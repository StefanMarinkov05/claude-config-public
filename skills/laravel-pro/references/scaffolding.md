# Scaffolding & automation

**Goal: write only the code a generator can't.** Every hand-typed line that a tool would have emitted is wasted time and a chance to introduce a typo the tool wouldn't make. But every generated line is a *draft* until read.

The split, empirically, on a real project: **~60% of files come out of generators correct and untouched; ~40% need hand-patching** — and that 40% is exactly where the business logic lives.

---

## The generate → review → patch loop

Never `generate` → `commit`. Always:

1. **Generate** — the widest tool that fits (Blueprint for whole schemas, `--generate` for resources)
2. **Read every generated file** — especially casts, relations, and factories
3. **Patch the business layer** — enums, constraints, aliased relations, authorization, validation
4. **Verify against the running app** — tinker or HTTP, not just `php -l`
5. **Commit the slice**

---

## Level 1–2: Filament (admin CRUD)

The highest-leverage tool in the stack. A resource replaces a controller, 4 Blade views, a form request, and pagination.

```bash
# Full CRUD from the DB columns — ALWAYS pass --no-interaction
php artisan make:filament-resource Course --generate --no-interaction

# Nested CRUD on the parent's edit page (course → its sections)
php artisan make:filament-relation-manager CourseResource courseSections title \
    --related-resource="App\Filament\Resources\CourseSections\CourseSectionResource" \
    --generate --no-interaction

# Dashboard widgets
php artisan make:filament-widget AcademyStats --stats-overview --no-interaction
php artisan make:filament-widget EnrollmentsChart --chart --no-interaction
```

**What `--generate` gets right:** field types inferred from column types (`TextInput`, `Textarea`, `Toggle`, `DatePicker`, `FileUpload`), relation selects, searchable/sortable columns, soft-delete filters and restore actions.

**What it can't know — always hand-added:**

| Add by hand | Example |
|---|---|
| Enum options + badges | `->options(CourseStatus::class)`, `->badge()` |
| Business validation | `->minValue(0)`, `->after('start_date')`, custom `->rule()` closures |
| Derived/scoped relations | `->relationship('instructor', 'name', fn ($q) => $q->where('role', Instructor))` |
| Computed columns | `->counts('enrollments')` |
| Filters | `SelectFilter`, date-range `Filter` |
| Custom actions | mark-paid, grade, refund — with `requiresConfirmation()` + `DB::transaction()` |
| Ownership scoping | `getEloquentQuery()` override |
| Nav grouping | `$navigationIcon`, `$navigationGroup` — the generator gives every resource the same icon |
| Relation registration | `getRelations()` ships empty; you fill it |

**Free win:** implement `HasLabel` + `HasColor` on the backed enum once, and every Filament select, badge, and filter across every resource inherits correct labels and colours with zero per-field config.

**Known generator failures** — see `gotchas.md`: relation-manager and `--table` widget generators crash (Nette error) when an optional prompt can't be resolved; hand-write those.

---

## Level 3: Blueprint (bulk schema)

```bash
composer require --dev laravel-shift/blueprint
# write draft.yaml at the project root
php artisan blueprint:build
```

One YAML → migrations + models (with `$fillable`, casts, relations) + factories, for the whole schema at once.

```yaml
models:
  Category:
    name: string
    is_active: boolean default:true
    relationships:
      hasMany: Course

  Course:
    category_id: id foreign:categories
    title: string
    slug: string unique
    price: decimal:8,2 default:0
    status: string
    softdeletes: softDeletes
    relationships:
      belongsTo: Category
      hasMany: CourseSection, Enrollment
```

**Column syntax:** `string`, `text nullable`, `boolean default:true`, `decimal:8,2`, `unsignedInteger`, `id foreign:table`, `timestamp nullable`, `softdeletes: softDeletes`, modifiers `unique`, `nullable`, `default:x`.

**Blueprint's blind spots — always patch after generating:**

