# Dream Test 3.0.0 Release Notes

**Release Date:** 2026-11-18

Dream Test 3.0.0 adds line coverage to the runner. It also runs the hooks of
each scope in a process that keeps their resources alive, follows the official
Gherkin grammar, and gives each Gherkin scenario one typed state value. This
is a major release: read the breaking changes below before you update.

## Highlights

### 📈 Built-in line coverage

`runner.coverage(coverage.new())` measures the modules in `src` with the
native line counters of the BEAM. After the test results, the runner prints a
table per file and writes an LCOV file to `build/coverage/lcov.info`.
dream_test measures itself this way: its own tests cover 100% of the lines in
`src`, with no exclusions.

- `coverage.show_missing` lists the lines that did not run.
- `coverage.minimum_percent` and `coverage.minimum_percent_per_file` fail the
  run below a total or per-file percent.
- `runner.coverage_from_environment` turns coverage on only when
  `DREAM_TEST_COVERAGE` is `1` or `true`, for example only in CI.
- `coverage.exclude`, `coverage.exclude_with_reason` and the
  `// coverage:ignore` markers leave out files, lines, blocks and functions.
  The table always says what was excluded.
- Output formats: LCOV, JSON (`coverage.json_path`), Cobertura XML
  (`coverage.cobertura_path`), Markdown for GitHub job summaries
  (`coverage.markdown_path`), and HTML with annotated source
  (`coverage.html_path`, or one page with `coverage.html_file`).
- `coverage.merge_lcov` adds LCOV files from other BEAM instances, for
  example an application server that measures itself with `coverage.start`
  and `coverage.finish`.
- A new guide, `documentation/12-coverage-badge.md`, shows how to publish a
  live coverage badge from GitHub Actions to a `badges` branch, with no
  outside service.

### 🧵 A new hook process model

The hooks of each scope run in one owner process that lives while the tests
of the scope run. A pool, a supervisor or an ETS table that a `before_all`
hook starts now lives for the tests of its group. A test runs its
`before_each` hooks, its body and its `after_each` hooks in one process.

- One rule for every hook failure: a failed set-up hook gives `SetupFailed`
  to each test that it serves. A failed tear-down hook keeps the test status,
  the other tear-down hooks still run, and the run fails.
- `runner.run` returns a `types.RunReport` with the test results and the
  tear-down failures. The BDD and Gherkin reporters show a
  `Set-up and tear-down failures:` section.
- When the process that keeps a set-up alive stops, the runner reports the
  stopped set-up one time and names each test that it did not run.
- A hook that crashes, never returns, or kills its own process does not stop
  the run.
- A test body past its timeout is always `TimedOut`.

### 🥒 Gherkin conformance

The parser follows the official Gherkin grammar and passes the official
Gherkin test files (37 good files, 12 bad files, and 8 good files that
dream_test rejects on purpose).

- `Rule:` sections, more than one `Examples` section for each scenario, the
  `*` step keyword, and the English keyword synonyms.
- A step can have both a DataTable and a DocString.
- `Examples` values replace placeholders in the scenario name, DocStrings and
  DataTables, and each row test has the row label in its name.
- Typed parse errors (`parser.ParseError`, `parser.FeatureFileError`) with the
  line of each problem.

### 🧩 Typed step state

The `world` key/value store is gone. Each scenario starts from the state that
you give to `steps.new(initial:)`. A `given` or `when` step gets the state and
returns the next state. A `then` step gets the state and returns an
assertion. The compiler now checks the type of the state in every step. For
example, `fn step_add(cart: Int, _context: StepContext) -> Result(Int, String)`
is a `when` step for a scenario whose state is an `Int`.

## Breaking changes

Each item has a 2.x and a 3.0.0 example in
[Upgrading to 3.0.0](../documentation/13-upgrading-to-3.md).

- `runner.run` and `parallel.run_root_parallel` return `types.RunReport`, and
  the reporter functions that format a whole run take one.
  `runner.has_failures` is now `types.failed`.
- Gherkin: `world` is removed, `steps.new` takes the initial state,
  `steps.when_` and `steps.then_` are now `steps.when` and `steps.then`,
  `steps.step` is removed, and a pattern defined two times in one phase is an
  error.
- Gherkin syntax tree and parser: `Scenario Outline` is a `Scenario` with
  `Examples`, `Step` has `doc_string` and `data_table`, parse errors are
  typed, and lines that the grammar does not permit are errors.
- Hook failures: set-up failures give `SetupFailed`, and tear-down failures
  go into the run report in place of fake `<after_all>` tests.
- The JSON report schema is `2.0`.
- `runner.exit_on_failure` stops the BEAM with `init:stop(1)`.
- `sandbox.run_isolated` takes the function and its input as two parameters.
- `types.Root`, `types.TestResult` and `types.TestInfo` changed shape, and
  `types.ModuleCoverage` and `types.CoverageSummary` are removed.

## Requirements

- Gleam 1.19 or later for exact coverage line numbers. Older Gleam versions
  map only the first line of each function, and the coverage table warns
  about it.
- Erlang/OTP 27 or later with the JIT (the default on x86-64 and ARM64) for
  coverage. On another runtime, `coverage.start` fails with
  `NativeCoverageUnsupported`.

## Files of interest

- `src/dream_test/coverage.gleam`
- `src/dream_test/runner.gleam`
- `src/dream_test/parallel.gleam`
- `src/dream_test/sandbox.gleam`
- `src/dream_test/types.gleam`
- `src/dream_test/gherkin/parser.gleam`
- `src/dream_test/gherkin/steps.gleam`
- `documentation/12-coverage-badge.md`
- `documentation/13-upgrading-to-3.md`
- `CHANGELOG.md`
