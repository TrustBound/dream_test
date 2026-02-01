# Dream Test 2.1.0 Release Notes

**Release Date:** 2026-01-31

Dream Test 2.1 adds **runner-level hooks** so you can apply setup/teardown across
all suites without touching each suite’s internal hook structure.

## Highlights

### ✅ Runner-level hooks (test/suite/run)

The runner now supports hooks at three levels:

- **Per-test**: `before_each_test` / `after_each_test`
- **Per-suite**: `before_each_suite` / `after_each_suite`
- **Per-run**: `before_all_suites` / `after_all_suites`

Per-test hooks run inside the executor (sandboxed, ordered correctly around suite hooks),
and failures in `before_each_test` yield `SetupFailed` so test bodies are skipped safely.

### ✅ Metadata passed into hooks

New metadata types are available for hooks and filtering:

- `types.TestInfo` includes name, full name, tags, kind, and **source**.
- `types.SuiteInfo` includes suite name, test list, and **source**.

`source` is best-effort:

- Unit discovery suites use the **module name**.
- Gherkin discovery suites use the **.feature file path**.
- Manually constructed suites use `None`.

### ✅ Documentation and examples

- New **runner hooks** section in the Runner & execution guide.
- Tested snippet added at `examples/snippets/test/snippets/runner/runner_hooks.gleam`.
- README and documentation index updated to highlight runner hooks.
- Compatibility reports refreshed.

## Files of interest

- `src/dream_test/runner.gleam`
- `src/dream_test/parallel.gleam`
- `src/dream_test/types.gleam`
- `documentation/07-runner-and-execution.md`
- `examples/snippets/test/snippets/runner/runner_hooks.gleam`

