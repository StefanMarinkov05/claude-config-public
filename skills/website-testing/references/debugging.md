# Debugging

Finding the cause behind a symptom. Not a testing layer — it produces no
artifact that runs again — but the discipline that turns a failure into a
regression test.

## The protocol

1. **Reproduce it reliably.** A bug you cannot trigger on demand cannot be
   confirmed fixed. If it is intermittent, that *is* the first finding — see
   "Intermittent failures" below.
2. **Minimise.** Strip the reproduction to the smallest input and shortest path
   that still fails. Most of the diagnosis happens here; the minimal case
   usually names the cause.
3. **Read the actual error.** The full message, the exception *class*, and the
   first frame in your own code — not the framework's. The exception type is
   frequently the whole answer (a constraint violation and an application
   refusal mean very different things).
4. **Form one hypothesis** and state what would disprove it.
5. **Instrument to test that hypothesis**, not to look around.
6. **Fix, then prove the fix**: revert it and confirm the failure returns.
7. **Ask why it was not caught**, and add the test that would have caught it.

Step 7 is the one that compounds. A fix without it means the same class
returns.

## Check the project's known-issues record first

Some errors look like ordinary bugs and are not. A project that keeps a
troubleshooting document has usually paid for those lessons already —
**read it before proposing a fix**. Recurring examples of the shape:

- A static analyser crashing on a memory limit and reporting the crash in the
  same format as a real finding.
- A factory that passes every static check and fails on insert, because a
  constraint was added after it was written.
- A code generator reporting success while leaving stale definitions behind.
- Editor diagnostics disagreeing with the container where dependencies live.

If the error is not there and you solve it, **add an entry**: symptom, cause,
fix, **why it recurs**, and what would prevent it permanently. An entry saying
what was fixed without why it recurs is half an entry.

## Reading a stack trace

- **Find the first frame in your own code**, top-down. Frames above it are the
  framework doing what it was told.
- **The exception class narrows the cause faster than the message.** A type
  error at a hydration boundary means the value arrived before any of your code
  ran. A constraint violation means the application guard is missing or on the
  wrong side of a boundary.
- **A driver-level exception reaching the UI is two bugs**: the condition, and
  the fact that a foreseeable condition was not handled as a refusal.

## Instrumentation

Prefer, in order:

1. **A failing test** at the lowest level that reproduces it. Permanent, and
   it becomes the regression test.
2. **Logging with structured context** — the ids and values, not just "here".
3. **A debugger breakpoint**, for genuinely stateful problems.
4. **Print statements**, last, and never committed. A lint rule should make
   this impossible to forget.

## Intermittent failures

Do not add a retry. A retry converts a real bug into a slow, invisible one.

Record first: which test, what the failure was, what the immediately following
run did, and whether a whole-suite re-run reproduces it. Then look for the
usual causes:

- **Time-dependent assertions** crossing a second or day boundary.
- **Order dependence** — one test leaving data another reads.
- **Unsorted results** asserted in order.
- **Timing barriers** in concurrency tests that stop aligning on a loaded
  machine. Note the failure mode is asymmetric: a barrier that stops aligning
  makes the workers *sequential*, which makes the test **pass** while proving
  nothing (`concurrency-testing.md`).

An unidentified flake is a known gap, and belongs in the write-up as one.

## Debugging a whole environment, not a bug

When everything fails at once, suspect the environment before the code. A real
instance: five containers exited simultaneously with the same non-zero status,
and the cause was the container daemon restarting — visible only in the
daemon's own uptime, not in any application log.

Check, in order: is the service running, did the runtime restart, did a
dependency's port change, is disk full, is the database reachable. The
application log is the *last* place a whole-environment failure shows up.

## Debugging what you cannot see

Some failures produce no error: a silently wrong answer, a filter that applies
itself, a hook that never fires.

The technique is **differential**: run the same operation with and without the
suspect input, and diff the *result set*, not the status code. If a wrong
answer returns 200, only the data reveals it.

For "the code never ran" suspicions, add a deliberate failure (throw) inside
the block and confirm it surfaces. If it does not, the block is unreachable and
that is the bug.

## Checklist

- [ ] Known-issues record consulted before proposing a fix
- [ ] Reproduced reliably, then minimised
- [ ] Exception class and first own-code frame identified
- [ ] One hypothesis at a time, with a disproof condition
- [ ] Fix proven by reverting it
- [ ] "Why was this not caught" answered, with a test added
- [ ] New recurring-error entry written, including why it recurs
- [ ] No retries added to hide intermittency
