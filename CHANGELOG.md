# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-11-18

Dream Test 3.0.0 adds built-in line coverage. It also gives the hooks of
each scope one setup process, follows the official Gherkin grammar, and
gives each Gherkin scenario one typed state value in place of the `world`
store. This release has breaking changes. Read
[Upgrading to 3.0.0](documentation/13-upgrading-to-3.md) before you update.

### Breaking changes

#### Runner and run report

- `runner.run` returns `types.RunReport`, not `List(TestResult)`. A
  `RunReport` holds the test results, the hook failures (failed teardown
  hooks and stopped setups) and the results reporters that crashed.
- `runner.has_failures` is removed. Use `types.failed(report)`, which is
  also `True` for a teardown failure, for a stopped setup and for a
  crashed results reporter.
- `runner.silent()` drops the normal output only: progress, results
  reports and the coverage report. It still writes two kinds of error to
  the standard error stream: the `Results reporter failed` error of a
  `reporter_types.Custom` reporter that crashed, and a coverage error, for
  example a total below `coverage.minimum_percent`. In 2.x, a silent run
  dropped all output.
- `parallel.run_tree_parallel` returns `types.RunReport`, not
  `List(TestResult)`.
- `parallel.RunTreeParallelWithReporterConfig` has a new field
  `outer_setups: List(parallel.OuterSetup)`, and
  `parallel.RunTreeParallelWithReporterResult` has the new fields
  `hook_failures` and `outer_setups`.
- `runner.exit_on_failure` stops the BEAM with `init:stop(1)` in place of
  `erlang:halt(1)`, so the BEAM shuts down cleanly. As in 2.x, a failed run
  writes all its output, and then ends the program with status 1 inside
  `runner.run`: no code after `runner.run` runs. In 3.0.0 it also writes
  the coverage files first. It also stops with status 1 when a teardown
  hook failed and every test passed, when a setup stopped
  (`SetupStopped`), when a `reporter_types.Custom` reporter crashed, and
  when coverage failed. 2.x had no teardown failures in the report, no
  stopped setups, no custom reporters and no coverage.
- `types.Root` is now `types.Tree`, and `types.root` is now `types.tree`.
  A tree is one top-level group with its children and one context; a
  suite holds one or more trees. The tree holds the top-level group
  itself: `Tree(initial:, name:, tags:, children:)` in place of
  `Root(seed:, tree: Group(name:, tags:, children:))`.
- The start value has the label `initial` in place of `seed`:
  `unit_context.describe(name:, initial:, children:)`,
  `types.tree(name:, initial:, children:)` and the field
  `types.Tree.initial`, the same label as `steps.new(initial:)`. A call
  without labels does not change.
- `types.TestResult` and `types.TestInfo` hold `groups: List(String)` (the
  names of the groups around the test) in place of
  `full_name: List(String)`.
- The `run` field of `types.Test`, `BeforeAll`, `BeforeEach`, `AfterEach`
  and `AfterAll` is a `types.Callback`, not a function. This affects only
  code that builds `types.Node` values directly.
- `types.ModuleCoverage` and `types.CoverageSummary` are removed. Use
  `dream_test/coverage`.
- `types.TestKind.Integration` is removed. No test ever had this kind. Tag
  integration tests with `unit.with_tags` and select them with
  `runner.filter_tests`.
- The alias `types.TestSuiteItem` is removed. Use `types.Node`.
- The module `dream_test/context` (`TestContext`, `new`, `failures`,
  `add_failure`) is removed. Nothing in Dream Test used it.
- `TestSuite` has no type parameter and moves to the new module
  `dream_test/suite`. `types.TestSuite(context)` is removed. Each tree of
  a suite keeps its context inside the suite, so one `runner.new` takes a
  `unit` suite, a `unit_context` suite and a Gherkin feature together.
  `unit.describe`, `unit_context.describe`, the Gherkin suite functions
  and module discovery give a `suite.TestSuite`. To run a tree that you
  build yourself, give it to `suite.from_tree`.
- `runner.RunBuilder` has no type parameter. `runner.before_each_test`
  and `runner.after_each_test` take `fn(TestInfo) -> Result(Nil, String)`.
  The hooks get the `TestInfo` of the test, not its context, and cannot
  change the context.
- `parallel.RunTreeParallelWithReporterConfig` takes
  `runner_before_each_test` and `runner_after_each_test` as
  `List(fn(TestInfo) -> Result(Nil, String))`, the same type as the runner
  hooks, in place of functions that also got and gave the context.
- Module discovery loads a suite with a context, for example from
  `unit_context`, and runs it with its own context. `discover.to_suite`
  puts each module suite in one group, and each suite keeps its own
  context. In 2.x, `discover.to_suite` gave the tests of such a suite
  `Nil` in place of their context.
- A module discovery pattern that matches no test module is an error:
  `<pattern>: no test module matches the pattern`. A test module whose
  beam file does not load is an error:
  `<module>: cannot load the module: <reason>`. `discover.to_suites` and
  `discover.to_suite` give a failing test for each, and
  `discover.list_modules` gives `Error`. Before, both gave no module and
  no error, so a wrong pattern gave a run that passed.
- `types.AssertionResult` has the new variant `AssertionPending`, for
  `unit.pending`. A `case` on an `AssertionResult` needs a branch for it.
- The typed `parallel` functions take a `types.Tree(context)`. Build one
  with `types.tree`, not with `unit.describe`. The label of the tree is
  `tree:` in place of `suite:`, in `run_tree_parallel` and in
  `RunTreeParallelWithReporterConfig`.
- The `parallel` names say "tree" in place of "root":
  `run_root_parallel` is now `run_tree_parallel`,
  `run_root_parallel_with_reporter` is now `run_tree_parallel_with_reporter`,
  `RunRootParallelWithReporterConfig` is now
  `RunTreeParallelWithReporterConfig`, and
  `RunRootParallelWithReporterResult` is now
  `RunTreeParallelWithReporterResult`.

