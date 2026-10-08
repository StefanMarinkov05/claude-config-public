# Race test harness

Concrete recipes for the two-process barrier described in SKILL.md step 7.
Read that first — the harness is worthless if the assertion is the wrong one.

## Why two processes

One process holds one connection. A race between two connections cannot be
produced by interleaving work on a single one, and every attempt to fake it
tests something other than the mechanism:

- Taking the lock in the test with raw `SELECT … FOR UPDATE` and watching a
  second connection block → tests the database engine, not your code.
- Holding the row elsewhere and asserting the operation times out → the write
  and any dependent insert block on the holder whether or not the *read* took
  a lock, so the timeout arrives either way.
- Injecting a conflicting write via an ORM event → runs inside the transaction
  under test, where a lock is not supposed to stop it and does not.

## Why a barrier

Framework boot is 200–800 ms and varies per process. The window between the
deciding read and the write is microseconds. Started sequentially, the second
process reliably arrives after the first has committed and the test passes
with the mechanism removed.

Both workers therefore: boot → warm the connection (so the barrier, not a TCP
handshake, is the last thing before the critical section) → sleep to just
before a shared instant → busy-wait the remainder. `sleep`/`usleep` alone
overshoots by milliseconds, which is orders of magnitude wider than the window.

The barrier lives entirely in the test. **Never add a test-only branch, flag,
or sleep hook to production code** to make a race reproducible — that changes
the thing being measured.

## Test isolation

Transaction-rollback isolation (`RefreshDatabase`, `@Transactional`, pytest
`--create-db` with rollback fixtures) is incompatible with these tests:

- Rows the test inserted were never committed, so the second connection cannot
  see them.
- Asking for one makes that connection queue behind the test's own uncommitted
  write, producing a lock-wait timeout raised by the *first* session.

The failure looks like a locking bug in the code under test. It is the harness
locking against itself.

Put race tests in their own suite, commit fixtures, and truncate afterwards
with foreign keys disabled — a hand-maintained delete order breaks the moment
a factory gains a relation.

## Laravel / Pest

```php
$script = <<<'PHP'
    <?php
    require __DIR__.'/vendor/autoload.php';
    $app = require __DIR__.'/bootstrap/app.php';
    $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

    $id = (int) $argv[1];
    $startAt = (float) $argv[2];

    Illuminate\Support\Facades\DB::select('SELECT 1');   // warm the connection

    if (($remaining = $startAt - microtime(true)) > 0.01) {
        usleep((int) (($remaining - 0.01) * 1_000_000));
    }
    while (microtime(true) < $startAt) {
        // busy-wait to microsecond alignment
    }

    try {
        app(App\Actions\Inventory\ReserveStock::class)->handle(
            App\Models\ProductVariation::findOrFail($id), 1,
        );
        echo 'OK';
    } catch (Throwable $e) {
        echo 'FAILED:'.get_class($e);
    }
    PHP;

file_put_contents(base_path('race-worker.php'), $script);
$startAt = microtime(true) + 3.0;   // generous enough for two cold boots

$processes = collect(range(1, 2))->map(function () use ($id, $startAt) {
    $p = new Symfony\Component\Process\Process(
        ['php', 'race-worker.php', (string) $id, (string) $startAt],
        base_path(),
        // A bare PHP process reads .env, not phpunit.xml — without this the
        // workers hit the development database while the test asserts against
        // the test one, and nothing appears to happen at all.
        [
            'DB_CONNECTION' => 'mysql',
            'DB_DATABASE' => config('database.connections.mysql.database'),
            'DB_HOST' => config('database.connections.mysql.host'),
            'DB_PORT' => (string) config('database.connections.mysql.port'),
            'DB_USERNAME' => config('database.connections.mysql.username'),
            'DB_PASSWORD' => config('database.connections.mysql.password'),
        ],
    );
    $p->start();

    return $p;
});

$processes->each(fn ($p) => $p->wait());
$outputs = $processes->map(fn ($p) => trim($p->getOutput().$p->getErrorOutput()));
```

`php artisan tinker <file>` is not an option for the worker — it never exits,
so the processes produce no output and the test fails for an unrelated reason.

## Choosing the assertion

Always include the worker output in the failure message. "Expected 1, got 0"
usually means the workers failed to boot, not that locking is broken, and
without the output that costs an hour.

**Constraint-backed invariant** — assert the failure *type*:

```php
expect($outputs->first(fn ($o) => $o !== 'OK'))
    ->toBe('FAILED:'.InsufficientStockException::class,
        'A QueryException here means the loser read stale state, passed the '.
        'check, and was stopped by the CHECK constraint — a 500 where the '.
        'user should have seen a handled message.'.$report);
```

**No constraint possible** — assert the winner *count*, plus the invariant on
final state:

```php
expect($outputs->filter(fn ($o) => $o === 'OK'))->toHaveCount(1, $report);
expect($product->fresh()->is_available && $product->variations()->count() === 0)
    ->toBeFalse($report);
```

## Other stacks

The shape is identical; only process spawning changes.

- **Node/Jest**: `child_process.fork()` workers, barrier on `Date.now()`,
  report via `process.send()`. Disable any transactional test wrapper.
- **Python/pytest**: `multiprocessing.Process`, or `pytest-xdist` with a
  `multiprocessing.Barrier`. Use a real database, not the rollback fixture.
- **Go**: goroutines are sufficient *only* if each takes its own `*sql.Conn`
  from the pool — two goroutines sharing one connection serialise silently.
  `sync.WaitGroup` plus a `chan struct{}` as the barrier.
- **JVM**: threads with `CyclicBarrier`, each with its own connection from the
  pool. Beware a test container pinning one connection per thread-local.

The universal traps: one connection cannot race itself; rollback isolation
hides committed state; and boot/setup time dwarfs the window unless a barrier
aligns the workers.

## Deterministic alternatives

A barrier makes the interleaving *likely*, never certain. Where certainty
matters more than realism:

- **Two connections driven by hand from the test**: open connection A, `BEGIN`,
  take the locking read, then on connection B run the operation with a short
  `innodb_lock_wait_timeout` and assert it blocks. Deterministic, but it tests
  the engine unless the operation under test is what takes A's lock.
- **Jepsen-style linearizability checking** for distributed systems — far
  beyond what a typical application needs.
- **Deterministic simulation** (single-threaded scheduler, controlled clock)
  where the codebase is built for it. Not retrofittable.

Prefer the barrier plus the deletion law: run the suite with the mechanism
removed and confirm red. A test that is merely probabilistic is still evidence
when it has been observed distinguishing the two versions.
