# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Typed Gherkin scenario state. `steps.new(initial:)` takes the state that
  each scenario starts from. A `given` or `when` step definition is an
  action, `fn(state, StepContext) -> Result(state, String)`. A `then` step
  definition is a check,
  `fn(state, StepContext) -> Result(AssertionResult, String)`.
  `steps.initial_state(registry)` gives the initial state.
  `StepContext.scenario_id` gives the id of the scenario.
- `types.Callback(input, output)` (`NoInput` and `WithInput`) and
  `types.call`. A test body or hook in a `Node` keeps the shape that the
  user wrote: `unit.before_all(setup)` stores
  `BeforeAll(NoInput(setup))`, and `unit_context.before_all(setup)` stores
  `BeforeAll(WithInput(setup))`.
- `types.RunReport`, the result of a run: the test results and the
  tear-down hooks that failed. Make one with `types.run_report(tests:,
  teardown_failures:)`, read it with `types.report_tests` and
  `types.report_teardown_failures`, and check it with `types.failed`.
  `RunReport` is opaque, so it can grow without a breaking change.
- `types.TeardownFailure(hook:, groups:, message:)` and
  `types.TeardownHook` (`AfterEachTestHook`, `AfterEachHook`,
  `AfterAllHook`, `AfterEachSuiteHook`, `AfterAllSuitesHook`), with
  `types.teardown_hook_name`.
- `types.SetupStopped(set_up:, groups:, reason:, not_run:)`, a variant of
  `types.TeardownFailure` for a set-up that stopped: the process that
  keeps its set-up alive exited while or after its set-up hooks ran.
  `not_run` is the full name of each test that had not started and was
  not run (see `types.full_name`). The runner records each test at the
  moment that it skips it. Also `types.SetUpHook` (`BeforeAllHook`,
  `BeforeEachSuiteHook`, `BeforeAllSuitesHook`) with
  `types.set_up_hook_name`. The BDD and Gherkin reporters show a stopped
  set-up as
  `before_all in "<groups>" stopped: the process that keeps its set-up alive exited with <reason>.`,
  then `These tests had not started and were not run:` and the full name
  of each test, for example `root > b` (the list only when tests were not
  run). The JSON reporter gives it as `{"kind": "setup_stopped", "hook":
  "before_all", "groups": [...], "message": "<reason>", "not_run":
  [["root", "b"], ...]}`, with each test as its `full_name` list, and each
  failed tear-down hook now has `"kind": "hook_failed"`.
- `sandbox.OwnerLost(reason)`: `run_in_owner` gives it when the owner had
  stopped before it started the function, so the function did not run.
- `types.is_failure(status)`, the one check for a failure status
  (`Failed`, `SetupFailed`, `TimedOut`). The runner, the BDD reporter and
  `types.failed` use it.
- `dream_test/reporters/teardown` (`format`, `format_in_color`) gives the
  `Set-up and tear-down failures:` section that the BDD and Gherkin
  reporters show.
  Each function takes the list of tear-down failures, for example
  `types.report_teardown_failures(report)`.
- `sandbox.run_catching(run:, input:)` runs a function in the calling
  process and gives `Ok(value)`, or `Error("class:reason")` when the
  function crashes. No new process starts, so a resource that the function
  starts stays alive after it returns.
- `progress.line` and `progress.ProgressEvent`. `progress.line` gives the
  text of the progress bar for the start of a run, a finished test, or the
  end of a run. It always gives a line, because `ProgressEvent` has no hook
  events. The runner uses it.
- `sandbox.run_in_owner`, `sandbox.check_owner` and `sandbox.stop_owner`
  with the types `sandbox.Owner` and `sandbox.OwnerResult`. An owner
  process runs functions one after another with a timeout for each, and
  stays alive between them, so a pool or an ETS table that one function
  starts lives for the next function. The runner uses owners for the
  hooks of each scope.
- `sandbox.format_exit_reason` gives the text of a process exit reason, in
  the same form that `run_isolated` and the parallel runner use for a crash
  (`"normal"`, `"killed"`, or the inspected reason). Use it in a custom
  runner to show a crash reason the same way as dream_test.
- `gherkin.format_scenarios` gives the feature and scenario lines of the
  Gherkin reporter without the summary line. Use it in a reporter that
  writes its own summary. The BDD reporter now uses it, in place of a
  removal of the summary line from the full Gherkin report.
- `dream_test/reporters/summary` gives the summary line of the BDD and
  Gherkin reporters (`summary.format` and `summary.format_in_color`) and
  the counts behind it (`summary.count`, which gives `summary.Counts`). Use
  it in a custom reporter to give the same summary as dream_test. The BDD,
  Gherkin and JSON reporters now use it, in place of three copies of the
  same count code.
- `ansi.apply_if` applies a style only when colour is on. Use it in a
  reporter with a colour option.
- The Gherkin `*` step keyword. In a `.feature` file, `* I pack a passport`
  is a step. In the inline DSL, `feature.asterisk("I pack a passport")`
  makes one. A `*` step takes the phase of the step before it, like `And`
  and `But`. `gherkin/types.StepKeyword` has the new `Asterisk` variant.
- `gherkin/types.StepPhase` (`GivenPhase`, `WhenPhase`, `ThenPhase`): the
  phase of a step, which maps to Arrange, Act and Assert.
  `gherkin/types.resolve_phase` gives the phase of a step from its keyword
  and the phase before it. `gherkin/types.phase_to_string` gives the name
  of a phase.
- `gherkin/steps.validate` returns the duplicate step definitions of a
  registry, one line for each.

- Gherkin `Rule:` sections. `gherkin/types.Rule` holds the name,
  description, tags, an optional Background and the scenarios of a Rule.
  `Feature.rules` holds the Rules. The steps of the Feature Background run
  first, then the steps of the Rule Background, then the scenario steps.
  Each Rule runs as a group named `Rule: <name>`, so the full name of a
  scenario in a Rule is `Feature > Rule: <name> > Scenario`. The Gherkin
  reporter prints the Rule as a heading under its feature.
- More than one `Examples` section for each scenario. `gherkin/types.Examples`
  holds the name, description, tags and table of a section, and every row
  of every section runs. The tags of a section apply to the tests that its
  rows make. A test of an `Examples` row is named
  `<scenario> (<examples name>, Example N)`, or `<scenario> (Example N)`
  when the section has no name. N counts the rows of all sections, from 1.