#### Hooks and processes

- One rule for every hook failure. A failed setup hook gives `SetupFailed`
  to each test that it serves. A failed teardown hook does not change a
  test status, the remaining teardown hooks still run, the failure goes
  into the hook failures of the run report, and the run fails.
- When a `before_all` hook fails, times out or crashes, the tests of its
  group and of every group inside it are `SetupFailed`, not `Failed`.
- The hooks of each scope run in one setup process of that scope, and a
  test runs in one process: its `before_each_test` hooks, `before_each`
  hooks, body, `after_each` hooks and `after_each_test` hooks.
- A test body that runs past its timeout is `TimedOut`, not `Failed`.
- At the very moment of a deadline, the runner keeps a result that is
  already waiting for it. So a test that finished at its deadline can keep
  its result, and a test that is `TimedOut` for a step can also hold the
  context and teardown failures of steps that finished in that moment.

#### Sandbox

- `sandbox.run_isolated` takes the function and its input as two
  parameters: `run_isolated(config:, run: fn(input) -> a, input:)` in place
  of `run_isolated(config:, test_function: fn() -> a)`.

#### Reporters

- The reporter functions that format a whole run take a `types.RunReport`:
  `bdd.render`, `bdd.format`, `bdd.report`, `bdd.format_summary_only`,
  `json.render`, `json.format`, `json.format_pretty`, `json.report`,
  `json.report_pretty`, `gherkin.format` and `gherkin.report`. The `report`
  functions return the report.
- The JSON schema version is `2.0`. Its `summary` adds the counts
  `teardown_failed` (teardown hooks that failed) and `setup_stopped`
  (setups whose process stopped). The new list `hook_failures` holds an
  object for each hook failure, with `kind`, `hook`, `path`, `message`
  and, for a stopped setup, `not_run`. A failed `after_all` hook is no
  longer a fake `<after_all>` test in `tests`.
- The `system` object of the JSON report has `gleam_stdlib_version` in
  place of `gleam_version`. The value did not change: it is the version of
  the `gleam_stdlib` package. The compiled code does not record the version
  of the Gleam compiler, so the report cannot give it.
- The JSON report (`json.format`, `json.format_pretty` and the JSON results
  reporter) ends with a newline. Before, text that a reporter wrote after
  it joined its last line.
- The summary line of the BDD and Gherkin reporters lists the extra counts
  in the order skipped, pending, timed out, setup failed, then the new
  counts teardown failed and setup stopped, before ` in <duration>`.
- `reporters/types.ResultsReporter` has the new variant `Custom(render:)`.
  A `case` on a `ResultsReporter` needs a branch for it.
- The progress event API is removed: `reporters/types.ReporterEvent`,
  `reporters/types.HookKind`, `reporters/types.HookOutcome` and
  `progress.handle_event`. `progress.render` takes a
  `progress.ProgressEvent`.

#### Gherkin step definitions

- The `world` key/value store is removed, with `dream_test/gherkin/world`
  and its ETS table. Each scenario made one atom that was never freed.
  Each scenario now has one typed state value.
- `steps.new` takes the initial scenario state, and `StepRegistry`,
  `FeatureConfig` and `discover.RunnableDiscovery` take the state type as a
  type parameter.
- The phase of a step definition sets its kind. `steps.given` and
  `steps.when` take an action,
  `fn(state, StepContext) -> Result(state, String)`. `steps.then` takes a
  check, `fn(state, StepContext) -> Result(AssertionResult, String)`. A
  check cannot change the state. The `StepHandler` type is removed.
- `steps.when_` is now `steps.when`, and `steps.then_` is now `steps.then`.
- `feature.to_test_suite` is now `feature.to_suite`, as `steps.to_suite`
  and `discover.to_suite`. It still takes a `FeatureConfig`.
- `StepContext` has no `world` field. It has a `scenario_id` field.
- `types.GherkinScenario(String)` is now
  `GherkinScenario(scenario_id: String, feature: Option(String), rule:
  Option(String))`. `feature` is the name of the Feature for a scenario in
  the group of its Feature, or `None` for a scenario of
  `steps.Scenarios`. `rule` is the name of the Rule group, for
  example `Some("Rule: Stock")`, or `None` for a scenario outside a Rule.
  The BDD and Gherkin reporters read the Feature and the Rule from these
  fields, not from the place of a group or from a group name that starts
  with `Rule:`. So both print `Feature:` on the same group, and a Feature
  named `Rule: refunds` prints as `Feature: Rule: refunds`. A scenario with
  `feature: None` gets no `Feature:` line: the Gherkin reporter prints its
  groups joined with ` > ` as its heading. A Gherkin test in the JSON
  report has `feature` and `rule` after `kind` (each a string, or `null`).
- The Gherkin reporter heads a result that is not in a Feature group by
  its groups joined with ` > `. A unit test `sums` in the groups `math`
  and `add` now heads as `math > add`. In 2.x it headed as `Feature:
  math`, the first group.
- A Gherkin result with no Feature and no groups prints no heading line.
  In 2.x it headed as `Feature: <test name>`. The `Feature: Unknown
  Feature` placeholder is gone.
- The scenario id ends with `#` and a number, for example
  `"Shopping Cart::Adding items#12"`, so it is unique in the run, also for
  two scenarios with the same name. In 2.x it was only the name path. The
  number changes between runs. The JSON report writes the same id in
  `"kind": "gherkin:<id>"`.
- `steps.step` is removed. Each step definition belongs to exactly one
  phase.
- `steps.find_step` takes `phase: StepPhase` in place of
  `keyword: StepKeyword`, and gives a `StepMatch(StepDefinition(state))`.
- `step_trie.insert` and `step_trie.lookup` take `phase: StepPhase` in
  place of a keyword `String`, and the trie has no `"*"` wildcard handler.
  `insert` returns `Result(StepTrie(handler), String)`.
