# Architecture — where code goes

The guiding principle: **most Laravel architecture wins come from restraint, not cleverness.** Add a layer when it removes duplication or clarifies orchestration — not because a pattern exists.

---

## Where does this logic go?

| Responsibility | Home | Never |
|---|---|---|
| HTTP concerns — route to a method, return a response | Controller | Business rules, queries beyond a simple fetch |
| Input validation + authorization of the *request shape* | Form Request | Controller body |
| Can this **user** do this to this **record** | Policy | Blade `@if` alone |
| Query composition, reusable filters | Model scopes / dedicated Query class | Copy-pasted `where()` chains |
| A single business operation with side effects | Action / Service class | Controller, model |
| Reacting to something that happened | Event + Listener | Inline after the write |
| Slow or failure-prone work | Queued Job | Inline in the request |
| Derived model state | Accessor / computed attribute | Recalculated in every view |
| Consistent create/update side effects | Observer (sparingly) | — |
| Shaping data for an API response | API Resource | `->toArray()` on the model |

### Controller size heuristic

If a controller method exceeds ~15 lines or does more than one of {validate, authorize, persist, call an API, dispatch a side effect}, extract. Controllers coordinate; they do not compute.

### Action classes

Single public method, named for the business operation, one responsibility:

```php
app/Actions/Enrollment/EnrollStudentInCourse.php
    public function handle(User $student, Course $course): Enrollment
```

Use when: the operation has multiple steps, needs a transaction, is triggered from more than one place (web + admin + console), or is worth testing in isolation. **Don't** wrap a single `Model::create()` in an action — that's ceremony.

### Repositories — usually don't

Eloquent already *is* the data-access abstraction. A repository layer over Eloquent typically adds indirection while forfeiting Eloquent's expressiveness (scopes, eager loading, pagination). Justify it only with a real second implementation or a genuine need to swap the persistence engine — "for testability" is not a reason, since Laravel can already use an in-memory SQLite database in tests.

---

## Folder structure

**Default (small–medium app)** — stay with Laravel's conventional layout. It is well understood and every tutorial matches it:

```
app/
├── Actions/            # business operations, grouped by domain
├── Enums/              # backed enums for every fixed value set
├── Events/ Listeners/
├── Filament/           # admin panel: Resources, Widgets, Pages
├── Http/
│   ├── Controllers/
│   ├── Middleware/
│   └── Requests/       # Form Requests
├── Jobs/
├── Livewire/           # public/user-facing components
├── Models/
├── Notifications/
├── Observers/
├── Policies/
└── Services/           # only for genuinely stateful/multi-method services
```

**Modular (large app, multiple teams, clear bounded contexts)** — group by domain, not technical layer:

```
app/Domain/Billing/{Actions,Models,Policies,Events}
app/Domain/Catalog/{...}
```

Don't start here. Migrate into it when a single domain's files become hard to find in the flat layout. Premature modularization costs more than it saves.

---

## Eloquent

**Relations** — define both directions when both are queried. A missing inverse (e.g. `User::courses()` when only `Course::instructor()` exists) forces awkward workarounds later.

**Casts** — get these right at creation; wrong casts fail silently until something formats the value:

| Column type | Cast | Common mistake |
|---|---|---|
| `TIMESTAMP` / `DATETIME` you want as Carbon | `'datetime'` | `'timestamp'` — that's Eloquent's *raw Unix integer* cast; `->format()` then throws |
| money | `'decimal:2'` | `'float'` — precision loss. Assign as **string**, not float, or brick/math deprecates |
| fixed value set | `MyEnum::class` | plain `'string'` |
| booleans | `'boolean'` | leaving as `0/1` |
| JSON | `'array'` / `AsCollection::class` | manual `json_decode` |

**Scopes** for reusable query fragments. **`hasManyThrough`** for two-hop relations (`Course → sections → lessons`) — but qualify column names in `orderBy` when the column exists on both joined tables (`orderBy('lessons.position')`, not `orderBy('position')`, which throws *ambiguous column*).

**Guard against N+1 in development:** in `AppServiceProvider::boot()`

```php
Model::preventLazyLoading(! $this->app->isProduction());
Model::preventSilentlyDiscardingAttributes(! $this->app->isProduction());
```

The second one turns "you tried to fill a non-fillable attribute and Laravel silently dropped it" from a mystery bug into an exception.

---

## Database design

- **Constraints belong in the database, not only in PHP.** A uniqueness rule enforced only by an `exists()` check is a race condition. Add the composite unique index *and* the friendly PHP check (the index is correctness, the check is UX).
- **Foreign keys** with intentional `onDelete` behavior — `cascade` vs `restrict` vs `nullOnDelete` is a business decision, not a default.
- **Soft deletes** only where recovery is a real requirement. They complicate every subsequent query and unique index. Note that soft-deleted rows still occupy FK references — `forceDelete()` is needed to actually remove them.
- **Index what you filter and sort on.** Foreign keys are indexed automatically; `status`, `slug`, and date columns used in `where`/`orderBy` are not.
- **Position/ordering columns** with a unique constraint make reordering painful (a swap violates uniqueness mid-transaction). Either renumber sequentially in one transaction, or accept non-unique positions.

---

## Migrations

- Never edit a migration that has run anywhere but your own machine — write a new one.
- Additive migrations for existing tables (`--table=users`) need explicit `down()` that drops exactly what `up()` added.
- Migration order matters: a table with a FK must run after the table it references. Blueprint-style generators get this right by timestamp; hand-written ones need care.
- `migrate:fresh --seed` is the reset button in development. Never in an environment with real data.

---

## Seeders & factories

Seeders should produce a **coherent demo dataset**, not random noise — named users, realistic titles, and records spread across every workflow state (pending / active / completed / cancelled), so every screen has something meaningful to render.

Factories must produce **valid** data:

- Enum columns: `fake()->randomElement(MyEnum::cases())` — never `fake()->word()`, which passes on write and explodes on read when the enum cast rejects it.
- Bounded numbers: `numberBetween(1, 20)`, not `randomNumber()`, which will violate realistic ranges and any composite unique index on ordering columns.
- Unique columns: `fake()->unique()->...`.

---

## Code generation

Generate everything a tool can produce; hand-write the ~40% that encodes business rules. The full playbook — Blueprint YAML, Filament generators, the artisan flag catalog, and each tool's specific blind spots — lives in **`scaffolding.md`**.