- The English keyword synonyms of Gherkin: `Business Need:` and `Ability:`
  for `Feature:`, `Example:` for `Scenario:`, `Scenario Template:` for
  `Scenario Outline:`, `Scenarios:` for `Examples:`, and the ```` ``` ````
  DocString separator.
- `gherkin/types.ScenarioKeyword` and
  `gherkin/types.scenario_keyword_to_string`: the keyword that starts a
  scenario.
- The name and description of a Background, and the description of a
  scenario, a Rule and an `Examples` section.
- Conformance tests for the Gherkin parser, from the official Gherkin
  test files: 37 good files parse to the official structure, 12 bad files
  give the official error line, and 8 good files that dream_test rejects on
  purpose give the dream_test error. The fixture README lists the skipped
  files and the reasons.
- `gherkin/parser.ParseError`, `ParseProblem`, `TokenKind` and
  `FeatureFileError`: typed parse errors, with one `ParseProblem` variant
  for each kind of problem. `parser.problem_to_string`,
  `parser.parse_error_to_string`, `parser.feature_file_error_to_string` and
  `parser.token_kind_to_string` give the messages.

### Changed

- BREAKING: the Gherkin `world` key/value store is removed, with
  `dream_test/gherkin/world` (`put`, `get`, `get_or`, `has`, `delete`,
  `scenario_id`, `new_world`, `cleanup`) and its ETS table. Each scenario
  made one atom that was never freed. The state is now one typed value that
  each step gets and a `given` or `when` step returns. Before:
  `fn step_add(context: StepContext) { put(context.world, "cart", get_or(context.world, "cart", 0) + 1) Ok(succeed()) }`.
  After: `fn step_add(cart: Int, _context: StepContext) { Ok(cart + 1) }`.
- BREAKING: `steps.new()` takes the initial scenario state, and
  `StepRegistry`, `FeatureConfig` and `discover.RunnableDiscovery` take
  the state type as a type parameter. Before: `steps.new()`. After:
  `steps.new(initial: 0)`, of type `StepRegistry(Int)`.
- BREAKING: the phase of a step definition sets its kind. `steps.given`
  and `steps.when` take an action (labelled `action`),
  `fn(state, StepContext) -> Result(state, String)`. `steps.then` takes a
  check (labelled `check`),
  `fn(state, StepContext) -> Result(AssertionResult, String)`. A check
  cannot change the state. The `StepHandler` type is removed. `find_step`
  gives a `StepMatch(StepDefinition(state))`: a `given` or `when`
  definition comes back as `Action(run)`, and a `then` definition as
  `Check(run)`. Before:
  `fn step_add(context: StepContext) -> Result(AssertionResult, String)`
  with `steps.when_("I add {int} items", step_add)`. After:
  `fn step_add(cart: Int, context: StepContext) -> Result(Int, String)`
  with `steps.when("I add {int} items", step_add)`.
- BREAKING: `steps.when_` is now `steps.when`, and `steps.then_` is now
  `steps.then`. The public API has no names with a trailing underscore.
  Before: `|> steps.when_("I add {int} items", add)`. After:
  `|> steps.when("I add {int} items", add)`.
- BREAKING: `StepContext` has no `world` field. It has a `scenario_id`
  field. Before: `world.scenario_id(context.world)`. After:
  `context.scenario_id`.
- BREAKING: the old progress event API is removed:
  `reporters/types.ReporterEvent` (`RunStarted`, `TestFinished`,
  `HookStarted`, `HookFinished`, `RunFinished`),
  `reporters/types.HookKind`, `reporters/types.HookOutcome` and
  `progress.handle_event`. The runner never sent these events, and
  `RunFinished` always gave 0 tear-down failures. Before:
  `progress.handle_event(reporter, reporter_types.RunStarted(total: 4))`
  gave `Some(text)`. After:
  `progress.line(reporter, progress.RunStartedProgress(total: 4))` gives
  `text`.
- BREAKING: `progress.render(columns, event)` takes a
  `progress.ProgressEvent` in place of a `ReporterEvent`. The last line now
  counts the tear-down failures, the same as `progress.line`. Before:
  `progress.render(30, reporter_types.RunStarted(total: 10))`. After:
  `progress.render(30, progress.RunStartedProgress(total: 10))`.
- BREAKING (only for code that builds `types.Node` values directly): the
  `run` field of `Test`, `BeforeAll`, `BeforeEach`, `AfterEach` and
  `AfterAll` is a `types.Callback`, not a function. Before:
  `types.BeforeAll(fn(_context) { setup() })`. After:
  `types.BeforeAll(types.NoInput(setup))`, or
  `types.BeforeAll(types.WithInput(setup_with_context))`. Code that uses
  `unit` or `unit_context` does not change.
- BREAKING: one rule for every hook failure. A failed set-up hook
  (`before_all_suites`, `before_each_suite`, `before_all`, `before_each`,
  `before_each_test`) gives `SetupFailed` to each test that it serves. A
  failed tear-down hook (`after_each_test`, `after_each`, `after_all`,
  `after_each_suite`, `after_all_suites`) does not change a test status,
  all the remaining tear-down hooks still run, and the failure goes into
  the tear-down list of the run report. The run then fails.
  - Before: `before_all_suites` and `before_each_suite` failures gave
    `Failed`. After: `SetupFailed`.
  - Before: an `after_each` or `after_each_test` failure changed the test
    status to `Failed`, also for `TimedOut`, `Skipped` and `SetupFailed`.
    After: the status stays, and the report has
    `TeardownFailure(hook: AfterEachHook, groups: <full test name>, ...)`.
  - Before: an `after_all`, `after_each_suite` or `after_all_suites`
    failure added a fake test (`<after_all>`, `<after_each_suite>`,
    `<after_all_suites>`) that changed the test count, and the later hooks
    of the same kind did not run. After: no fake test, every hook runs,
    and the report has one `TeardownFailure` for each failure.
- BREAKING: `runner.run` returns `types.RunReport`, not
  `List(TestResult)`. Before: `let results = runner.run(builder)`. After:
  `let results = runner.run(builder) |> types.report_tests`.
- BREAKING: `runner.has_failures` is removed. Before:
  `runner.has_failures(results)`. After: `types.failed(report)`, which is
  also `True` for a tear-down failure.
- BREAKING: `parallel.run_root_parallel` returns `types.RunReport`, not
  `List(TestResult)`, and `parallel.RunRootParallelWithReporterResult` has
  a new field `teardown_failures`. Before: `run_root_parallel(config,
  suite) |> list.length`. After: `run_root_parallel(config, suite) |>
  types.report_tests |> list.length`.
- BREAKING: `parallel.RunRootParallelWithReporterConfig` has a new field
  `outer_setups: List(parallel.OuterSetup)`, and
  `parallel.RunRootParallelWithReporterResult` has a new field
  `outer_setups` that gives the same set-ups after the run. An
  `OuterSetup` is a set-up around the suite that keeps its resources
  alive in a process, for example the `before_all_suites` or
  `before_each_suite` set-up: `SetupRunning(set_up:, groups:,
  check_owner:)` or `SetupStopped(set_up:, groups:, reason:, not_run:)`.
  The executor checks each one before each test and each group starts.
  After a set-up stopped, the tests of the suite that did not start are
  `SetupFailed`, no hook of the suite starts, and the executor adds the
  full name of each of these tests to `not_run` of the outermost stopped
  set-up. Before:
  `RunRootParallelWithReporterConfig(config:, suite:, progress_reporter:,
  write:, total:, completed:, runner_before_each_test:,
  runner_after_each_test:)`. After: add `outer_setups: []` to the config,
  and `outer_setups: _outer_setups` to a pattern that takes the result
  apart.
- When the set-up of the whole run (`before_all_suites`) or of a suite
  (`before_each_suite`) stops while the tests of a suite run, the tests of
  that suite that did not start are not run. Before, they ran, and only
  the later suites stopped. Each one is `SetupFailed` with
  `not run: the set-up from before_all_suites stopped (<reason>)` or
  `not run: the set-up from before_each_suite in "<suite>" stopped (<reason>)`,
  and the stopped set-up is reported once as `types.SetupStopped`.
- BREAKING: the reporter functions that format a whole run take a
  `types.RunReport`: `bdd.render`, `bdd.format`, `bdd.report`,
  `bdd.format_summary_only`, `json.render`, `json.format`,
  `json.format_pretty`, `json.report`, `json.report_pretty`,
  `gherkin.format` and `gherkin.report`. The `report` functions return the
  report. The new `summary.count`, `summary.format` and
  `summary.format_in_color` take a `RunReport` too.
  Before: `bdd.format(results)`. After: `bdd.format(report)`, or
  `bdd.format(types.run_report(tests: results, teardown_failures: []))`.
- BREAKING: the JSON schema version is `2.0`. `summary` has a new count
  `teardown_failed`, and the object has a new list `teardown_failures` of
  `{"hook", "groups", "message"}` objects. Fake tests such as `<after_all>`
  are no longer in `tests`.
- BREAKING: `progress.RunFinishedProgress` has a new field
  `teardown_failures`. The last progress line says
  `done, 1 tear-down failed` when a tear-down hook failed.
- The BDD and Gherkin reporters show a `Set-up and tear-down failures:`
  section before the summary, and the summary line adds
  `N tear-down failed`.
  `summary.Counts` has a new field `teardown_failed`, and
  `coverage.RunOutcome` has a new field `teardown_failed`.
- `exit_on_failure` stops with status 1 when a tear-down hook failed, also
  when every test passed.
- Each scope has one owner process for its hooks. The `before_all` and
  `after_all` hooks of a group run in one owner process of the group, the
  `before_each_suite` and `after_each_suite` hooks in one owner process of
  the suite, and `before_all_suites` and `after_all_suites` in one owner
  process of the run. The owner lives while the tests of its scope run.
  Each hook still gets the default timeout, and the messages are the same
  as before: `hook timed out in <scope>` and `hook crashed in <scope>: ...`.
- BREAKING: A test runs in one process: the `before_each_test` hooks, the
  `before_each` hooks, the body, the `after_each` hooks and the
  `after_each_test` hooks. Before, each hook and the body ran in its own
  process. The runner waits for each step with its timeout: the default
  timeout for a hook, the test timeout for the body. A body that sees
  `process.self()` now sees the same process as its hooks. A test process
  that stops during the body gives `Failed` with
  `crash: worker crashed in <group>: <reason>`. Before, a body that killed
  its own process gave `crash: killed`.
- BREAKING: `sandbox.run_isolated` now takes the function and its input as
  two parameters: `run_isolated(config:, run: fn(input) -> a, input:)` in
  place of `run_isolated(config:, test_function: fn() -> a)`. The function
  gets `input` as its argument, so a caller can pass a named function and
  its data and needs no closure. Before:
  `sandbox.run_isolated(config, fn() { double(21) })`. After:
  `sandbox.run_isolated(config, double, 21)`. A function with no data
  takes `Nil`: `sandbox.run_isolated(config, loop_forever, Nil)`.
- `runner.exit_on_failure` now stops the BEAM with `init:stop(1)` in place
  of `erlang:halt(1)`. This is how Gleam itself stops a `main` that
  crashes. The BEAM shuts down cleanly: the output is written and
  applications stop. The exit status is still 1. Code after `runner.run`
  can still run until `main` returns or the shutdown stops it; before, the
  BEAM stopped inside `runner.run`.
- BREAKING: A test body that runs past its timeout is now always
  `TimedOut`. Before, a sequential run (`max_concurrency` 1) gave
  `Failed`, and a parallel run gave `TimedOut` or `Failed`, by which of two
  deadlines ended first. Now the timeout of the body is the only
  deadline. It counts from the start of the body, and each hook has its own
  timeout. The failure is still `timeout: test timed out`, and the
  `after_each` hooks still run.
- BREAKING: When a `before_all` hook fails, times out or crashes, the tests
  of its group and of every group inside it are now `SetupFailed`, as the
  docs of `types.Status` say. Before, they were `Failed`. The failure is
  still `before_all` with the hook's message.
- BREAKING: `types.Root` now holds the top-level group itself:
  `Root(seed:, name:, tags:, children:)` in place of
  `Root(seed:, tree: Group(name:, tags:, children:))`. Before, a root whose
  tree was a single `Test` never ran, and no error said so. Now a suite is
  always a group. Code that builds suites with `describe`, `feature`,
  `types.root` or discovery does not change.
- BREAKING: `types.TestResult` and `types.TestInfo` now hold
  `groups: List(String)` (the names of the groups around the test) in place
  of `full_name: List(String)`. The test name is the `name` field, so a
  full name can no longer be empty or end with a name other than the test
  name. Before, `full_name: []` was possible, and the BDD reporter wrote
  `✓ ` and the Gherkin reporter `Unknown Scenario` for it. The new function
  `types.full_name(groups, name)` gives the old list. Code that builds or
  reads these records by hand must change, for example
  `TestResult(name: "adds", full_name: ["Cart", "adds"], ..)` becomes
  `TestResult(name: "adds", groups: ["Cart"], ..)`, and
  `info.full_name` becomes `types.full_name(info.groups, info.name)`. The
  JSON report still writes `full_name` as the full list.
- BREAKING: The summary line of the BDD and Gherkin reporters now lists the
  extra counts in the order skipped, pending, timed out, setup failed.
  Before, the order was the reverse: `1 setup failed, 1 timed out,
  1 pending, 1 skipped`. Now it is `1 skipped, 1 pending, 1 timed out,
  1 setup failed`. Update tests or tools that compare the exact summary
  text.
- BREAKING: `gherkin/feature.InlineStep` now holds
  `keyword: gherkin/types.StepKeyword` in place of `keyword: String`.
  Before, an unknown keyword such as `"Gvien"` became `Given` without a
  message. Now a wrong keyword cannot compile. The `given`, `when`, `then`,
  `and` and `but` helpers do not change. Code that builds the record by hand
  must change, for example `InlineStep(keyword: "When", text: "I add 3")`
  becomes `InlineStep(keyword: gherkin_types.When, text: "I add 3")`.
- BREAKING: `gherkin/discover.with_registry` now gives a new opaque type,
  `RunnableDiscovery`, and `gherkin/discover.to_suite` takes only that type.
  Before, `to_suite` took a `FeatureDiscovery` and panicked when no registry
  was attached. Now a suite without step definitions cannot compile. The
  usual call
  `discover.features("test/*.feature") |> discover.with_registry(steps) |> discover.to_suite("features")`
  does not change. Code that writes the type of the `with_registry` result
  must change `FeatureDiscovery` to `RunnableDiscovery`, and code that called
  `to_suite` without `with_registry` must add the call.

- BREAKING: `gherkin/steps.step` is removed. Each step definition now
  belongs to exactly one phase. Before, `step` matched a step of any
  keyword. Now register it with `given`, `when` or `then`, for example
  `|> steps.step("I add {int} items", add)` becomes
  `|> steps.when("I add {int} items", add)`. To use one pattern in two
  phases, register it in each phase.
- BREAKING: `gherkin/types.StepKeyword` has a new variant, `Asterisk`, for
  the `*` keyword. A `case` on `StepKeyword` must add a branch for it.
- BREAKING: `gherkin/steps.find_step` now takes `phase: StepPhase` in place
  of `keyword: StepKeyword`, for example
  `find_step(registry, Given, "I have 3 items")` becomes
  `find_step(registry, GivenPhase, "I have 3 items")`. Resolve an `And`,
  `But` or `*` step with `types.resolve_phase` first.
- BREAKING: `gherkin/step_trie.insert` and `gherkin/step_trie.lookup` now
  take `phase: StepPhase` in place of a keyword `String`, and the trie has
  no `"*"` wildcard handler. `insert` now returns
  `Result(StepTrie(handler), String)`: a second handler for the same phase
  and pattern is an `Error` in place of a silent replacement.
- BREAKING: A pattern registered two times in one phase is now an error.
  Before, the second definition replaced the first without a message. Now
  `given`, `when` and `then` keep the first definition and record the
  error. `find_step` and `validate` return it, and each scenario that uses
  the registry fails with it, for example
  `Duplicate step definition: Given "I have {int} items" is already defined. Each pattern can have one definition for each of Given, When and Then.`
  The same pattern in two phases is not a duplicate.
- BREAKING: The first step of a Background, and of a Scenario or Scenario
  Outline when the Background has no steps, must use Given, When or Then.
  Before, a leading `And` or `But` was matched as a `Given` step. Now a
  `.feature` file with a leading `And`, `But` or `*` gives a parse error
  that names the line, for example
  `line 3: "And a" has no step before it. ...`. An inline feature with a
  leading `And`, `But` or `*` fails each scenario with the same message
  before any step runs. When the Background has steps, a Scenario can start
  with `And`, `But` or `*`: the step takes the phase of the last Background
  step.
- `gherkin/parser.parse_file` now puts the path at the start of a parse
  error, for example
  `test/cart.feature: line 3: "And a" has no step before it. ...`.
  `gherkin/discover` gives the same error text as before.
- A step line in a feature description, before the first Background or
  Scenario, is now description text. Before, a `Given`, `When`, `Then`,
  `And` or `But` line there was dropped. A `* ` list item in a description
  stays description text.

- BREAKING: `gherkin/types.Scenario` is now one record,
  `Scenario(keyword, name, description, tags, steps, examples)`, with
  `examples: List(Examples)`. The `ScenarioOutline` variant is removed.
  Before: `ScenarioOutline(name: "O", tags: [], steps: steps, examples: table)`.
  After: `Scenario(keyword: KeywordScenarioOutline, name: "O", description: None, tags: [], steps: steps, examples: [Examples(name: "", description: None, tags: [], table: Some(table))])`.
- BREAKING: `gherkin/types.Background` now holds `name` and `description`.
  Before: `Background(steps: steps)`. After:
  `Background(name: "", description: None, steps: steps)`.
- BREAKING: `gherkin/types.Feature` has a new field, `rules: List(Rule)`.
  Add `rules: []` where you build a `Feature`.
- BREAKING: `gherkin/parser.parse_string` now returns
  `Result(Feature, ParseError)` in place of `Result(Feature, String)`.
  `parser.parse_error_to_string` gives the old `line N: ...` text.
- BREAKING: `gherkin/parser.parse_file` now returns
  `Result(Feature, FeatureFileError)` in place of `Result(Feature, String)`.
  `parser.feature_file_error_to_string` gives the message: `<path>: line N:
  ...` for an invalid file, and `Failed to read feature file: ...` for a
  file that cannot be read.
- BREAKING: `gherkin/discover.LoadResult.errors` is now
  `List(parser.FeatureFileError)` in place of `List(String)`. Use
  `parser.feature_file_error_to_string` for the old text.
- BREAKING: The Gherkin parser now follows the official Gherkin grammar.
  A line that the grammar does not permit at its position is now an
  `UnexpectedLine` error. Before, the parser ignored it. Examples: text
  after the steps of a scenario, a Background after a scenario, and a step
  after an `Examples` table. Text below a header line (also a line that
  starts with `|` or `"""`) is the description of that header, as in
  Gherkin.
- BREAKING: Every parse error message now starts with `line N:`. The
  messages for an unclosed DocString and for an unexpected line changed:
  `DocString is not closed` is now
  `The DocString that starts on line N is not closed`.
- BREAKING: A description now keeps the leading whitespace of each line and
  the empty lines between its text lines, as Gherkin does. Before:
  `Some("First line\nSecond line")`. After:
  `Some("  First line\n\n  Second line")`.
- BREAKING: The test of an `Examples` row now has the row label in its
  name. Before, each row test was named `<scenario>` and only its id had
  `(Example N)`. After: `<scenario> (Example N)`, or
  `<scenario> (<examples name>, Example N)`.
- BREAKING: A scenario with no `Examples` section now runs one time, also
  when its keyword is `Scenario Outline`. Before, an outline with no
  `Examples` made no tests.
- BREAKING: A tag line is now read as Gherkin reads it. `@a@b` is two tags,
  `@tag #comment` ignores the comment, and a tag with whitespace in it
  (`@a b`) is a `TagContainsWhitespace` error. Before, `@a b` gave the tag
  `a`.
- BREAKING: A `# language:` line before the Feature must name `en`.
  Another language is an `UnsupportedLanguage` error. Before, the line was
  a comment.
- BREAKING: `gherkin/types.Step` now holds `doc_string: Option(DocString)`
  and `data_table: Option(DataTable)` in place of
  `argument: Option(StepArgument)`, so that a step can have both arguments.
  The `StepArgument` type is removed; `DocString(content:, content_type:)`
  and `DataTable(rows:)` are now types of their own. Before:
  `Step(keyword: Given, text: "a", argument: Some(DataTable(rows: rows)))`.
  After:
  `Step(keyword: Given, text: "a", doc_string: None, data_table: Some(DataTable(rows: rows)))`.
  Step handlers do not change: they still read `context.table` and
  `context.doc_string`.
- BREAKING: `gherkin/types.resolve_keyword` is removed. Use
  `gherkin/types.resolve_phase`. Before: `resolve_keyword(And, Given)` gave
  `Given`. After: `resolve_phase(keyword: And, previous: Some(GivenPhase))`
  gives `Ok(GivenPhase)`.

### Fixed

- The capture helpers of `dream_test/gherkin/steps` (`get_int`,
  `get_float`, `get_string`, `get_word`) give an error that names the
  capture. Before: `Capture at index is not an integer` and
  `No capture at index`. After:
  `Capture 0 is the word "apples", not an integer` and
  `No capture at index 2: the step has 1 capture`.
- A resource that a group `before_all` hook starts now lives for the tests
  of the group. Before, the hook ran in a short-lived process, so a pool
  that links to its caller (for example a supervisor) and an ETS table
  stopped before the first test ran.
- A crash in a suite-level hook (`before_all_suites`, `before_each_suite`,
  `after_each_suite`, `after_all_suites`) no longer stops the whole run.
  The runner catches it and records it as a failure of that hook, with the
  message `hook crashed: <reason>` or `hook crashed in <suite>: <reason>`.
  These hooks run in the owner process of their scope, so the resources
  that they start live until the tear-down hooks of the scope end.
- A resource that a `before_each` hook starts now lives for the body and
  the `after_each` hooks of the test. Before, the hook ran in a
  short-lived process, so a pool and an ETS table stopped before the body
  ran.
- A suite-level hook or a group `before_all` or `after_all` hook that never
  returns no longer stops the run. A set-up hook gives `SetupFailed` with
  `hook timed out` or `hook timed out in <scope>`, and a tear-down hook
  gives a tear-down failure with the same message.
- A hook that kills its owner process no longer stops the run. The runner
  monitors the owner. A tear-down hook that kills its owner is recorded as
  `hook crashed in <scope>: <reason>`, and the next hook of the scope runs
  in a new owner process.
- A set-up is reported by its cause, not by its timing. When the owner
  process of a set-up exits, while a `before_all`, `before_each_suite` or
  `before_all_suites` hook runs or between two of them, the set-up
  stopped: it is reported as `types.SetupStopped`, no other set-up hook
  of the scope runs, and each test of the scope is `SetupFailed` with
  `not run: the set-up from <set-up hook> ... stopped (<reason>)`. A
  set-up hook that returns `Error` or crashes inside the hook is still
  `hook crashed in <scope>: <reason>` (or its error message), and a hook
  that never returns is still `hook timed out in <scope>`. Before, an
  owner that exited during a set-up hook was reported as
  `hook crashed in <scope>: <reason>`.
- A set-up whose process stops while the tests of its scope run is now
  reported as a stopped set-up, `types.SetupStopped`, not as a failure of
  a tear-down hook. The tests of the scope that did not start yet are not
  run: each one is `SetupFailed` with
  `not run: the set-up from before_all in "<group>" stopped (<reason>)`,
  `not run: the set-up from before_each_suite in "<suite>" stopped (<reason>)`
  or `not run: the set-up from before_all_suites stopped (<reason>)`. The
  tear-down hooks of the scope run in a new owner process.
- A tear-down hook always runs when the owner of its scope stops just
  before the hook starts. Before, the hook was reported as crashed and did
  not run. `run_in_owner` now knows if the owner started the function, and
  the runner runs the hook again in a new owner.
- The `after_each` and `after_each_test` hooks now run when the test
  process stops, for example when a linked process crashes. Before, a
  test process that stopped skipped them. They run in a new process with
  their own timeouts and get the context after the last `before_each` hook
  that returned. The test keeps its status.
- Coverage no longer counts the line of a function with an
  `@external(erlang, ...)` attribute. Gleam code never calls the wrapper
  that Gleam compiles for such a function, so the line was always shown as
  missing. A function without the attribute whose body only calls an
  external is still counted.
- `match_snapshot` and `match_snapshot_inspect` now ignore a CRLF (`\r\n`)
  line end at the end of a snapshot file, as they already did for `\n` and
  `\r`. Before, a snapshot file saved with Windows line ends did not match
  the same text.
- A Gherkin step can now have both a DataTable and a DocString, in either
  order, as in the official Gherkin grammar. The step handler gets both, in
  `context.table` and `context.doc_string`. Before, the parser kept one
  argument and dropped the other without a message. A second DocString on
  one step is a `RepeatedDocString` error.
- The values of an `Examples` row now replace the `<header>` placeholders
  in the scenario name, the DocStrings (content and media type) and the
  DataTable cells, as in the official Gherkin compiler. Before, only the
  step text changed, so a test was named `the <one> (Example 1)` in place
  of `the un (Example 1)`. The headers now replace in column order; before,
  the order was not defined, so with two columns of the same name either
  value could win. Now the first column wins.
- A scenario with no steps now runs no Background steps, as in the official
  Gherkin compiler. Before, the Background steps ran, so a failing
  Background step failed a scenario with no steps.
- The Feature tags now appear one time in the tags of a Gherkin test.
  Before, a test of a Feature tagged `@f` with a scenario tagged `@s` had
  the tags `["f", "f", "s"]`; now it has `["f", "s"]`. The Feature keeps its
  tags, each Rule group now holds its own tags, and each test holds the
  scenario and `Examples` tags. The order is still Feature, Rule, scenario,
  `Examples`.
- The Gherkin parser now gives an error for a DocString that has no closing
  `"""`. Before, the DocString took all the lines to the end of the file, and
  the parser dropped the scenarios in those lines without a message.
- `file.delete_files_matching` and `snapshot.clear_snapshots_in_directory`
  now read the directory name as text. Before, they made a wildcard pattern
  from the name, so a name with `{`, `[`, `*` or `?` gave a `badpattern`
  error or deleted files in other directories.
- `timing.format_duration_us` now gives `"0.0ms"` for a negative duration,
  the same as for `0`. Before, it gave text such as `"0.-5ms"`.
- `sandbox.run_isolated` without crash reports now gives `SandboxCrashed`
  when an exit signal stops the worker, for example when a linked process
  crashes. Before, it waited for the full timeout and gave `SandboxTimedOut`.
- `sandbox.run_isolated` now waits only for the down message of its own
  worker, and removes that message when it returns. Before, with crash
  reports on, it left the down message in the mailbox, and a later call in
  the same process took it and gave `SandboxCrashed("normal")`.
- `sandbox.run_isolated` without crash reports now gives the crash reason
  of `SandboxCrashed` as a `String`. Before, it was an Erlang charlist, so
  the parallel runner crashed when it put the reason of a crashed hook in
  its error text.
- The Gherkin reporter now writes the failures of a timed out scenario,
  for example `timeout` with its message, under the scenario line. The BDD
  reporter already did this. Before, the Gherkin reporter showed only the
  `!` marker and no reason.
- Pretty JSON (`json.format_pretty`, `json.report_pretty` and the JSON
  reporter with `pretty`) now writes an empty list as `[]`. Before, it
  wrote `[`, a line of spaces, and `]`. Compact JSON does not change.
- `gherkin/discover.to_suite` now gives the full file path as the source of
  a parse error test. Before, it cut the path at the first `": "`, so a
  path such as `features/a: b.feature` gave the source `features/a`.
- The Gherkin parser now gives the error
  `Step cannot have more than one DocString` for a step with two
  DocStrings. Before, it kept the second DocString and dropped the first
  without a message.
- The Gherkin parser now removes the indentation of the opening `"""` from
  each DocString line, as standard Gherkin does. A line with less
  indentation loses only the indentation it has. Before, each line kept
  all its indentation, so a DocString inside an indented step started with
  spaces.
- The Gherkin parser now reads `Background: <name>` and `Examples: <name>`.
  Before, it read only `Background:` and `Examples:` with no name. With a
  name, the parser ignored the line, so the background steps went to no
  background and the Examples rows went to no table. The name is not kept,
  because `Background` and `ExamplesTable` have no field for it.
- The BDD reporter without colour now writes the skipped, pending, timed out
  and setup failed counts of its summary as plain text. Before, it put ANSI
  colour codes around these counts, also when colour was off.

- A table cell can now be empty. Before, `| a | | b |` gave `["a", "b"]`.
  Now it gives `["a", "", "b"]`.
- A table cell now unescapes `\|`, `\\` and `\n`. The text before the
  first `|` and after the last `|` of a row is not a cell.
- A table row with a different number of cells than the first row of its
  table is now an `InconsistentCellCount` error.
- The Gherkin reporter now uses the feature name for the `Feature:` line
  of a discovered feature. Before, it used the suite name, because the
  suite name is the first group.

## [2.2.0] - 2026-11-17

### Added

- **Line coverage** (`dream_test/coverage`, `runner.coverage`)

  - Opt-in line coverage with the native line counters of the BEAM, which
    need Erlang/OTP 27 or later with the JIT. The runner prints a coverage
    table after the results and writes an LCOV file to
    `build/coverage/lcov.info` (`coverage.lcov_path`, `coverage.no_lcov`)
  - More than one coverage run can measure in one BEAM, as long as no module
    is in two runs at the same time. Coverage never stops a process that
    runs old code of a measured module
  - `coverage.source_directory` measures one folder in place of `src`
  - `coverage.show_missing` adds a `Missing` column with the line ranges that
    did not run
  - `coverage.minimum_percent` and `coverage.minimum_percent_per_file` fail
    the run when the total or one file is below the minimum
  - `runner.coverage_from_environment` turns coverage on only when
    `DREAM_TEST_COVERAGE` is `1` or `true`
  - Every coverage error fails the run with a `Coverage failed` message that
    gives what failed, the reason and the fix

- **Coverage exclusions** (`dream_test/coverage`)

  - `coverage.exclude` and `coverage.exclude_with_reason` remove files that
    match a pattern
  - `coverage:ignore`, `coverage:ignore-start` / `coverage:ignore-end` and
    `coverage:ignore-function` comment markers ignore lines, blocks and whole
    functions in `.gleam` and `.erl` files. Text after a marker is its reason
  - A count line after the total shows what was excluded.
    `coverage.show_excluded` adds an `Excluded` column with the reasons, and
    `coverage.require_exclusion_reasons` fails the run when a reason is missing

- **Coverage table options** (`dream_test/reporters/coverage`)

  - `coverage.color`, `coverage.sort_by_coverage` and `coverage.hide_complete`
  - `dream_test/reporters/ansi` holds the ANSI colour helpers

- **Coverage output formats** (`dream_test/coverage/*`)

  - JSON (`coverage.json_path`), Cobertura XML (`coverage.cobertura_path`),
    Markdown (`coverage.markdown_path`) and HTML with annotated source
    (`coverage.html_path`)
  - `coverage.html_file` writes the same HTML report as one combined page:
    the table, then the annotated source of each file, linked from the
    table. `html.combined` renders it in a custom pipeline
  - `coverage.html_path` deletes the `files` folder of the HTML directory
    before it writes new pages, so no page of a removed source file stays

- **Coverage from other BEAM instances** (`coverage.merge_lcov`)

  - Merges LCOV files that match a pattern into the report, for example the
    file that a separately run application server writes with
    `coverage.start` and `coverage.finish`

- **Coverage without the runner** (`coverage.start`, `coverage.finish`,
  `coverage.check_minimum`, `coverage.check_minimum_per_file`,
  `dream_test/coverage/report`)

- **Line accuracy warning**

  - The coverage table warns when a Gleam version before 1.19 built a
    measured file, because older versions map only the first line of each
    function to its source line. The warning does not fail the run

- **Coverage badge** (`.github/workflows/ci.yml`, `README.md`,
  `documentation/12-coverage-badge.md`)

  - A push to `main` publishes the coverage total to `coverage.json` on the
    `badges` branch. The README shows it as a shields.io badge, with the
    colour rule of the coverage table
  - The CI coverage run writes its JSON summary to
    `build/coverage/coverage.json`
  - A new guide shows how to set up the same badge in your own repository

### Changed

- **Toolchain** (`.github/workflows/*.yml`, `CONTRIBUTING.md`)

  - CI and the publish workflows now use Gleam 1.19.2. Contributors need
    Gleam 1.19.0 or later, because coverage line numbers are exact only from
    1.19 and the coverage self-tests check exact lines
  - CI also runs the README snippet tests in `examples/snippets`

## [2.1.3] - 2026-07-06

### Fixed

- **Hex publishing** (`.github/workflows/publish.yml`, `.github/workflows/publish-docs.yml`)

  - The 2.1.2 release was never published: Gleam 1.14's Hex client sends duplicate
    `content-type` headers on publish requests, which Hex.pm began rejecting with
    `400 Bad Request` after a server-side Plug upgrade on 2026-06-27
  - The publish workflows now use Gleam 1.17.0, whose Hex client sends a single
    `content-type` header
  - 2.1.3 is the first version on Hex to include the 2.1.2 changes

- **JSON reporter snippet snapshot** (`examples/snippets`)

  - The tested snippet now also normalizes `otp_version` in the JSON report so the
    snapshot no longer breaks when Erlang/OTP is upgraded

### Changed

- **Toolchain** (`.github/workflows/ci.yml`, `CONTRIBUTING.md`)

  - CI now runs Gleam 1.17.0, and sources are reformatted with the 1.17 formatter
    (whitespace-only changes)
  - Contributor prerequisites now require Gleam 1.17.0+ and Erlang/OTP 28+, since
    older formatters produce output that fails CI's format check

## [2.1.2] - 2026-07-06

_Not published to Hex: the publish workflow failed (see 2.1.3). These changes
first shipped in 2.1.3._

### Changed

- **Dependency constraints** (`gleam.toml`)

  - Widened `gleam_stdlib` to `>= 0.60.0 and < 2.0.0` so dream_test can be installed
    alongside packages that require `gleam_stdlib` 1.x
  - Verified the full test suite and all examples against `gleam_stdlib` 1.0.3
  - Thanks to [@aschrijver](https://github.com/aschrijver) for reporting ([#19](https://github.com/TrustBound/dream_test/issues/19))

### Fixed

- **JSON reporter snippet snapshot** (`examples/snippets`)

  - The tested snippet now normalizes `gleam_version` in the JSON report so the
    snapshot no longer breaks when `gleam_stdlib` is upgraded

## [2.1.1] - 2026-02-02

### Fixed

- **Gherkin step attachments** (`dream_test/gherkin/parser`)

  - Data tables and doc strings now attach to the correct step in parsed scenarios
  - Thanks to [Álvaro Vilanova Vidal](https://github.com/alvivi) for finding and fixing this issue

## [2.1.0] - 2026-01-31

### Added

- **Runner-level hooks** (`dream_test/runner`, `dream_test/parallel`)

  - New `before_each_test`, `after_each_test`, `before_each_suite`, `after_each_suite`,
    `before_all_suites`, and `after_all_suites` hooks
  - Hooks receive structured metadata via `types.TestInfo` and `types.SuiteInfo`
  - Per-test hooks run in the executor with sandboxing and correct ordering around suite hooks

- **Test/suite metadata** (`dream_test/types`)

  - New `TestInfo` and `SuiteInfo` types, including best-effort `source`
  - Source tracking for unit discovery (module name) and Gherkin discovery (feature path)

### Changed

- **Setup failure status** (`dream_test/parallel`)

  - Runner `before_each_test` failures now yield `SetupFailed` and skip test bodies

### Documentation

- Added runner hook section to the runner guide with a tested snippet
- Updated README and documentation index to highlight runner hooks
- Refreshed compatibility reports (`COMPATIBILITY.md`, `COMPATIBILITY_REPORT.md`, `CONSTRAINT_ANALYSIS.md`)

## [2.0.0] - 2025-12-27

### Added

- **Suite-first runner builder** (`dream_test/runner`)

  - New `runner.new([suite]) |> ... |> runner.run()` pipeline for configuring and running suites
  - Configuration is applied via builder functions (`max_concurrency`, `default_timeout_ms`, `progress_reporter`, `results_reporters`, `output`, `silent`, `exit_on_failure`, `filter_tests`)
  - Suite list can be built incrementally with `add_suites(...)`, and specific suites can run with an execution config override via `add_suites_with_config(...)`

- **Runtime test discovery** (`dream_test/discover`)

  - Builder for discovering compiled test modules under `./test/` via module path globs (e.g. `"unit/**_test.gleam"`)
  - Loads modules that export `tests/0` and calls them to obtain `TestSuite(Nil)` values

- **Reporting split** (`dream_test/reporters/types`, `dream_test/reporters/bdd`, `dream_test/reporters/json`, `dream_test/reporters/progress`)

  - Runner emits structured `ReporterEvent`s (`RunStarted`, `TestFinished`, `RunFinished`, plus hook events)
  - Live progress via `runner.progress_reporter(progress.new())`
  - End-of-run reporting via `runner.results_reporters([bdd.new(), json.new(), ...])`

- **Live progress bar reporter** (`dream_test/reporters/progress`)

  - In-place single-line progress bar that adapts to terminal width

- **Selective sandbox crash reports** (`dream_test/sandbox`)

  - New `SandboxConfig.show_crash_reports` flag (default `False`) to suppress noisy BEAM crash reports while still reporting failures
  - Convenience helper `sandbox.with_crash_reports` for local debugging

### Changed

- **Unit DSL is suite-first** (`dream_test/unit`, `dream_test/types`)

  - Suite items are now typed (`SuiteItem(ctx)`) and suites carry context (`TestSuite(ctx)`)
  - Test bodies now return `Result(AssertionResult, String)` for explicit failure reporting
  - Lifecycle hooks now return `Result(ctx, String)` for explicit failure reporting

- **Parallel runner API** (`dream_test/parallel`)

  - Added event-driven entrypoints for driving reporters during parallel execution

### Documentation

- Updated docs to the new v2 suite-first pipeline and event-driven reporter model.

### Breaking Changes

- `dream_test/runner`: replaced `run_all*` / `run_suite*` free functions with the `RunBuilder` pipeline (`runner.new(...) |> ... |> runner.run()`).
- `dream_test/unit`: test bodies now return `Result(AssertionResult, String)` instead of `AssertionResult`. Hooks now return `Result(ctx, String)` instead of `ctx`.
- `dream_test/unit`: replaced the old `UnitTest` tree + `to_test_suite` conversion with typed suite builders (`describe`, `group`, `describe_with_hooks`, `SuiteHooks`).
- `dream_test/types`: suites and test cases are now context-typed (`TestSuite(ctx)`, `SuiteTestCase(ctx)`), so user code matching these types must be updated.
- **Reporters refactored and split**: live output via `runner.progress_reporter(progress.new())`, end-of-run output via `runner.results_reporters([bdd.new(), json.new(), ...])`. The old `dream_test/reporter` module is replaced by `dream_test/reporters/*`.
- `dream_test/gherkin/world.get`: error type changed from `Result(a, Nil)` to `Result(a, String)` for more informative failures.

## [1.2.0] - 2025-12-04

### Added

- **Snapshot Testing** (`dream_test/matchers/snapshot`, `dream_test/assertions/should`)

  - `match_snapshot()` matcher for comparing string output against stored files
  - `match_snapshot_inspect()` for testing non-string values via `string.inspect`
  - Auto-creates snapshots on first run; compares on subsequent runs
  - Delete snapshot file to regenerate (no magic flags or environment variables)
  - `clear_snapshot()` to programmatically delete individual snapshots
  - `clear_snapshots_in_directory()` to bulk-delete `.snap` files
  - `SnapshotFailure` payload for rich error reporting with diffs

- **File Module** (`dream_test/file`)

  - Generalized file I/O module for internal use
  - `read()`, `write()`, `delete()`, `delete_files_matching()` functions
  - Structured `Error` type with variants: `NotFound`, `PermissionDenied`, `IsDirectory`, `NoSpace`, `FileSystemError`
  - `error_to_string()` for human-readable error messages
  - Auto-creates parent directories on write

### Changed

- **Gherkin Parser** now uses the generalized `dream_test/file` module
- **README restructured** with table of contents and teaching-optimized section order

### Documentation

- Added "Snapshot Testing" section to README with usage examples
- Added table of contents under hero for quick navigation
- Reordered sections for optimal learning flow
- Added "Snapshot" to available matchers table
- Added "Snapshot testing" to feature status table
- Added `snapshot_testing.gleam` example in `examples/snippets/test/`
- World-class hexdocs for all new public functions and types

## [1.1.0] - 2025-12-02

### Added

- **Test tagging and filtering** (`dream_test/unit`, `dream_test/runner`)

  - `with_tags()` function to tag unit tests for categorization
  - `RunnerConfig.test_filter` predicate for selective test execution
  - Filter by tags, name, kind, or any `SingleTestConfig` field
  - Works with both flat mode (`run_all`) and suite mode (`run_suite`)
  - Unified tagging across unit tests and Gherkin scenarios

- **`succeed()` function** (`dream_test/assertions/should`)

  - Explicit success counterpart to `fail_with()` for conditional branches
  - Use in `case` expressions where all branches must return `AssertionResult`
  - Recommended over importing `AssertionOk` directly in user code

- **Gherkin/Cucumber BDD Support**

  - Full Cucumber-style Given/When/Then testing with typed step definitions
  - Inline DSL for defining features directly in Gleam (`feature`, `scenario`, `given`, `when`, `then`)
  - `.feature` file parser supporting standard Gherkin syntax
  - Step registry with radix trie for O(words) step lookup
  - Typed placeholders: `{int}`, `{float}`, `{string}`, `{word}`
  - Prefix/suffix support for placeholders (e.g., `${float}` matches `$19.99`)
  - World state management with ETS-backed mutable scenario state
  - Background steps for shared setup across scenarios
  - Tag support for filtering scenarios (`@smoke`, `@slow`, etc.)
  - Scenario Outline with Examples table expansion
  - Data tables and doc strings in steps
  - Gherkin-style reporter with scenario-level output

- **Feature Discovery** (`dream_test/gherkin/discover`)

  - Builder pattern for loading `.feature` files with glob patterns
  - `features()` → `with_registry()` → `to_suite()` fluent API
  - Graceful error handling for parse failures

- **Per-Test Timing** (`dream_test/timing`)

  - Human-readable duration formatting (ms, s, m, h)
  - Per-test and total duration in BDD and Gherkin reporters
  - Monotonic time measurement for accurate elapsed time

- **JSON Reporter** (`dream_test/reporters/json`)

  - Machine-readable JSON output for CI/CD integration
  - `format` and `format_pretty` for string output
  - `report` and `report_pretty` for pipeline integration
  - Includes system info (OS, OTP version, Gleam version)
  - Detailed failure payloads with expected/actual values
  - Composable with BDD reporter for dual output

### Dependencies

- Added `gleam_regexp` dependency for step pattern tokenization
- Added `gleam_json` dependency for JSON reporter

### Documentation

- Added comprehensive Gherkin/BDD section to README
- Added JSON reporter section to README
- Added shopping cart example in `examples/shopping_cart/`
- Added Gherkin and JSON reporter snippets in `examples/snippets/`
- Updated feature status table with Gherkin/Cucumber BDD and JSON Reporter
- Added custom matchers documentation with example snippet
- Updated hexdocs for all new public functions

## [1.0.3] - 2025-12-01

### Changed

- **Improved Pipeline Composability**
  - `report` now returns results, enabling cleaner pipelines:
    `run_all() |> report(io.print) |> exit_on_failure()`

### Documentation

- Added "CI integration" section to README with `exit_on_failure` examples
- Updated Quick Start example to demonstrate full pipeline with exit codes
- Added "CI exit codes" to the feature status table

## [1.0.2] - 2025-12-01

### Added

- **Test Skipping**

  - New `skip` function as an analog to `it` for temporarily disabling tests
  - Simply change `it` to `skip` to skip a test; the body is preserved but not executed
  - Skipped tests appear with `-` marker in output and are counted in summary

- **Exit Code Handling**

  - New `exit_on_failure` function exits with code 1 if any tests failed
  - New `has_failures` function to check if test results contain failures
  - Proper CI integration: test suites now fail builds when tests fail

- **AssertionSkipped Result Type**
  - New `AssertionSkipped` variant in `AssertionResult` for skip support

### Documentation

- Added "Skipping tests" section to README with examples
- Added new `skipping_tests.gleam` snippet in `examples/snippets/test/`

## [1.0.1] - 2025-12-01

### Changed

- **Documentation Improvements**
  - All README code examples are now backed by tested source files
  - Each snippet has its own file in `examples/snippets/test/` for stable linking
  - Added Quick Start example with string utilities
  - README code blocks now include 🧪 links to verified source

### Removed

- Removed redundant `examples/math_app/` and `examples/string_app/` directories
- Consolidated all README examples into `examples/snippets/`

## [1.0.0] - 2025-11-30

### Added

- **Core Testing Framework**

  - `describe` and `it` blocks for BDD-style test organization
  - Nested describe blocks with proper scoping
  - Test tagging and filtering support

- **Assertions Module** (`dream_test/assertions/should`)

  - Fluent assertion API with `should` builder
  - `or_fail_with` for custom failure messages
  - Chainable assertion pattern

- **Matchers**

  - `equality` - `equal`, `not_equal`, `be_same_as`
  - `boolean` - `be_true`, `be_false`
  - `comparison` - `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`
  - `string` - `contain`, `start_with`, `end_with`, `match_pattern`
  - `collection` - `be_empty`, `have_length`, `contain_element`, `contain_exactly`
  - `option` - `be_some`, `be_none`, `unwrap_some`
  - `result` - `be_ok`, `be_error`, `unwrap_ok`, `unwrap_error`

- **Test Runner**

  - Parallel test execution with configurable concurrency
  - Sequential test support for tests requiring isolation
  - Test timeout handling
  - Comprehensive test result reporting

- **BDD Reporter** (`dream_test/reporters/bdd`)

  - Colorized terminal output
  - Hierarchical test result display
  - Summary statistics (passed, failed, skipped)
  - Failure details with context

- **Lifecycle Support**

  - `before_each` and `after_each` hooks
  - Setup and teardown at describe block level
  - Context passing between lifecycle hooks and tests

- **Sandbox Module** (`dream_test/sandbox`)

  - Isolated test execution environment
  - Process isolation for test safety

- **Process Testing** (`dream_test/process`)
  - Utilities for testing OTP processes
  - Process lifecycle testing support

### Documentation

- Comprehensive README with usage examples
- CONTRIBUTING guide for contributors
- STANDARDS document for code conventions
- API documentation for all public modules

[Unreleased]: https://github.com/TrustBound/dream_test/compare/2.2.0...HEAD
[2.2.0]: https://github.com/TrustBound/dream_test/compare/2.1.3...2.2.0
[2.1.3]: https://github.com/TrustBound/dream_test/compare/2.1.1...2.1.3
[2.1.2]: https://github.com/TrustBound/dream_test/compare/2.1.1...7c1daa617e276eef2f7ad4bf470f0ac8dfb634a3
[2.1.1]: https://github.com/TrustBound/dream_test/compare/2.1.0...2.1.1
[2.1.0]: https://github.com/TrustBound/dream_test/compare/2.0.0...2.1.0
[2.0.0]: https://github.com/TrustBound/dream_test/compare/1.2.0...2.0.0
[1.2.0]: https://github.com/TrustBound/dream_test/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/TrustBound/dream_test/compare/1.0.3...1.1.0
[1.0.3]: https://github.com/TrustBound/dream_test/compare/1.0.2...1.0.3
[1.0.2]: https://github.com/TrustBound/dream_test/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/TrustBound/dream_test/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/TrustBound/dream_test/releases/tag/1.0.0