- A pattern registered two times in one phase is an error. The first
  definition stays, and each scenario that uses the registry fails with
  `Duplicate step definition: ...`. The same pattern in two phases is not a
  duplicate.
- `feature.InlineStep` holds `keyword: gherkin/types.StepKeyword` in place
  of `keyword: String`.
- Step text and step patterns are split into words in the same way: at
  spaces, with a double-quoted run kept in one word. A space in a pattern
  must be a space in the text, so `$ {float}` does not match `$19.99`.
  `{word}` matches only text with no space. Before, the step text was also
  split where digits meet other characters, and the pattern was not.
- `step_trie.parse_step_pattern` gives one `List(StepSegment)` for each
  word, and `StepSegment.LiteralWord` is now `LiteralText`.
  `step_trie.tokenize_step_text` splits only at spaces outside quotes. A
  quoted run starts at a double quote at the start of a word, also after
  `(` or `[`. It ends at a double quote before a space, the end of the
  text, or one of `,` `.` `)` `]` `;` `:` `!` `?`. So
  `"apple", "banana"` is two words, and the quote in `O"Brien` or `5"`
  is an ordinary character.
- `discover.with_registry` gives the opaque type `RunnableDiscovery`, and
  `discover.to_suite` takes only that type.
- A `discover.features` pattern that matches no files is an error.
  `discover.to_suite` gives one failing test,
  `No feature files match the pattern "<pattern>"`, tagged
  `no-feature-files`. `discover.load` gives the new error
  `parser.NoMatchingFeatureFiles(pattern)`. Before, both gave no features
  and no errors, so a wrong pattern gave a run that passed.
- A `discover.features` pattern that cannot be searched, for example
  `features/{a.feature`, is an error, not a crash while the suite is
  built. `discover.load` gives the new error
  `parser.InvalidFeatureFilePattern(pattern, reason)`, and
  `discover.to_suite` gives one failing test,
  `Cannot search for feature files with the pattern "<pattern>": <reason>`,
  tagged `invalid-feature-pattern`.
- `{float}` matches a number as Cucumber reads it: an optional sign,
  digits with an optional `.` and digits, or `.` and digits alone, and an
  optional exponent, for example `20`, `.5`, `-3`, `1e5` and `1.5e-3`.
  `5.`, `1,000`, `NaN` and `Infinity` do not match. This changes which
  step runs: with `total {word}` and `total {float}`, the text `total 20`
  now runs the `{float}` step, and `${float}USD` matches `$20USD`.
  `{int}` still wins over `{float}`. Before, `{float}` needed a `.`.
- `discover.list_files` returns
  `Result(List(String), parser.FeatureFileError)`, not `List(String)`. A
  pattern that cannot be searched gives
  `Error(parser.InvalidFeatureFilePattern(pattern, reason))`. A pattern
  that matches no files gives `Ok([])`.

#### Gherkin parser and syntax tree

- `gherkin/types.Scenario` is one record,
  `Scenario(keyword, name, description, tags, steps, examples)`, with
  `examples: List(Examples)`. The `ScenarioOutline` variant is removed.
- `gherkin/types.Background` holds `name` and `description`.
- `gherkin/types.Feature` has a new field, `rules: List(Rule)`.
- `gherkin/types.Step` holds `doc_string: Option(DocString)` and
  `data_table: Option(DataTable)` in place of
  `argument: Option(StepArgument)`. The `StepArgument` type is removed.
- `gherkin/types.StepKeyword` has a new variant, `Asterisk`.
- `gherkin/types.resolve_keyword` is removed. Use
  `gherkin/types.resolve_phase`.
- `parser.parse_string` returns `Result(Feature, ParseError)`,
  `parser.parse_file` returns `Result(Feature, FeatureFileError)`, and
  `discover.LoadResult.errors` is `List(parser.FeatureFileError)`, in place
  of `String` errors. `FeatureFileError` is new, with four variants:
  `UnreadableFeatureFile(error)`, `InvalidFeatureFile(path, error)`,
  `NoMatchingFeatureFiles(pattern)` and
  `InvalidFeatureFilePattern(pattern, reason)`.
- The parser follows the official Gherkin grammar. A line that the grammar
  does not permit at its position is an `UnexpectedLine` error. Before, the
  parser ignored it.
- Every parse error message starts with `line N:`, and
  `DocString is not closed` is now
  `The DocString that starts on line N is not closed`.
- The first step of a Background, and of a Scenario when the Background
  has no steps, must use Given, When or Then. A leading `And`, `But` or `*`
  is a parse error in a `.feature` file, and fails each scenario of an
  inline feature.
- A description keeps the leading whitespace of each line and the empty
  lines between its text lines.
- The test of an `Examples` row has the row label in its name:
  `<scenario> (Example N)`, or `<scenario> (<examples name>, Example N)`.
- A scenario with no `Examples` section runs one time, also when its
  keyword is `Scenario Outline`.
- A tag line is read as Gherkin reads it: `@a@b` is two tags,
  `@tag #comment` ignores the comment, and `@a b` is a
  `TagContainsWhitespace` error.
- A `# language:` line before the Feature must name `en`. Another language
  is an `UnsupportedLanguage` error.

### Upgrading from 2.x

Read [Upgrading to 3.0.0](documentation/13-upgrading-to-3.md). It shows 2.x
code and the same code for 3.0.0 for each change below. Some 2.x examples
are copies of files at tag 2.1.3. The others use only the 2.1.3 API, and
the guide labels them.

- Gherkin steps get and return a typed scenario state. `world` is removed.
- `steps.new` takes the initial state. `steps.step` is removed.
- `steps.when_` and `steps.then_` are now `steps.when` and `steps.then`.
- `feature.to_test_suite` is now `feature.to_suite`.
- `unit_context.describe` and `types.tree` take `initial:` in place of
  `seed:`.
