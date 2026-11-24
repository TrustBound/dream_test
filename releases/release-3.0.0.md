# Dream Test 3.0.0 Release Notes

**Release Date:** 2026-11-24

Dream Test 3.0.0 adds line coverage to the runner. It also runs the hooks of
each scope in a process that keeps their resources alive, follows the official
Gherkin grammar, and gives each Gherkin scenario one typed state value. This
is a major release: read the Migration Guide before you update.

## Key Highlights

- **Built-in line coverage**: `runner.coverage(coverage.new())` measures `src` with the line counters of the BEAM, prints a table and writes an LCOV file
- **A new hook process model**: the hooks of each scope run in one process that keeps their resources alive while the tests run
- **One suite type (breaking)**: one `TestSuite` type, with a setup and a teardown for a whole tree
- **Gherkin conformance**: the parser follows the official Gherkin grammar
- **Typed step state (breaking)**: each Gherkin scenario has one typed state value, and `world` is removed
- **Clearer failure reports**: a failure of more than one line, such as a changed snapshot, shows as a line diff, and a failure in a Gherkin step names the step, its file and its line
- **Guides for tests with recordings**: record HTTP calls and PostgreSQL queries one time, then play them back in CI with no network and no database

## What's New

### Built-in Line Coverage

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
- A new guide, `docs/guides/coverage-badge.md`, shows how to publish a
  live coverage badge from GitHub Actions to a `badges` branch, with no
  outside service.

### A New Hook Process Model

The `before_all` and `after_all` hooks of a group run in one setup process
that lives while the tests of the group run. A pool, a supervisor or an ETS table that a `before_all`
hook starts now lives for the tests of its group. A test runs its
`before_each` hooks, its body and its `after_each` hooks in one process.

- One rule for every hook failure: a failed setup hook gives `SetupFailed`
  to each test that it serves. A failed teardown hook keeps the test status,
  the other teardown hooks still run, and the run fails.
- `runner.run` returns a `types.RunReport` with the test results, the
  hook failures (failed teardown hooks and stopped setups) and the crashed `reporter_types.Custom` reporters. The BDD and Gherkin reporters show a
  `Setup and teardown failures:` section.
- When the process that keeps a setup alive stops, the runner reports the
  stopped setup one time and names each test that it did not run.
- A hook that crashes, never returns, or kills its own process does not stop
  the run.
- A test body past its timeout is `TimedOut`, not `Failed`.

### One Suite Type, and Setups for a Whole Tree

- Every suite has one type, `suite.TestSuite` in the new module
  `dream_test/suite`, whatever context its tests get. One `runner.new`
  takes `unit` suites, `unit_context` suites and Gherkin features together.
  `suite.group` and `suite.join` put suites together, and each keeps its
  own context.
- A context setup gives the context of a tree and runs once, only
  when at least one of its tests runs: `unit_context.describe_with_setup`
  for unit tests, and `steps.new_with_setup` for Gherkin scenarios, for
  example to start one server for all the scenarios of a feature.
- `steps.to_suite` makes one suite from several Features with one
  registry, so one setup serves all of them. Its children
  (`steps.SuiteChild`) are `Feature`, `Scenarios`, `Group`
  and `Node`.
- `suite.from_tree` turns a tree that you build by hand (`types.Tree`)
  into a `TestSuite`.
- Pending tests: `unit.pending(name)` and `unit_context.pending(name)` make
  a test with a name and no body, for a test skeleton. The reporters show
  it as pending, and the run still passes.

### Gherkin Conformance

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

### Typed Step State

The `world` key/value store is gone. Each scenario starts from the state that
you give to `steps.new(initial:)`. A `given` or `when` step gets the state and
returns the next state. A `then` step gets the state and returns an
assertion. The compiler now checks the type of the state in every step. For
example, `fn step_add(cart: Int, _context: StepContext) -> Result(Int, String)`
is a `when` step for a scenario whose state is an `Int`.

