# Quality — testing, static analysis, CI

## Definition of done

A slice is done when **all** of these hold. "It compiles" and "the generator succeeded" are not on this list.

- [ ] Exercised against a running app — real HTTP request, tinker call, or passing test
- [ ] Authorization verified from *both* sides: the allowed actor succeeds, a forbidden actor is blocked
- [ ] Edge cases checked: empty state, missing relation, duplicate submit, boundary values
- [ ] `./vendor/bin/pint` clean
- [ ] `./vendor/bin/phpstan analyse` clean at the project's configured level
- [ ] No leftover test data mutating the seeded baseline
- [ ] Committed and pushed as its own atomic unit

---

## Testing

### Pest (default)

```bash
composer require --dev pestphp/pest pestphp/pest-plugin-laravel
./vendor/bin/pest --init
```

Let Composer resolve the version against the project's PHP and Laravel
majors rather than pinning one here — Pest's major is coupled to PHPUnit's.

```php
// tests/Feature/EnrollmentTest.php
it('blocks enrollment when the course is full', function () {
    $course  = Course::factory()->create(['maximum_students' => 1]);
    $first   = User::factory()->student()->create();
    $second  = User::factory()->student()->create();

    actingAs($first)->post(route('enroll', $course))->assertOk();
    actingAs($second)->post(route('enroll', $course))->assertForbidden();

    expect($course->enrollments()->count())->toBe(1);
});
```

Run: `./vendor/bin/pest`, `--parallel` when the suite grows, `--filter=Enrollment` while iterating.

### What's actually worth testing

Rank by *cost of being wrong*, not by coverage percentage:

1. **Money, capacity, and concurrency** — anything with a transaction or a lock. These fail rarely and expensively.
2. **Authorization boundaries** — for each policy: the owner can, a peer cannot, an admin can. This is where silent security holes live.
3. **State machines** — enrollment/payment/submission status transitions, and the rules that gate them.
4. **Business rules with a formula** — grade calculation, progress percentage, eligibility.

Don't write tests for: framework behavior (Eloquent saves things), getters/setters, or Filament resource *configuration* (test the policy behind it instead).

### Feature vs Unit

Default to **feature tests** hitting real routes with a real database (`RefreshDatabase`). They test the thing that actually ships. Reserve unit tests for pure logic with no I/O — a grade formula, a value object.

### Testing database

`phpunit.xml` — SQLite in-memory is fast, but if the app relies on `lockForUpdate`, MySQL-specific SQL, or JSON column behavior, test against MySQL instead or those paths are untested:

```xml
<env name="DB_CONNECTION" value="sqlite"/>
<env name="DB_DATABASE" value=":memory:"/>
```

---

## Static analysis

### PHPStan + Larastan

```bash
composer require --dev larastan/larastan
```

`phpstan.neon`:

```neon
includes:
    - vendor/larastan/larastan/extension.neon

parameters:
    paths:
        - app
        - database
        - routes
    level: 5
    checkMissingIterableValueType: false
```

**Start at level 5** on an existing codebase and raise one level at a time, fixing as you go. Starting at 9 on legacy code produces thousands of errors and gets abandoned. New projects can start at 6–8.

Larastan teaches PHPStan about Eloquent magic — facades, relation return types, model attributes, collections. Without it, PHPStan flags most Laravel code as broken.

### Pint (formatting)

```bash
./vendor/bin/pint          # fix
./vendor/bin/pint --test   # verify only (CI)
```

Zero-config by design. Don't fight it or hand-tune `pint.json` — the value is that it's not a decision.

### Rector (automated refactoring + upgrades)

```bash
composer require --dev rector/rector driftingly/rector-laravel
./vendor/bin/rector process --dry-run   # ALWAYS dry-run first
./vendor/bin/rector process
```

Best use: Laravel and PHP major-version upgrades, where it mechanically applies most of the migration guide. Review the diff — it's a code transformer, not an oracle.

---

## CI — GitHub Actions

`.github/workflows/ci.yml`:

```yaml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: shivammathur/setup-php@v2
        with:
          php-version: '8.4'
          extensions: intl, zip, gd, pdo_mysql, bcmath
          coverage: none
      - run: composer install --prefer-dist --no-progress
      - run: cp .env.example .env && php artisan key:generate
      - run: ./vendor/bin/pint --test
      - run: ./vendor/bin/phpstan analyse
      - run: ./vendor/bin/pest
```

Gate merges on this. A check that doesn't block is decoration.

---

## Verifying without a test suite

When tests don't exist yet, `tinker` is the highest-value verification tool — it exercises the *real* code path, not a reimplementation of it:

```bash
php artisan tinker --execute="
  \$u = App\Models\User::factory()->create(['role' => App\Enums\UserRole::Instructor]);
  echo var_export(\$u->can('update', App\Models\Course::first()), true);
"
```

Two disciplines that matter when doing this:

- **Reset mutated state afterward** (`migrate:fresh --seed` if it drifted). Test scripts that leave the seeded baseline changed make the *next* verification lie to you.
- **Each `--execute` is a fresh process, but within one script the framework caches.** Livewire computed properties memoize on first access — a read → mutate → read sequence in one script returns the stale first value. That's the cache working as designed, not a bug. Instantiate fresh objects to simulate separate requests.