- `StepContext` has `scenario_id` in place of `world`.
- `GherkinScenario` has the fields `scenario_id`, `feature` and `rule`.
- A pattern registered two times in one phase is an error.
- `find_step` and `step_trie` take a `StepPhase` in place of a keyword.
- Step text and patterns split into words only at spaces.
- `{float}` matches whole numbers, so `total 20` can run a different step.
- `steps.given` and `steps.when` take `action:`, and `steps.then` takes
  `check:`, in place of `handler:`.
- A `discover.features` pattern that matches no files fails the run.
- A module discovery pattern that matches no test module fails the run,
  and so does a test module that does not load.
- `runner.run` and `parallel.run_tree_parallel` return a `types.RunReport`.
- `runner.has_failures` is now `types.failed`.
- `TestResult` and `TestInfo` hold `groups` in place of `full_name`.
- `TestSuite` has no type parameter and is in `dream_test/suite`.
- `runner.before_each_test` and `runner.after_each_test` get only the `TestInfo`.
- Module discovery runs a suite with a context with its own context.
- `run_root_parallel*` and `RunRootParallelWithReporter*` are now
  `run_tree_parallel*` and `RunTreeParallelWithReporter*`.
- `RunTreeParallelWithReporterConfig` has the new field `outer_setups`, and
  its field `suite` is now `tree`.
- `types.Root` is now `types.Tree` and holds the group fields, and hooks
  and tests hold a `Callback`.
- A failed setup hook gives `SetupFailed`. A body timeout gives `TimedOut`.
- A failed teardown hook goes into the run report, not into the results.
- Hooks run in one setup process of their scope.
- Reporter functions that format a whole run take a `RunReport`.
- The JSON report has schema version `2.0`.
- The summary line lists skipped, pending, timed out, setup failed.
- `progress.handle_event` and the reporter event types are removed.
- The Gherkin syntax tree changed: `Scenario`, `Step`, `Background`, `Feature`.
- Parse errors are typed, and the parser follows the official grammar.
- `sandbox.run_isolated` takes the function and its input.
- `types.ModuleCoverage` and `types.CoverageSummary` are removed.
- `types.TestKind.Integration`, `types.TestSuiteItem` and the module
  `dream_test/context` are removed.

### Added

- **Suites with different contexts in one run** (`dream_test/suite`)

  - Every suite has the type `suite.TestSuite`, whatever context its tests
    get. One `runner.new` takes `unit` suites, `unit_context` suites and
    Gherkin features together
  - `suite.from_tree` makes a suite from a `types.Tree` that you build
    yourself. `suite.new` makes one from children and a
    `types.SuiteContext`
  - `suite.group` puts suites in one group, and `suite.join` puts them one
    after the other in one suite. Each suite keeps its own context
  - `suite.name`, `suite.tests` and `suite.run` read and run a suite.
    `suite.run` takes a `suite.RunInput`: the concurrency and default
    timeout, the test filter, the progress output, the runner hooks
    around each test and the outer setups
  - `suite.with_source` gives each test of a suite that has no source a
    source, for example the module name. A test that has a source, such
    as the `.feature` path of a scenario, keeps it. Module discovery uses it
  - `parallel.run_tree` runs a typed tree inside groups, with the new
    config type `parallel.RunTreeConfig`: the fields of
    `RunTreeParallelWithReporterConfig`, the tree as `name`, `tags`,
    `children` and `context`, and the groups around it
  - Module discovery loads suites with a context, and `discover.to_suite`
    keeps the context of each module suite

- **Pending tests for writing test skeletons**

  - `unit.pending(name)` and `unit_context.pending(name)` make a test with
    a name and no body. Its status is `Pending`: the reporters show it with
    `~` and count it as pending, and the run still passes
  - `types.AssertionResult` has the new variant `AssertionPending`

- **A context from a setup**

  - `unit_context.describe_with_setup(name:, setup:, teardown:,
    children:)` makes a suite whose context is the value of `setup`
  - `steps.new_with_setup(setup:, teardown:)` makes a step registry whose
    scenarios start from the value of `setup`. `gherkin/discover.to_suite`
    runs the setup one time for the scenarios of all its files.
    `steps.to_suite(registry:, name:, tags:, children:)` makes a suite
    that starts as the registry says. Its children are
    `steps.SuiteChild` values: `Feature(feature)`,
    `Scenarios(feature)`, `Group(name:, tags:, children:)` and
    `Node(node)`. The scenarios of every Feature run with the steps
    of that registry, so a suite of Features cannot mix the steps of one
    registry with the setup of another
  - The setup runs one time for each tree, before the first test of
    that tree, and only when at least one of its tests runs. The teardown
    gets its value after the last test of that tree. Both run in one process that lives while the tests run
  - The reports call this setup the context setup: it runs once for each
    tree that has a test to run, and its value is the context. Its
    teardown, the context teardown, runs after the last test of that tree
  - A failed setup gives `SetupFailed` to each test, with the operator
    `context setup`, and the teardown does not run. A crash reads
    `the context setup crashed in <tree>: <reason>`, and a timeout reads
    `the context setup timed out in <tree>`. A failed teardown is a
    teardown failure with the new hook `types.ContextTeardownHook`, named
    `context teardown` in the reports and in JSON. A setup whose process
    stops is a `SetupStopped` with the new hook `types.ContextSetupHook`,
    named `context setup`, and each test that did not start gets
    `not run: the context setup of "<tree>" stopped (<reason>)`
  - `steps.SuiteChild` puts several Features in one suite with one
    setup: `Feature(feature)` is a group with the tests of a Feature