| Gap | Fix |
|---|---|
| **Aliased foreign keys are misparsed** — `belongsTo: User:instructor_id` emits a *duplicate* method (fatal) plus a phantom `instructor_id_id` column | Rewrite the relation by hand: `belongsTo(User::class, 'instructor_id')`; drop the phantom column from the migration |
| Wrong date cast — `'timestamp'` (raw Unix int) where `'datetime'` (Carbon) was meant | Fix every date cast on generated models |
| Zero enum awareness — enum columns become `string`, factories get `fake()->word()` | Add `MyEnum::class` casts; factories use `fake()->randomElement(MyEnum::cases())` |
| No composite unique constraints | Add `$table->unique(['course_id', 'position'])` to the migration |
| No `hasManyThrough` | Add by hand |
| Unbounded fakers — `randomNumber()` on a `position` column violates unique indexes | `numberBetween(1, 20)` |
| Cannot modify existing tables | Anything touching the base `users` table is a hand-written `--table=` migration |

**Verdict:** worth it for 8+ tables. For 2–3, plain `make:model -mf` is faster than learning the DSL.

---

## Level 4–5: artisan generators

Always prefer a flag over a second command.

```bash
# Model + migration + factory + seeder + policy + resource controller, one shot
php artisan make:model Course -mfsp --resource

# -m migration  -f factory  -s seeder  -p policy  -c controller
#    --resource (RESTful methods)  --requests (form requests too)

php artisan make:migration add_role_to_users_table --table=users
php artisan make:enum CourseStatus            # NOTE: lands in app/, move to app/Enums/
php artisan make:policy CoursePolicy --model=Course
php artisan make:request StoreCourseRequest
php artisan make:job ProcessCertificate
php artisan make:notification SubmissionGraded
php artisan make:observer CourseObserver --model=Course
php artisan make:livewire CourseCatalog
php artisan make:controller X --invokable      # single-action controllers
php artisan notifications:table                # database notifications
```

**`make:enum` puts the file in `app/`, not `app/Enums/`.** Move it and fix the namespace, or the convention silently breaks.

---

## What is *always* hand-written

No generator can infer these, because they encode decisions rather than structure:

- **Enums** — the cases, labels, colours, and every model cast referencing them
- **Composite unique constraints** and business indexes
- **Relations with non-default foreign keys** and `hasManyThrough`
- **Policies** — the actual authorization rules
- **Transactions + row locks** for contested state
- **Domain methods** — eligibility checks, grade calculation, state transitions
- **Seeders** with coherent, realistic data spanning every workflow state
- **Custom actions** — anything with confirmation, side effects, or notifications

---

## Automating the quality loop

Put the repetitive checks behind one command. `composer.json`:

```json
"scripts": {
    "lint":     "pint",
    "test":     "pest --parallel",
    "analyse":  "phpstan analyse --memory-limit=512M",
    "check":    ["@lint", "@analyse", "@test"],
    "fresh":    "@php artisan migrate:fresh --seed"
}
```

```bash
composer check    # the whole gate, one command — same thing CI runs
composer fresh    # reset dev data
```

Wire the same three into CI (`quality.md`) so local and CI can't diverge.

**Also automate:**
- `php artisan ide-helper:generate && ide-helper:models --write` — kills most phantom IDE errors
- `./vendor/bin/rector process --dry-run` — mechanical Laravel/PHP major upgrades
- A `post-update-cmd` composer hook to regenerate IDE helpers after every `composer update`

---

## When *not* to reach for a generator

- **A one-off** — scaffolding a resource you'll delete tomorrow costs more than it saves.
- **When the abstraction doesn't fit.** Filament is an *admin panel* framework. Bending it into a public-facing storefront fights the tool; use Livewire or Blade there.
- **When you don't yet understand what it emits.** Generated code you can't read is code you can't debug. If that's the situation, hand-write one example first, then generate the rest.