### Clearer Failure Reports

A changed snapshot, or any failure whose expected or actual text has more
than one line, shows as a line diff under the failure in the BDD and
Gherkin reports: `Diff (- expected, + actual):`, then `- ` for a line of
the expected text only, `+ ` for a line of the actual text only, and two
spaces for a line in both. Before, the report printed both whole texts,
with their second and later lines at the start of the line.

The diff is a longest common subsequence of the lines. It hides same
lines more than 3 lines from a change, shows at most 100 lines, makes
trailing whitespace and a missing final newline visible, and has a size
limit: above 1,000,000 line pairs, the changed lines show as removed, then
added. A value of one line keeps the `Expected:` and `Actual:` lines.
`dream_test/reporters/diff` gives the same diff to a reporter of your own.
[Lock down large output with snapshots](https://github.com/TrustBound/dream_test/blob/3.0.0/docs/guides/snapshot-testing.md)
shows a real report.

A failure in a Gherkin step names the step on a `Step:` line, with its
keyword and text as the feature writes them, and with its file and line
for a `.feature` file, for example
`Step: Then I should have 5 items total (test/features/shopping_cart_failures.feature:5)`.
A failed check, an `Error` from a step function, an undefined step and a
step that crashes read alike. The failure has the new payload
`types.StepFailure`, so the JSON report has the step too, as a `step`
object. [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/3.0.0/docs/guides/gherkin-bdd.md)
shows a real report.

### Guides

The guides moved from `documentation/` to `docs/guides/`. Their file names
have no number now, for example `docs/guides/writing-tests.md`. They are
rewritten by reader task: 16 guides and one reference page. Each guide
starts with a table of contents, walks through numbered steps with the
real output of each one, passing and failing, and ends with its failure
cases, a "Test your code" section and common pitfalls. A test compares
each output that a guide shows with the real output of the code. New
guides: "Write and run your first test" (`getting-started.md`), "Write
your own matcher" (`custom-matchers.md`), and the reference page
(`reference.md`) with every matcher, the runner settings, the rules of
hook processes and the Gherkin rules. Two more new guides show tests
with recordings: "Test HTTP calls with recordings" (`recorded-http.md`)
records the calls of an API client with `dream_http_client`, and "Test
database code with recorded queries" (`recorded-queries.md`) records
PostgreSQL queries with `dream_postgres`. Both play back in CI with no
network and no database. Their steps are tests, so they end with the CI
job in place of a "Test your code" section. Their code is the new project
`examples/recording`, and a new CI job runs its tests in playback mode.
A third new guide, "Mock at the system boundary"
(`mock-at-the-boundary.md`), explains the idea behind both: keep the
application code and the test assertions, and change what answers at
the dependency boundary. It shows the same suite in a live run and an
offline run, and what a recording proves.
Each example in the README has a guide badge. The badge links to the
guide section that shows the same example. HexDocs shows each guide as a
page.

## Testing

- 1244 tests run, 0 failed, in about 50 seconds of wall time (measured with a load average of about 9 from other programs), with 100.0% line coverage of `src` (3943 of 3943 lines). Apple M1 Max, OTP 29, Gleam 1.19.2

## Upgrading

Update your dependencies:

```toml
[dev-dependencies]
dream_test = ">= 3.0.0 and < 4.0.0"
```

Then run:

```bash
gleam deps update dream_test
```

### Requirements

- Gleam 1.19 or later for exact coverage line numbers. Older Gleam versions
  map only the first line of each function, and the coverage table warns
  about it.
- Erlang/OTP 27 or later with the JIT (the default on x86-64 and ARM64) for
  coverage. On another runtime, `coverage.start` fails with
  `NativeCoverageUnsupported`.

### Migration Guide

Each item that needs a code change has a 2.x and a 3.0.0 example in
[Upgrade from Dream Test 2.x to 3.0.0](https://github.com/TrustBound/dream_test/blob/3.0.0/docs/guides/upgrading-to-3.md).

- `runner.run` and `parallel.run_tree_parallel` return `types.RunReport`, and
  the reporter functions that format a whole run take one.
  `runner.has_failures` is now `types.failed`.
- Gherkin: `world` is removed, `steps.new` takes the initial state,
  `steps.when_` and `steps.then_` are now `steps.when` and `steps.then`,
  `steps.step` is removed, and a pattern defined two times in one phase is an
  error.
- Gherkin syntax tree and parser: `Scenario Outline` is a `Scenario` with
  `Examples`, `Step` has `doc_string` and `data_table`, parse errors are
  typed, and lines that the grammar does not permit are errors.
- Hook failures: setup failures give `SetupFailed`, and teardown failures
  go into the run report in place of fake `<after_all>` tests.
- The JSON report schema is `2.0`. Its `system` object has
  `gleam_stdlib_version` in place of `gleam_version`, with the same value:
  the version of the `gleam_stdlib` package. The JSON report ends with a
  newline.
- The summary line of the BDD and Gherkin reporters lists the extra counts
  in the order skipped, pending, timed out, setup failed, teardown failed,
  setup stopped, before ` in <duration>`. Each count shows only when it is
  not 0. `teardown failed` and `setup stopped` are new.
- `runner.exit_on_failure` stops the BEAM with `init:stop(1)`. Every test
  runs, and the runner writes all its output first. Then it ends the
  program with status 1 when a test fails, times out or has a failed
  setup, when a teardown hook fails, when a setup stops
  (`SetupStopped`), when a `reporter_types.Custom` reporter crashes, when
  the run ran no test, and when coverage fails.
- A run that runs no test fails. In 2.x it passed. A filter that keeps no
  test, or `runner.new([])`, gives such a run: the BDD and Gherkin
  reporters end with a `No tests ran` line, `types.failed(report)` is
  `True`, and with `exit_on_failure` the exit status is 1. A skipped or
  pending test is a test that ran. Add `runner.allow_no_tests()` to a
  runner that is empty on purpose.
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
- `types.Root` is now `types.Tree`, and `types.root` is now `types.tree`:
  a tree is one top-level group with its children and one context, and a
  suite holds one or more trees. The `parallel` functions take the tree
  with the label `tree:` in place of `suite:`.
- The start value has the label `initial` in place of `seed`, as in
  `steps.new(initial:)`: `unit_context.describe(name:, initial:,
  children:)`, `types.tree(name:, initial:, children:)` and the field
  `types.Tree.initial`. A call without labels does not change.
- The `parallel` names say "tree" in place of "root": `run_root_parallel`
  is now `run_tree_parallel`, `run_root_parallel_with_reporter` is now
  `run_tree_parallel_with_reporter`, and `RunRootParallelWithReporterConfig`
  and `RunRootParallelWithReporterResult` are now
  `RunTreeParallelWithReporterConfig` and
  `RunTreeParallelWithReporterResult`.
- `RunTreeParallelWithReporterConfig` has the new required field
  `outer_setups`. `RunTreeParallelWithReporterResult` has the new fields
  `hook_failures` and `outer_setups`.
- The `run` field of `types.Test` and of the hook nodes (`BeforeAll`,
  `BeforeEach`, `AfterEach` and `AfterAll`) is a `types.Callback`:
  `NoInput(run:)` or `WithInput(run:)`. In 2.x it was a function.
- Gherkin: `feature.InlineStep.keyword` is a `gherkin/types.StepKeyword` in
  place of a `String`. `discover.with_registry` returns the new type
  `discover.RunnableDiscovery(state)`, and `discover.to_suite` takes only
  that type.
- `types.Tree`, `types.TestResult` and `types.TestInfo` changed shape, and
  `types.ModuleCoverage` and `types.CoverageSummary` are removed.
- `TestSuite` has no type parameter and is in `dream_test/suite`, and
  `runner.RunBuilder` has no type parameter.
- `runner.before_each_test` and `runner.after_each_test` take
  `fn(TestInfo) -> Result(Nil, String)`: the hooks get the `TestInfo` of the
  test, not its context.
- Module discovery keeps the context of a suite with a context; in 2.x its
  tests got `Nil`.
- `types.AssertionResult` has the new variant `AssertionPending`.
- `types.FailurePayload` has the new variant `StepFailure(keyword:, text:,
  file:, line:, cause:)`. A `case` on a `FailurePayload` needs a branch for
  it. A failure in a Gherkin step has it as its payload, with the payload
  of the failure inside the step as `cause`: code that reads the payload
  of a failed scenario, such as an `EqualityFailure`, reads it from
  `cause`.
- Gherkin: `gherkin/types.Step` has the new field `line: Option(Int)`. Code
  that builds a `Step` gives `line: None`, or the line of the step.
- The progress event API changed: `progress.handle_event` and the reporter
  event types are removed; use `progress.line` with a
  `progress.ProgressEvent`.
- `types.TestKind.Integration`, `types.TestSuiteItem` and the module
  `dream_test/context` are removed.
- Gherkin: `find_step` and `step_trie` take a `StepPhase` in place of a
  keyword.
- A `discover.features` pattern that matches no files is an error, and so
  is a module discovery pattern that matches no test module.
- Gherkin: `feature.to_test_suite` and `FeatureConfig` are removed. A
  suite from one parsed Feature is `steps.feature_suite(registry:, feature:)`.
- Gherkin: `steps.given` and `steps.when` take the step function with the
  label `action:`, and `steps.then` with the label `check:`. In 2.x the
  label was `handler:`.
- Gherkin: `types.GherkinScenario` is
  `GherkinScenario(scenario_id:, feature:, rule:)`. In 2.x it held only the
  id. The BDD and Gherkin reporters print `Feature:` from `feature`, so
  both label the group of the Feature and no other group. The JSON report
  has `feature` and `rule` for a Gherkin test.
- Gherkin: `{float}` matches a number as Cucumber reads it, such as `20`,
  `.5` or `1e5`. In 2.x it needed a `.`. With `total {word}` and
  `total {float}`, the text `total 20` now runs the `{float}` step.
- Gherkin: step text and step patterns are split into words in the same
  way, at spaces, with a double-quoted run kept in one word. In 2.x the
  step text was also split where digits meet other characters.
- Gherkin: `parser.parse_file` returns `Result(Feature, FeatureFileError)`.
  In 2.x it returned `Result(Feature, String)`. `discover.list_files`
  returns a `Result`.
- A `types.Tree` (in 2.x `types.Root`) is no longer a `TestSuite`. Pass it
  to `suite.from_tree`.
- Docs: a link to a guide under `documentation/` no longer works. Link to
  the guide under `docs/guides/` with no number, for example
  `docs/guides/writing-tests.md` in place of
  `documentation/03-writing-tests.md`.

## Documentation

- [dream_test](https://hexdocs.pm/dream_test) - v3.0.0
- [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md)
- [Upgrade from Dream Test 2.x to 3.0.0](https://github.com/TrustBound/dream_test/blob/main/docs/guides/upgrading-to-3.md)
- [Measure line coverage and gate CI on it](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md)
- [Publish a coverage badge from your own CI](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage-badge.md)
- [Mock at the system boundary](https://github.com/TrustBound/dream_test/blob/main/docs/guides/mock-at-the-boundary.md)
- [Test HTTP calls with recordings](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md)
- [Test database code with recorded queries](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-queries.md)
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md)
- [Changelog](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)

## Community

- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream_test/issues)
- [Contributing](https://github.com/TrustBound/dream_test/blob/main/README.md#contributing)