- **Line coverage** (`dream_test/coverage`, `runner.coverage`)

  - Opt-in line coverage with the native line counters of the BEAM, which
    need Erlang/OTP 27 or later with the JIT. The runner prints a coverage
    table after the results and writes an LCOV file to
    `build/coverage/lcov.info` (`coverage.lcov_path`, `coverage.no_lcov`)
  - More than one coverage run can measure in one BEAM, as long as no module
    is in two runs at the same time. Coverage never stops a process that
    runs old code of a measured module
  - A run keeps its modules until `coverage.finish` reads their line
    counts, or until the process that called `coverage.start` ends. Then
    another run can measure them
  - `coverage.source_directory` measures one folder in place of `src`
  - `coverage.show_missing` adds a `Missing` column with the line ranges that
    did not run
  - `coverage.minimum_percent` and `coverage.minimum_percent_per_file` fail
    the run when the total or one file is below the minimum
  - `runner.coverage_from_environment` turns coverage on only when
    `DREAM_TEST_COVERAGE` is `1` or `true`
  - Every coverage error fails the run with a `Coverage failed` message that
    gives what failed, the reason and the fix
  - The line of a function with an `@external(erlang, ...)` attribute is not
    counted, because Gleam code never calls the wrapper that Gleam compiles
    for it. A function without the attribute whose body only calls an
    external is counted
  - `dream_test/reporters/coverage.RunOutcome` gives the last line of a
    coverage failure: the passed and failed tests, the teardown hooks that
    failed (`teardown_failed`), the setups that stopped (`setup_stopped`),
    the results reporters that crashed (`reporters_crashed`), and whether
    the runner exits on failure, for example
    `Tests: 3 passed, 1 setup stopped. Exit status 1, because a setup stopped and coverage did not complete.`
  - dream_test measures itself: its own tests cover 100% of the lines in
    `src`, with no exclusions

- **Coverage exclusions** (`dream_test/coverage`)

  - `coverage.exclude` and `coverage.exclude_with_reason` remove files that
    match a pattern
  - `coverage:ignore`, `coverage:ignore-start` / `coverage:ignore-end` and
    `coverage:ignore-function` comment markers ignore lines, blocks and whole
    functions in `.gleam` and `.erl` files. Text after a marker is its reason
  - A marker that cannot apply fails the run with the file and the line,
    for example a `coverage:ignore` marker that another marker or the end
    of the file follows before a line of code (`IgnoreLineWithoutCode`)
  - A count line after the total shows what was excluded.
    `coverage.show_excluded` adds an `Excluded` column with the reasons, and
    `coverage.require_exclusion_reasons` fails the run when a reason is missing

- **Coverage table options** (`dream_test/reporters/coverage`)

  - `coverage.color`, `coverage.sort_by_coverage` and `coverage.hide_complete`
  - `dream_test/reporters/ansi` holds the ANSI colour helpers.
    `ansi.apply_if` applies a style only when colour is on

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
  - `SF:` paths lose their `.` parts and empty parts, as measured paths
    do, so `coverage.exclude` also matches a merged file that is written
    another way. An absolute `SF:` path is a `MalformedLcov` error

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

- **Run report** (`dream_test/types`)

  - `types.RunReport`, the result of a run: the test results, the hook
    failures and the results reporters that crashed.
    Make one with
    `types.run_report(tests:, hook_failures:, reporter_crashes:)`, read
    it with `types.report_tests`, `types.report_hook_failures` and
    `types.report_reporter_crashes`, and check it with `types.failed`.
    `RunReport` is opaque, so it can grow without a breaking change
  - `types.HookFailure`, a teardown hook that failed or a setup that
    stopped. Its variant `types.TeardownFailed(hook:, path:, message:)`
    is a teardown hook that failed, with
    `types.TeardownHook` (`AfterEachTestHook`, `AfterEachHook`,
    `AfterAllHook`, `AfterEachSuiteHook`, `AfterAllSuitesHook`,
    `ContextTeardownHook`), with
    `types.teardown_hook_name`
  - `types.SetupStopped(setup:, path:, reason:, not_run:)`, a variant of
    `types.HookFailure` for a setup that stopped: the process that
    keeps its setup alive exited while or after its setup hooks ran.
    `not_run` is the full name of each test that had not started and was
    not run. Each such test is `SetupFailed` with a failure such as
    `not run: the setup from before_all in "Database" stopped (killed)`,
    the teardown hooks still run, and `types.failed` is `True`. Also
    `types.SetupHook` (`BeforeAllHook`, `BeforeEachSuiteHook`,
    `BeforeAllSuitesHook`, `ContextSetupHook`) with
    `types.setup_hook_name`
  - `types.is_failure(status)`, the one check for a failure status
    (`Failed`, `SetupFailed`, `TimedOut`)
  - `types.full_name(groups, name)` gives the full name of a test
  - `types.Callback(input, output)` (`NoInput` and `WithInput`) and
    `types.call`. A test body or hook in a `Node` keeps the shape that the
    user wrote: `unit.before_all(setup)` stores `BeforeAll(NoInput(setup))`,
    and `unit_context.before_all(setup)` stores
    `BeforeAll(WithInput(setup))`

- **Parallel runner** (`dream_test/parallel`)

  - `parallel.OuterSetup`: a setup around the suite that keeps its
    resources alive in a process, for example the `before_all_suites` or
    `before_each_suite` setup. It is
    `SetupRunning(setup:, path:, check_setup_process:)` or
    `SetupStopped(setup:, path:, reason:, not_run:)`. The executor checks
    each one before each test and each group starts

- **Sandbox** (`dream_test/sandbox`)

  - `sandbox.run_in_setup_process`, `sandbox.check_setup_process` and `sandbox.stop_setup_process`
    with the types `sandbox.SetupProcess` and `sandbox.SetupProcessResult`. A setup
    process runs functions one after another with a timeout for each, and
    stays alive between them, so a pool or an ETS table that one function
    starts lives for the next function. `sandbox.SetupProcessLost(reason)` says
    that the setup process stopped before it started the function. Any process can
    use a setup process, and a setup process that stopped is never waited for: after
    `check_setup_process` gives `Error`, `run_in_setup_process` gives `SetupProcessLost` and
    `stop_setup_process` returns at once. When a function times out, the setup process is
    killed and `run_in_setup_process` returns only after the setup process has exited
  - `sandbox.kill_and_wait(pid)` kills a process and returns when it has
    exited, so its ETS tables and its registered name are free. The runner
    uses it for each process that times out, so a teardown hook never
    starts while the process that timed out still holds a resource
  - `sandbox.run_catching(run:, input:)` runs a function in the calling
    process and gives `Ok(value)`, or `Error("class:reason")` when the
    function crashes
  - `sandbox.format_exit_reason` gives the text of a process exit reason, in
    the same form that `run_isolated` and the parallel runner use for a
    crash (`"normal"`, `"killed"`, `"the process had already stopped"`
    for a monitor of a process that was gone, or the inspected reason)

