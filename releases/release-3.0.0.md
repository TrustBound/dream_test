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

The `before_all` and `after_all` hooks of a group run in one setup process
that lives while the tests of the group run. A pool, a supervisor or an ETS table that a `before_all`
hook starts now lives for the tests of its group. A test runs its
`before_each` hooks, its body and its `after_each` hooks in one process.

- One rule for every hook failure: a failed set-up hook gives `SetupFailed`
  to each test that it serves. A failed tear-down hook keeps the test status,
  the other tear-down hooks still run, and the run fails.
- `runner.run` returns a `types.RunReport` with the test results, the
  tear-down failures and the crashed `reporter_types.Custom` reporters. The BDD and Gherkin reporters show a
  `Set-up and tear-down failures:` section.
- When the process that keeps a set-up alive stops, the runner reports the
  stopped set-up one time and names each test that it did not run.
- A hook that crashes, never returns, or kills its own process does not stop
  the run.
- A test body past its timeout is always `TimedOut`.

### 🧺 One suite type, and set-ups for a whole suite

- Every suite has one type, `suite.TestSuite` in the new module
  `dream_test/suite`, whatever context its tests get. One `runner.new`
  takes `unit` suites, `unit_context` suites and Gherkin features together.
  `suite.group` and `suite.join` put suites together, and each keeps its
  own context.
- A suite set-up gives the context of a whole suite and runs once, only
  when at least one of its tests runs: `unit_context.describe_with_set_up`
  for unit tests, and `steps.new_with_set_up` for Gherkin scenarios, for
  example to start one server for all the scenarios of a feature.
- `steps.to_suite` makes one suite from several Features with one
  registry, so one set-up serves all of them. Its children
  (`steps.SuiteChild`) are `Feature`, `Scenarios`, `Group` and `Node`.
- `suite.from_tree` turns a suite tree that you build by hand
  (`types.Root`) into a `TestSuite`.
- Pending tests: `unit.pending(name)` and `unit_context.pending(name)` make
  a test with a name and no body, for a test skeleton. The reporters show
  it as pending, and the run still passes.

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

Each item that needs a code change has a 2.x and a 3.0.0 example in
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
- The JSON report schema is `2.0`. Its `system` object has
  `gleam_stdlib_version` in place of `gleam_version`, with the same value:
  the version of the `gleam_stdlib` package. The JSON report ends with a
  newline.
- The summary line of the BDD and Gherkin reporters lists the extra counts
  in the order skipped, pending, timed out, setup failed, tear-down failed,
  set-up stopped, before ` in <duration>`. Each count shows only when it is
  not 0. `tear-down failed` and `set-up stopped` are new.
- `runner.exit_on_failure` stops the BEAM with `init:stop(1)`. Every test
  runs, and the runner writes all its output first. Then it ends the
  program with status 1 when a test fails, times out or has a failed
  set-up, when a tear-down hook fails, when a set-up stops
  (`SetupStopped`), when a `reporter_types.Custom` reporter crashes, and
  when coverage fails.
- A crashed `reporter_types.Custom` reporter is in the run report, so
  `types.failed(report)` is `True`. `types.report_reporter_crashes` gives
  its position and the full reason.
- `runner.silent()` drops the normal output only: progress, results
  reports and the coverage report. It still writes two kinds of error to
  the standard error stream: the `Results reporter failed` error of a
  `reporter_types.Custom` reporter that crashed, and a coverage error, for
  example a total below `coverage.minimum_percent`.
- `reporters/types.ResultsReporter` has the new variant `Custom(render:)`.
  A `case` on a `ResultsReporter` needs a branch for it.
- `sandbox.run_isolated` takes the function and its input as two parameters.
- `types.Root`, `types.TestResult` and `types.TestInfo` changed shape, and
  `types.ModuleCoverage` and `types.CoverageSummary` are removed.
- `TestSuite` has no type parameter and is in `dream_test/suite`, and
  `runner.RunBuilder` has no type parameter.
- `runner.before_each_test` and `runner.after_each_test` take
  `fn(TestInfo) -> Result(Nil, String)`: the hooks get the `TestInfo` of the
  test, not its context.
- Module discovery keeps the context of a suite with a context; in 2.x its
  tests got `Nil`.
- `types.AssertionResult` has the new variant `AssertionPending`.
- The progress event API changed: `progress.handle_event` and the reporter
  event types are removed; use `progress.line` with a
  `progress.ProgressEvent`.
- `types.TestKind.Integration`, `types.TestSuiteItem` and the module
  `dream_test/context` are removed.
- Gherkin: `find_step` and `step_trie` take a `StepPhase` in place of a
  keyword.
- A `discover.features` pattern that matches no files is an error, and so
  is a module discovery pattern that matches no test module.
- Gherkin: `steps.given` and `steps.when` take the step function with the
  label `action:`, and `steps.then` with the label `check:`. In 2.x the
  label was `handler:`.
- Gherkin: `types.GherkinScenario` is
  `GherkinScenario(scenario_id:, rule:)`. In 2.x it held only the id.
- Gherkin: `{float}` matches a number as Cucumber reads it, such as `20`,
  `.5` or `1e5`. In 2.x it needed a `.`. With `total {word}` and
  `total {float}`, the text `total 20` now runs the `{float}` step.
- Gherkin: step text and step patterns are split into words in the same
  way, at spaces, with a double-quoted run kept in one word. In 2.x the
  step text was also split where digits meet other characters.
- Gherkin: `parser.parse_file` returns `Result(Feature, FeatureFileError)`.
  In 2.x it returned `Result(Feature, String)`. `discover.list_files`
  returns a `Result`.
- A `types.Root` is no longer a `TestSuite`. Pass it to `suite.from_tree`.

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
