# Gotchas — traps found the hard way

Real failures hit while building production Laravel, with the diagnosis. Most cost 20+ minutes each the first time.

---

## Filament

### v3 tutorials do not work on v4/v5

The single biggest time sink. Filament v4 merged Forms and Infolists into a unified `Schemas` namespace, and most tutorials/Stack Overflow answers are still v3.

| v3 | v4 / v5 |
|---|---|
| `public static function form(Form $form): Form` | `public static function form(Schema $schema): Schema` |
| `return $form->schema([...])` | `return $schema->components([...])` |
| `Filament\Forms\Form` | `Filament\Schemas\Schema` |
| `Tables\Actions\*`, `Pages\Actions\*` | unified `Filament\Actions\*` |

**Always pin the docs URL to your major** — `filamentphp.com/docs/4.x/...`. The bare `/docs/` redirects to the newest and the samples silently differ.

### Filament 4 splits a resource across files

Not one class — `--generate` produces:

```
CategoryResource.php              # model, nav, wiring
Pages/{List,Create,Edit}Category.php
Schemas/CategoryForm.php          # the form lives here
Tables/CategoriesTable.php        # the table lives here
```

### Generators crash on missing input

`make:filament-relation-manager` and `make:filament-widget --table` throw a **Nette `Value '' is not valid class/function/constant name`** error when an optional prompt can't be answered. `--no-interaction` does *not* always fix it.

- Relation manager: pass `--related-resource="App\Filament\Resources\X\XResource"` explicitly.
- No related resource exists (e.g. a polymorphic `activities()` relation)? **Write the class by hand** — it's ~20 lines.
- `make:filament-widget --table`: hand-write it; the generator is broken.

`make:filament-resource` also blocks on an interactive "title attribute" prompt — always pass `--no-interaction`.

### `make:enum` puts enums in `app/`, not `app/Enums/`

Move them and fix the namespace, or the `App\Enums\*` convention silently doesn't hold.

### Enums pay off in Filament — if you implement the contracts

Implement `HasLabel` and `HasColor` on the backed enum, and `->badge()` on a table column renders a correctly-coloured pill with no per-column config. `->options(MyEnum::class)` populates selects. Define it once, inherit everywhere.

### Nav is auto-discovered; grouping is not

`->discoverResources(...)` in the panel provider registers every resource automatically — you never manually list them. But they all default to the *same* icon with no grouping, which is an unusable sidebar at 10 resources. Set `$navigationIcon` and `$navigationGroup` per resource.

### Hide, then deny

`shouldRegisterNavigation()` removes a resource from the sidebar for a role; it does **not** stop a typed URL. Pair it with a policy every time.

---

## Livewire

### Full-page components need an explicit layout

Routing straight to a component (`Route::get('/courses', CourseCatalog::class)`) makes Livewire look for `resources/views/components/layouts/app.blade.php`. Breeze puts its layout at `layouts.app`. Result: `Livewire page component layout view not found`.

```php
#[Layout('layouts.app')]
class CourseCatalog extends Component
```

### Breeze's layout assumes an authenticated user

`layouts/navigation.blade.php` calls `Auth::user()->name` with no guard — it **fatals for guests**. Any public page using `layouts.app` breaks for anonymous visitors. Build a separate minimal `layouts.public` rather than retrofitting guest handling into Breeze's dropdown nav.

### Computed properties memoize per request

`getXProperty()` accessed via `$this->x` caches on **first access** for that component instance. A read → mutate → read sequence within one request returns the stale first value.

In normal operation this is invisible (Livewire runs actions *before* `render()`), but bust it explicitly when an action mutates the underlying data:

```php
public function markComplete(): void
{
    LessonProgress::updateOrCreate([...], [...]);
    unset($this->completedLessonIds);   // ← invalidate
}
```

### Child components don't re-render with the parent

A nested component only re-renders when its **props** change. If a parent action should refresh a child, dispatch an event and listen for it — the child is an independent island by design.

### `wire:model` default changed between v2 and v3

v2 was live by default; **v3 is deferred**. `wire:model.live` is now required for reactivity. Half of the tutorials online are v2. See also v4, where `.blur`/`.change` modifiers changed what they control.

### Public properties are client-controlled; public methods are endpoints

Livewire's threat model surprises people: **every public property round-trips through the browser and is client-modifiable, and every public method is effectively a public endpoint** — whether or not you rendered a button for it.