- **Reporters**

  - `dream_test/reporters/summary` gives the summary line of the BDD and
    Gherkin reporters (`summary.format` and `summary.format_in_color`) and
    the counts behind it (`summary.count`, which gives `summary.Counts`)
  - `dream_test/reporters/hook_failures` (`format`, `format_in_color`) gives the
    `Setup and teardown failures:` section of the BDD and Gherkin
    reporters, from `types.report_hook_failures(report)`
  - `gherkin.format_scenarios` gives the feature and scenario lines of the
    Gherkin reporter without the summary line
  - `progress.line` and `progress.ProgressEvent` (`RunStartedProgress`,
    `TestFinishedProgress`, `RunFinishedProgress`) give the text of the
    progress bar for the start of a run, a finished test, or the end of a
    run

- **Typed Gherkin scenario state** (`dream_test/gherkin/steps`)

  - `steps.new(initial:)` takes the state that each scenario starts from
  - `StepContext.scenario_id` gives the id of the scenario, unique in
    the run
  - `steps.validate` returns the duplicate step definitions of a registry,
    one line for each

- **Gherkin conformance** (`dream_test/gherkin/*`)

  - Conformance tests from the official Gherkin test files: 37 good files
    parse to the official structure, 12 bad files give the official error
    line, and 8 good files that dream_test rejects on purpose give the
    dream_test error. The fixture README lists the skipped files and the
    reasons
  - `Rule:` sections. `gherkin/types.Rule` holds the name, description,
    tags, an optional Background and the scenarios of a Rule. The steps of
    the Feature Background run first, then the steps of the Rule
    Background, then the scenario steps. Each Rule runs as a group named
    `Rule: <name>`, and the Gherkin reporter prints the Rule as a heading
    under its feature
  - More than one `Examples` section for each scenario.
    `gherkin/types.Examples` holds the name, description, tags and table of
    a section, and every row of every section runs. The tags of a section
    apply to the tests that its rows make. N in `(Example N)` counts the
    rows of all sections, from 1
  - The `*` step keyword. In a `.feature` file, `* I pack a passport` is a
    step. In the inline DSL, `feature.asterisk("I pack a passport")` makes
    one. A `*` step takes the phase of the step before it, like `And` and
    `But`
  - The English keyword synonyms: `Business Need:` and `Ability:` for
    `Feature:`, `Example:` for `Scenario:`, `Scenario Template:` for
    `Scenario Outline:`, `Scenarios:` for `Examples:`, and the
    ```` ``` ```` DocString separator
  - `gherkin/types.ScenarioKeyword` and
    `gherkin/types.scenario_keyword_to_string`: the keyword that starts a
    scenario
  - The name and description of a Background, and the description of a
    scenario, a Rule and an `Examples` section
  - `gherkin/types.StepPhase` (`GivenPhase`, `WhenPhase`, `ThenPhase`), the
    phase of a step, which maps to Arrange, Act and Assert.
    `gherkin/types.resolve_phase` gives the phase of a step from its keyword
    and the phase before it, and `gherkin/types.phase_to_string` gives the
    name of a phase
  - `gherkin/parser.ParseError`, `ParseProblem`, `TokenKind` and
    `FeatureFileError`: typed parse errors, with one `ParseProblem` variant
    for each kind of problem. `parser.problem_to_string`,
    `parser.parse_error_to_string`, `parser.feature_file_error_to_string`
    and `parser.token_kind_to_string` give the messages

- **Custom results reporters** (`dream_test/reporters/types`)

  - `reporter_types.Custom(render)` adds your own report format to
    `runner.results_reporters`. `render` is a `fn(RunReport) -> String`.
    The runner calls it one time at the end of the run and writes the text,
    in list order with the `bdd` and `json` reports
  - The runner calls `render` in the process of the run, so `render` must
    return. An abnormal exit signal sent to the process of the run, for
    example from a linked process that `render` starts, is not caught and
    ends the run
  - The reports print before the coverage check and before
    `runner.exit_on_failure()` ends the program. Thus a custom report or a
    Gherkin report (`reporter_types.Custom(gherkin.format)`) prints, and the
    exit status is 1 when the run fails or coverage is below a minimum
  - A `render` function that crashes does not stop the run. The runner
    writes a `Results reporter failed` error to the error output and goes
    on with the next reporter and with coverage. The error names the
    position of the reporter: the first reporter in the list is at
    position 1, and every reporter counts, `bdd` and `json` included. It
    shows the crash on one line: the lines of the crash, each without the
    spaces at its start, joined with one space. When that line is longer
    than 200 characters, the error shows the first 200 characters and then
    ` ... (cut at 200 characters, and types.report_reporter_crashes has the
    full reason)`
  - The report that `runner.run` returns has each crash, so
    `types.failed(report)` is `True`. `types.report_reporter_crashes`
    gives a `types.ReporterCrash(position:, reason:)` with the full reason
    of each crash. The reporters get the report without the crashes, so a
    reporter later in the list does not see the crash of a reporter before
    it. With `runner.exit_on_failure()`, the exit status is 1

### Changed

- **Toolchain** (`.github/workflows/*.yml`, `CONTRIBUTING.md`)

  - CI and the publish workflows use Gleam 1.19.2. Contributors need
    Gleam 1.19.0 or later, because coverage line numbers are exact only from
    1.19 and the coverage self-tests check exact lines
  - CI also runs the README snippet tests in `examples/snippets`

- **Hook processes and setups**

  - A setup hook and its teardown hook run only when at least one of
    the tests that they serve runs, with or without a filter. A group,
    a suite or a run with no test runs no `before_all`/`after_all`,
    `before_each_suite`/`after_each_suite` or
    `before_all_suites`/`after_all_suites`
  - Each hook still gets the default timeout, and the messages are
    `hook timed out in <scope>` and `hook crashed in <scope>: ...`
  - A hook that kills its setup process does not stop the run. The runner
    monitors the setup process. A teardown hook that kills its setup process is recorded
    as `hook crashed in <scope>: <reason>`, and the next hook of the scope
    runs in a new setup process. A teardown hook always runs, also when
    the setup process of its scope stops just before the hook starts
  - When the setup process of a setup exits, during or after its setup
    hooks, the setup stopped. It is reported once as `types.SetupStopped`,
    no other setup hook of the scope runs, and each test of the scope that
    did not start is `SetupFailed` with
    `not run: the setup from before_all in "<group>" stopped (<reason>)`,
    `not run: the setup from before_each_suite in "<suite>" stopped (<reason>)`
    or `not run: the setup from before_all_suites stopped (<reason>)`. The
    teardown hooks of the scope run in a new setup process
  - The `after_each` and `after_each_test` hooks run when the test process
    stops, for example when a linked process crashes. They run in a new
    process with their own timeouts and get the context after the last
    `before_each` hook that returned. The test keeps its status

- **Reporters**

  - The BDD and Gherkin reporters show a `Setup and teardown failures:`
    section before the summary, also in the BDD summary-only mode, and the summary line adds
    `N teardown failed` for failed teardown hooks and `N setup stopped`
    for setups whose process stopped. A stopped setup shows as
    `before_all in "<groups>" stopped: the process that keeps its setup alive exited with <reason>.`,
    then `These tests had not started and were not run:` and the full name
    of each test, for example `root > b`
  - The last progress line says `done, 1 teardown failed` when a teardown
    hook failed, and `done, 1 setup stopped` when a setup stopped
    (`progress.RunFinishedProgress` has `teardown_failed` and
    `setup_stopped`)

- **Gherkin**

  - `gherkin/parser.parse_file` puts the path at the start of a parse
    error, for example
    `test/cart.feature: line 3: "And a" has no step before it. ...`
  - A step line in a feature description, before the first Background or
    Scenario, is description text. Before, a `Given`, `When`, `Then`,
    `And` or `But` line there was dropped. A `* ` list item in a
    description stays description text

### Removed

- `dream_test/gherkin/world` (`put`, `get`, `get_or`, `has`, `delete`,
  `scenario_id`, `new_world`, `cleanup`)
- `gherkin/steps.step`, `gherkin/steps.when_`, `gherkin/steps.then_` and
  the `StepHandler` type
- `gherkin/types.resolve_keyword`, `gherkin/types.StepArgument` and the
  `ScenarioOutline` variant of `gherkin/types.Scenario`
- `runner.has_failures`
- `reporters/types.ReporterEvent`, `reporters/types.HookKind`,
  `reporters/types.HookOutcome` and `progress.handle_event`
- `types.ModuleCoverage` and `types.CoverageSummary`
- BREAKING: `types.TestKind.Integration`. No test ever had this kind. Tag
  integration tests with `unit.with_tags` and select them with
  `runner.filter_tests`
- BREAKING: the alias `types.TestSuiteItem`. Use `types.Node`
- BREAKING: the module `dream_test/context` (`TestContext`, `new`,
  `failures`, `add_failure`). Nothing in Dream Test used it

### Fixed

- A number with a comma, such as `1,000` or `1,5`, does not match
  `{float}`. Before, `total 1,000` matched `total {float}` with the value
  `1.0`, and `1,5` gave `1.5`.
- The progress line of a run with no tests shows `0/0` and `100%`.
  Before, it showed `0/1` and `0%`.
- Pretty JSON keeps a string that starts with a combining mark, such as
  a test name that starts with U+0301. Before, the mark joined the
  opening quote, and the rest of the output had the wrong layout.
- A process that a test starts and links to its test process, such as
  the actor of `process.start_counter` or `process.start_actor`, stops
  when the test ends, as the `dream_test/process` docs say. The test
  process exits with reason `shutdown`. Before, a linked process that did
  not trap exits stayed alive after a test that passed, failed or crashed.
- A process that a context setup or a `before_all` hook starts and links
  to its setup process stops when the setup process stops. The setup
  process exits with reason `shutdown`. Before, it exited with reason
  `normal`, and a linked process that did not trap exits stayed alive
  after the run.
- `process.await_ready` and `process.await_some` measure the timeout on
  the monotonic clock. `interval_ms: 0` no longer waits forever, and the
  time in the check counts toward the timeout.
- `discover.load` gives an error that names the module when `tests()`
  returns a value that is not a test suite. Before, the whole run crashed.
  The error text of a `tests()` that crashes, and of a pattern that cannot
  be searched, now has the real cause, for example
  `tests() crashed: error:...` in place of `call_tests_failed`.
- `sandbox.run_isolated` gives `SandboxTimedOut` only after the process
  that timed out has exited, so what it held is free when the call
  returns.
- The capture helpers of `dream_test/gherkin/steps` (`get_int`,
  `get_float`, `get_string`, `get_word`) give an error that names the
  capture. Before: `Capture at index is not an integer` and
  `No capture at index`. After:
  `Capture 0 is the word "apples", not an integer` and
  `No capture at index 2: the step has 1 capture`.
- A resource that a group `before_all` hook starts lives for the tests of
  the group. Before, the hook ran in a short-lived process, so a pool that
  links to its caller (for example a supervisor) and an ETS table stopped
  before the first test ran.
- A resource that a `before_each` hook starts lives for the body and the
  `after_each` hooks of the test. Before, a pool and an ETS table stopped
  before the body ran.
- A crash in a suite-level hook (`before_all_suites`, `before_each_suite`,
  `after_each_suite`, `after_all_suites`) does not stop the whole run. The
  runner records it as a failure of that hook, with the message
  `hook crashed: <reason>` or `hook crashed in <suite>: <reason>`.
- A suite-level hook or a group `before_all` or `after_all` hook that never
  returns does not stop the run. A setup hook gives `SetupFailed` with
  `hook timed out` or `hook timed out in <scope>`, and a teardown hook
  gives a teardown failure with the same message.
- `match_snapshot` and `match_snapshot_inspect` ignore a CRLF (`\r\n`)
  line end at the end of a snapshot file, as they already did for `\n` and
  `\r`. Before, a snapshot file saved with Windows line ends did not match
  the same text.
- `file.delete_files_matching` and `snapshot.clear_snapshots_in_directory`
  read the directory name as text. Before, they made a wildcard pattern
  from the name, so a name with `{`, `[`, `*` or `?` gave a `badpattern`
  error or deleted files in other directories.
- `timing.format_duration_us` gives `"0.0ms"` for a negative duration, the
  same as for `0`. Before, it gave text such as `"0.-5ms"`.
- `sandbox.run_isolated` without crash reports gives `SandboxCrashed` when
  an exit signal stops the worker, for example when a linked process
  crashes. Before, it waited for the full timeout and gave
  `SandboxTimedOut`.
- `sandbox.run_isolated` waits only for the down message of its own worker,
  and removes that message when it returns. Before, with crash reports on,
  it left the down message in the mailbox, and a later call in the same
  process took it and gave `SandboxCrashed("normal")`.
- `sandbox.run_isolated` without crash reports gives the crash reason of
  `SandboxCrashed` as a `String`. Before, it was an Erlang charlist, so the
  parallel runner crashed when it put the reason of a crashed hook in its
  error text.
- The BDD reporter without colour writes the skipped, pending, timed out
  and setup failed counts of its summary as plain text. Before, it put ANSI
  colour codes around these counts, also when colour was off.
- The Gherkin reporter writes the failures of a timed out scenario, for
  example `timeout` with its message, under the scenario line. Before, it
  showed only the `!` marker and no reason.
- The BDD and Gherkin reporters use the feature name for the `Feature:`
  line of a discovered feature, and label no other group as a Feature.
  Before, both used the suite name.
- Pretty JSON (`json.format_pretty`, `json.report_pretty` and the JSON
  reporter with `pretty`) writes an empty list as `[]`. Before, it wrote
  `[`, a line of spaces, and `]`. Compact JSON does not change.
- A Gherkin step can have both a DataTable and a DocString, in either
  order, as in the official Gherkin grammar. The step definition gets both,
  in `context.table` and `context.doc_string`. Before, the parser kept one
  argument and dropped the other without a message.
- A step with two DocStrings is the error
  `Step cannot have more than one DocString` (`RepeatedDocString`). Before,
  the parser kept the second DocString and dropped the first without a
  message.
- The parser gives an error for a DocString that has no closing `"""`.
  Before, the DocString took all the lines to the end of the file, and the
  parser dropped the scenarios in those lines without a message.
- The parser removes the indentation of the opening `"""` from each
  DocString line, as standard Gherkin does. A line with less indentation
  loses only the indentation it has. Before, each line kept all its
  indentation.
- The parser reads `Background: <name>` and `Examples: <name>`, and keeps
  the name in `Background.name` and `Examples.name`. Before, the parser
  ignored a line with a name, so the background steps went to no
  background and the Examples rows went to no table.
- The values of an `Examples` row replace the `<header>` placeholders in
  the scenario name, the DocStrings (content and media type) and the
  DataTable cells, as in the official Gherkin compiler. Before, only the
  step text changed, so a test was named `the <one>` in place of
  `the un (Example 1)`. The headers replace in column order, so with two
  columns of the same name the first column wins.
- A scenario with no steps runs no Background steps, as in the official
  Gherkin compiler. Before, a failing Background step failed a scenario
  with no steps.
- The Feature tags appear one time in the tags of a Gherkin test. Before, a
  test of a Feature tagged `@f` with a scenario tagged `@s` had the tags
  `["f", "f", "s"]`. Now it has `["f", "s"]`. The order is Feature, Rule,
  scenario, `Examples`.
- A DocString line unescapes each escaped separator of the active
  separator, as the official Gherkin parser does: `\"\"\"` becomes `"""`
  inside a `"""` DocString, and `` \`\`\` `` becomes ```` ``` ```` inside a
  ```` ``` ```` DocString. Before, the backslashes stayed in the content.
- A table cell can be empty. Before, `| a | | b |` gave `["a", "b"]`. Now
  it gives `["a", "", "b"]`.
- A table cell unescapes `\|`, `\\` and `\n`. The text before the first `|`
  and after the last `|` of a row is not a cell.
- A table row with a different number of cells than the first row of its
  table is an `InconsistentCellCount` error.
- A step pattern matches its own text. Before, `I enable 2FA` and
  `I click "Save changes"` matched no step, and `the user is {word}` did
  not match `the user is user42`.
- Step lookup finds a match whenever one exists. Before, with
  `I have {int} items` and `I have 5 apples`, the text `I have 5 items`
  matched no step, because lookup took the literal word `5` and did not go
  back. When two patterns match, a literal word wins over a placeholder.
- `gherkin/discover.to_suite` gives the full file path as the source of a
  parse error test. Before, it cut the path at the first `": "`, so a path
  such as `features/a: b.feature` gave the source `features/a`.

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

[3.0.0]: https://github.com/TrustBound/dream_test/compare/2.1.3...3.0.0
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