```php
#[Locked]                     // throws if the client tries to change it
public Assignment $assignment;

public int $price;            // WITHOUT #[Locked]: user sets this to 0 in devtools
```

- `#[Locked]` on every id, price, or ownership-bearing property.
- **Never trust a property for authorization** — re-check against `auth()->user()` inside the action method.
- A `public function markAsPaid()` on a student-facing component is callable by any student who can load that component. Make it `protected`, or authorize inside it.
- Never read a price or amount from the client — look it up from the database inside the action.

**The typing counterpart, same hydration path.** A strictly typed public property (`int`, `?int`, `float`) that the client *can* set will throw an uncaught `TypeError` during hydration, before any of the component's own code runs — a raw 500 from a crafted `$set` or query string. Two fixes, and picking the wrong one breaks the feature:

- `#[Locked]` for a **server-managed** value (an id set in `mount()`, an index moved by methods). A locked property the UI actually sets throws `CannotUpdateLockedPropertyException` instead — also a 500.
- Widen to `mixed` + normalise in the `updatedX()` hook for anything `wire:model` or `$set` legitimately drives (a quantity box, a star rating, a select). Validation on submit still guards what is persisted.

---

## Eloquent

### `'timestamp'` is not the datetime cast

`'timestamp'` is Eloquent's **raw Unix integer** cast. For a `TIMESTAMP`/`DATETIME` column you want as Carbon, the cast is `'datetime'`. With the wrong one, `->format()` throws `Could not parse '1790906175'`. Generators guess this wrong constantly — audit every date cast on generated models.

### `decimal:N` wants a string, not a float

```php
$enrollment->final_grade = (string) $grade;   // ✅
$enrollment->final_grade = $grade;            // ⚠️ brick/math deprecation, precision risk
```

Compare money with `bccomp((string) $a, (string) $b, 2) === 0`, never `==`.

### `hasManyThrough` + a column name on both tables = ambiguous SQL

`Course::lessons()` goes through `course_sections`. Both tables have `position`:

```php
$course->lessons()->orderBy('position')          // ❌ SQLSTATE 1052: ambiguous
$course->lessons()->orderBy('lessons.position')  // ✅ qualify it
```

### Soft deletes keep the FK reference alive

`$course->delete()` on a soft-deleting model leaves the row (and its foreign key) in the table. A subsequent attempt to delete the referenced parent fails with a constraint violation, and the row is invisible to normal queries. Use `Course::withTrashed()->...->forceDelete()` to actually remove it.

### FK deletion order

Deleting a parent before its children throws `Cannot delete or update a parent row`. Delete deepest-first: payment → enrollment → user. This bites hardest in cleanup scripts.

---

## Blueprint (laravel-shift/blueprint)

Useful for bulk schema generation, but treat the output as a draft:

- **Aliased foreign keys are misparsed.** `belongsTo: User:instructor_id` produced both a **duplicate `instructor()` method** (fatal PHP error) and a phantom **`instructor_id_id`** column.
- **No enum awareness** — every fixed-value column becomes a plain string, and the factory gets `fake()->word()`, which passes on write and throws on read once the enum cast exists.
- **No composite unique constraints, no `hasManyThrough`** — not expressible in the YAML. Add by hand.
- **Unbounded fakers** — `randomNumber()` on a `position` column will violate a composite unique index.

It also cannot modify existing tables, so anything touching the base `users` table is hand-written anyway.

---

## Tooling

### Intelephense false positives on Filament

Filament composes its API from ~15 traits, and Intelephense's static analysis doesn't fully walk that chain. It reports **`Undefined method 'icon'`** and **`Undefined type 'Filament\Schemas\Schema'`** at *Error* severity on correct code.

Verify with real tooling before believing it:

```bash
php -l path/to/File.php          # syntax
php artisan optimize:clear       # forces Laravel to resolve every class
php artisan tinker --execute="var_dump(method_exists('Filament\Actions\Action','icon'));"
```

If those pass, the code is fine — re-index the workspace (`Intelephense: Index Workspace`). Same class of false positive appears as "declared but not used" on symbols that *are* used.

---

## Caching

After **any** package install, `filament:install`, or route change: run `php artisan optimize:clear` before trusting `artisan serve`. Stale route cache produces 404s on routes that `php artisan route:list` displays correctly — an especially confusing failure because both signals seem authoritative.
