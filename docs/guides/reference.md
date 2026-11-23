# Reference

This page collects the lists and the exact rules that the guides link to: every built-in matcher, the helper modules for tests, the runner settings and their defaults, the statuses, the rules of hook processes, and the Gherkin keywords and matching rules. The guides show how to use them. The full API, with every function and type, is on [HexDocs](https://hexdocs.pm/dream_test/).

## Table of Contents

- [Matchers](#matchers)
- [Statuses and report marks](#statuses-and-report-marks)
- [Runner settings](#runner-settings)
- [Hook processes](#hook-processes)
- [Hook timeouts and crashes](#hook-timeouts-and-crashes)
- [Discovery errors](#discovery-errors)
- [Gherkin keywords](#gherkin-keywords)
- [Gherkin step matching](#gherkin-step-matching)
- [Gherkin test names and tags](#gherkin-test-names-and-tags)
- [Gherkin step failures](#gherkin-step-failures)
- [Gherkin parse errors](#gherkin-parse-errors)
- [File helpers](#file-helpers)
- [Process helpers](#process-helpers)
- [Timing helpers](#timing-helpers)
- [The sandbox](#the-sandbox)
- [Run the executor directly](#run-the-executor-directly)

## Matchers

Every built-in matcher is in `dream_test/matchers`, and goes in the pipeline `value |> should |> matcher(...) |> or_fail_with("...")`. [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md) shows how to choose one, and [Write your own matcher](https://github.com/TrustBound/dream_test/blob/main/docs/guides/custom-matchers.md) how to add one.

| Category | Matcher | What it checks |
|---|---|---|
| Equality | `be_equal(expected)` | Structural equality (`==`). |
| Equality | `not_equal(unexpected)` | Structural inequality (`!=`). |
| Boolean | `be_true()` | The value is `True`. |
| Boolean | `be_false()` | The value is `False`. |
| Option | `be_some()` | The value is `Some(_)`. It unwraps to the inner value for the next matcher. |
| Option | `be_none()` | The value is `None`. |
| Result | `be_ok()` | The value is `Ok(_)`. It unwraps to the `Ok` value. |
| Result | `be_error()` | The value is `Error(_)`. It unwraps to the error value. |
| List | `contain(item)` | The list contains `item`. |
| List | `not_contain(item)` | The list doesn't contain `item`. |
| List | `have_length(n)` | The list has exactly `n` items. |
| List | `be_empty()` | The list is `[]`. |
| Int | `be_greater_than(n)` | The value is `> n`. |
| Int | `be_less_than(n)` | The value is `< n`. |
| Int | `be_at_least(n)` | The value is `>= n`. |
| Int | `be_at_most(n)` | The value is `<= n`. |
| Int | `be_between(min, max)` | Strictly between: `min < value < max`. |
| Int | `be_in_range(min, max)` | In the inclusive range: `min <= value <= max`. |
| Float | `be_greater_than_float(n)` | The value is `> n`. |
| Float | `be_less_than_float(n)` | The value is `< n`. |
| String | `start_with(prefix)` | The string starts with `prefix`. |
| String | `end_with(suffix)` | The string ends with `suffix`. |
| String | `contain_string(substring)` | The string contains `substring`. |
| String | `match_regex(pattern)` | The string matches the regular expression `pattern` anywhere in it. |
| Snapshot | `match_snapshot(path)` | The `String` equals the snapshot file. A missing file is written, and the test passes. |
| Snapshot | `match_snapshot_inspect(path)` | The same, for any value, as `string.inspect` writes it. |
| Ending a chain | `or_fail_with(message)` | Ends the chain and gives the message of a failure. |
| Your own logic | `succeed()`, `fail_with(message)` | A passing or failing result, for a `case` in a test body. |

`clear_snapshot(path)` and `clear_snapshots_in_directory(directory)` delete snapshot files, for an update. Every matcher of this table is in one tested suite:

### Every built-in matcher <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/matchers/builtin_matchers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{
  be_between, be_equal, be_false, be_ok, be_some, be_true, contain,
  contain_string, have_length, match_regex, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Built-in matchers", [
    it("boolean: be_true", fn() {
      True
      |> should
      |> be_true()
      |> or_fail_with("expected True")
    }),
    it("boolean: be_false", fn() {
      False
      |> should
      |> be_false()
      |> or_fail_with("expected False")
    }),
    it("option: be_some + equal", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("expected Some(42)")
    }),
    it("result: be_ok + equal", fn() {
      Ok("hello")
      |> should
      |> be_ok()
      |> be_equal("hello")
      |> or_fail_with("expected Ok(\"hello\")")
    }),
    it("collection: have_length", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("expected list length 3")
    }),
    it("collection: contain", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("expected list to contain 2")
    }),
    it("comparison: be_between", fn() {
      5
      |> should
      |> be_between(1, 10)
      |> or_fail_with("expected 5 to be between 1 and 10")
    }),
    it("string: contain_string", fn() {
      "hello world"
      |> should
      |> contain_string("world")
      |> or_fail_with("expected substring match")
    }),
    it("string: match_regex", fn() {
      "user-123"
      |> should
      |> match_regex("^user-\\d+$")
      |> or_fail_with("expected an id like user-123")
    }),
  ])
}
```

## Statuses and report marks

| Status | BDD mark | When |
|---|---|---|
| `Passed` | `✓` | Every assertion passed. |
| `Failed` | `✗` | An assertion failed, the body returned `Error`, or the test process crashed. |
| `TimedOut` | `!` | The body ran past the test timeout. Its failure is `timeout: test timed out`. |
| `SetupFailed` | `⚠` | A setup hook that serves the test failed, crashed, timed out, or its setup process stopped. The body didn't run. |
| `Skipped` | `-` | The test is a `skip`. The body didn't run. |
| `Pending` | `~` | The test is a `pending`, with no body. |

`types.is_failure(status)` is `True` for `Failed`, `SetupFailed` and `TimedOut`. A run fails when a test has one of these, when a teardown hook failed, when a setup stopped, when a custom results reporter crashed, or when coverage failed. The summary line lists, after `N passed`, the counts that aren't 0, in this order: skipped, pending, timed out, setup failed, teardown failed, setup stopped.

### How a failure shows

- A failure shows its operator, then its `Message:`, then the details of its payload. An `Expected:` and an `Actual:` line show two values of one line.
- When the expected or the actual text has more than one line, or the two texts differ only in whitespace at their ends, the BDD and Gherkin reporters show a line diff in place of the two lines: `Diff (- expected, + actual):`, then `- ` for a line of the expected text only, `+ ` for a line of the actual text only, and two spaces for a line in both. Removed lines come before added lines.
- The diff is a longest common subsequence of the lines, after the common first and last lines. When the other lines make more than 1,000,000 pairs, they show as removed, then added, with a note.
- Same lines more than 3 lines from a change show as one `... N unchanged lines` line. At most 100 diff lines show, then `... N more lines of the diff`.
- A changed line shows trailing spaces as `·`, tabs as `→` and carriage returns as `␍`. When only one text ends with a newline, `\ No newline at end of text` follows the last line of the other text. `match_snapshot` ignores newlines at the end of both texts, and its failure holds the two texts that it compared.
- With colour, `-` lines are green and `+` lines are red. The JSON report holds the whole `expected` and `actual` texts and no diff. `dream_test/reporters/diff` gives the diff to a reporter of your own.

## Runner settings

| Setting | Default | What it does |
|---|---|---|
| `runner.max_concurrency(n)` | 4 | The most tests of one group that run at the same time. A value below 1 counts as 1. |
| `runner.default_timeout_ms(ms)` | 5000 | The timeout of each test body without its own, and of each hook. Must be at least 1. |
| `runner.add_suites_with_config(config, suites)` | the run's settings | Suites with their own `parallel.ParallelConfig(max_concurrency:, default_timeout_ms:)`. |
| `runner.filter_tests(predicate)` | every test | Runs only the tests whose `TestInfo` the predicate accepts. |
| `runner.progress_reporter(progress.new())` | none | Live progress during the run. |
| `runner.results_reporters([...])` | none | Reports after the run, in list order. |
| `runner.output(runner.Output(out:, error:))` | the standard output and error | Where the runner writes. |
| `runner.silent()` | off | Writes nothing to the standard output. Errors still go to the error stream. |
| `runner.exit_on_failure()` | off | Exit status 1 when the run fails, after all output. |
| `runner.coverage(config)`, `runner.coverage_from_environment(config)` | off | Line coverage. |
| `runner.before_all_suites`, `after_all_suites`, `before_each_suite`, `after_each_suite`, `before_each_test`, `after_each_test` | none | Runner hooks. |

`parallel.default_config()` gives the defaults, `ParallelConfig(max_concurrency: 4, default_timeout_ms: 5000)`.

## Hook processes

On the BEAM, a resource often lives as long as the process that started it. Each scope has one process that runs its hooks and lives as long as the tests it serves:

| Hooks | Process | Timeout |
|---|---|---|
| `before_all_suites`, `after_all_suites` | one setup process for the whole run | the default timeout, for each hook |
| `before_each_suite`, `after_each_suite` | one setup process for each suite | the default timeout of the suite, for each hook |
| the context setup and teardown (`unit_context.describe_with_setup`, `steps.new_with_setup`) | one setup process for each tree that has them, started after `before_each_suite` | the default timeout of the suite, for each |
| `before_all`, `after_all` | one setup process for each group | the default timeout, for each hook |
| `before_each_test`, `before_each`, the body, `after_each`, `after_each_test` | one process for each test | the default timeout for each hook, the test timeout for the body |

The default timeout is `runner.default_timeout_ms` (5000 ms when you don't set it), or the `default_timeout_ms` of `runner.add_suites_with_config` for the suites it adds. The test timeout is the `timeout_ms` of the test when it has one, else the default timeout. `unit.it` and `unit_context.it` give no `timeout_ms`. Only a test you build with `types.Test(..., timeout_ms: Some(ms), ...)` has its own.

- A setup hook and its teardown hook run only when at least one of the tests they serve runs, with or without `runner.filter_tests`. A group with no test runs no `before_all` or `after_all`, a suite with no test runs no `before_each_suite` or `after_each_suite`, and a run with no test runs no `before_all_suites` or `after_all_suites`.
- A pool that `before_all` starts lives until `after_all` stops it. A pool that `before_each` starts lives for the body and the `after_each` hooks of that test.
- When the tests a setup serves end, its setup process exits with reason `shutdown`. An ETS table that the setup process made is deleted, and every linked process stops, for example an actor that `before_all` started.
- When a test ends, its process exits with reason `shutdown`, or is killed on a timeout. An ETS table that the test made is deleted, and every linked process that doesn't trap exits stops, for example an actor from `process.start_actor`.
- If the body of a test times out, or the test process stops, the `after_each` and `after_each_test` hooks that didn't run yet still run, in a new process with their own timeouts. They get the context after the last `before_each` hook that returned. The test keeps its status, for example `TimedOut`.
- A test process that stops during the body gives `Failed` with `crash: worker crashed in <group>: <reason>`.

## Hook timeouts and crashes

A hook fails when it returns `Error(message)`, crashes or times out. A failed setup hook gives `SetupFailed` to each test it serves, and the teardown hooks of the levels that started still run. A failed teardown hook doesn't change a test status: all the remaining teardown hooks still run, the failure goes into `types.report_hook_failures(report)`, and the run fails. The BDD and Gherkin reporters show it in a `Setup and teardown failures:` section, the summary counts `N teardown failed`, and the JSON reporter writes it in `hook_failures`.

The runner waits for each hook with its timeout. The run goes on after a timeout. The message names the hook level:

- `before_all`, `after_all`, `before_each`, `after_each`, `before_each_test` and `after_each_test`: `hook timed out in <groups>`, with the group names joined by ` > `.
- `before_each_suite` and `after_each_suite`: `hook timed out in <suite>`.
- `before_all_suites` and `after_all_suites`: `hook timed out`.
- A context setup or teardown: `the context setup timed out in <groups>` or `the context teardown timed out in <groups>`.

A crash in a hook, or a crash of the process that runs it, doesn't stop the run:

- A hook that returns `Error` or crashes inside the hook is a failure of that hook: `hook crashed in <scope>: <reason>`. A context setup that crashes reads `the context setup crashed in <groups>: <reason>`.
- When the process that runs a setup hook (`before_all`, `before_each_suite`, `before_all_suites`) or the context setup exits, the setup stopped, as below: no other setup hook of the scope runs. When the process that runs a teardown hook exits, the runner records a failure of that hook.
- After a timeout or a crash of its setup process, the next hook of the scope runs in a new setup process.

If the process that keeps a setup alive exits while or after its setup hooks run, for example because a `before_all` hook killed it or a process linked to it crashed, the setup stopped:

- The run report gets a `types.SetupStopped(setup:, path:, reason:, not_run:)` failure. `not_run` is the full name of each test that the runner didn't run because of it.
- The reporters show `before_all in "<groups>" stopped: the process that keeps its setup alive exited with <reason>.`, then, when tests weren't run, the line `These tests had not started and were not run:` and the full name of each test, such as `root > b`. The JSON reporter writes `not_run` as a list of `full_name` lists.
- Each test of the scope that didn't start is `SetupFailed` with `not run: the setup from before_all in "<groups>" stopped (<reason>)`, `not run: the setup from before_each_suite in "<suite>" stopped (<reason>)`, `not run: the setup from before_all_suites stopped (<reason>)`, or, for a context setup, `not run: the context setup of "<groups>" stopped (<reason>)`.
- No hook of a group or suite under the stopped setup starts. The tests that started keep their results. The teardown hooks of the scope run in a new setup process.
- The runner checks the process of each setup around a test (the whole run, the suite and the groups) before each test and each group starts.

## Discovery errors

`discover.to_suites` and `discover.load` turn each problem into a failing test in the group `Discovery Errors`, so a wrong pattern never gives a run that passes with no tests. Each discovered module must define `pub fn tests()` that returns a `TestSuite`. A module without it is skipped with no error. A pattern names files under `test/`, such as `unit/**_test.gleam` for `test/unit/cart_test.gleam`.

| Test name | Cause |
|---|---|
| `<pattern>: cannot search for test modules: <class>:<reason>` | The pattern can't be searched. |
| `<pattern>: no test module matches the pattern` | No module that the pattern matches has `tests()`. |
| `<module>: cannot load the module: <reason>` | The beam file of the module doesn't load. |
| `<module>: tests() crashed: <class>:<reason>` | `tests()` crashed. |
| `<module>: tests() did not return a test suite: <value>` | `tests()` returned another value. |

`discover.to_suite` puts each module suite in one group, and the load errors stay directly under the suite name. `discover.list_modules` gives the module names that a discovery finds.

## Gherkin keywords

The parser follows the official Gherkin grammar, and knows these English keywords and synonyms:

| Keyword | Synonyms |
|---|---|
| `Feature:` | `Business Need:`, `Ability:` |
| `Rule:` | |
| `Background:` | |
| `Scenario:` | `Example:` |
| `Scenario Outline:` | `Scenario Template:` |
| `Examples:` | `Scenarios:` |
| `Given`, `When`, `Then`, `And`, `But`, `*` | |
| DocString `"""` | DocString ```` ``` ```` |

A `# language:` line must name `en`, because the parser knows only English. A step can have a DataTable and a DocString, in either order, and the step function gets them in `context.table` and `context.doc_string`.

Phase rules:

- Given, When and Then are the three phases of a scenario: Arrange, Act and Assert. Each step definition belongs to one phase, and a step matches only the definitions of its phase.
- `And`, `But` and `*` take the phase of the step before them.
- The first step of a Background must use Given, When or Then. The first step of a Scenario or Scenario Outline must too, unless a Background step runs before it: then it can start with `And`, `But` or `*`, which takes the phase of the last Background step.
- In a Rule, the Feature Background steps and the Rule Background steps both run before the scenario, in that order. The Background steps get the initial state first, and the scenario steps get the state the last Background step gave.
- A `.feature` file that breaks these rules doesn't parse, and the error names the file and the line. An inline feature that breaks them fails each scenario before any step runs, with the text of the parse problem, such as `"And a base" has no step before it. ...`.
- Each pattern can have one step definition in each phase. A second definition of the same pattern in the same phase is a duplicate: `steps.validate` returns the duplicates, and each scenario that uses the registry fails with them. The same pattern in two phases isn't a duplicate.

## Gherkin step matching

The placeholders:

- `{int}`: an integer, such as `42` or `-5`.
- `{float}`: a number as Cucumber reads it: an optional sign, digits with an optional `.` and digits (or `.` and digits alone), and an optional exponent, such as `3.14`, `-0.5`, `20`, `.5` or `1.5e-3`. `5.`, `1,000` and `NaN` aren't numbers.
- `{string}`: a double-quoted string, such as `"hello world"`. The capture has no quotes.
- `{word}`: a run of characters with no space, such as `alice` or `user42`.
- `{}`: any text in one word.

Step text and patterns are split into words at spaces, in the same way. A double-quoted run stays in one word. A quoted run starts at a double quote at the start of a word, also after `(` or `[`. It ends at a double quote before a space, the end of the step, or one of `,` `.` `)` `]` `;` `:` `!` `?`. So `I add "apple", "banana"` matches `I add {string}, {string}`, and the quote in `O"Brien` or `5"` is an ordinary character.

A placeholder can have literal text before or after it in the same word: `${float}USD` matches `$19.99USD` and captures `19.99`. A space in a pattern must be a space in the text: `$ {float}` doesn't match `$19.99`. A pattern without placeholders always matches its own text.

When more than one pattern matches a step, lookup compares the words from left to right, and takes the pattern with the more specific word at the first word where they differ:

1. A word with no placeholders comes first.
2. Then a word with more segments (literal text and placeholders) comes first. `{int}%` comes before `{word}`.
3. Then the segments are compared from left to right. Literal text comes before `{string}`, then `{int}`, `{float}`, `{word}` and `{}`. Longer literal text comes before shorter literal text.

If the most specific word leads to no match for the rest of the step, lookup tries the next one, so it finds a match whenever one exists. The capture helpers `get_int`, `get_float`, `get_string` and `get_word` return a `Result`, and `capture_count` gives the number of captures. A wrong capture gives an error such as `Capture 0 is the word "apples", not an integer`.

## Gherkin test names and tags

- Each Feature is a group named after it. The BDD and Gherkin reporters print `Feature: <name>` on that group, and on no other group, so a suite name or a `suite.group` above it prints as a plain group.
- Each Rule becomes a group named `Rule: <name>`, or `Rule:` for a Rule with no name, under the Feature. The full name of a scenario in a Rule is `Feature > Rule: <name> > Scenario`.
- Each Examples row becomes one test named `<scenario> (Example N)`, or `<scenario> (<examples name>, Example N)` when the `Examples` section has a name. N counts the rows of all `Examples` sections of the scenario, from 1, so each name is different. Every row of every section runs.
- The values of an Examples row replace the `<header>` placeholders in the scenario name, the step texts, the DocStrings and the DataTable cells, in column order.
- A scenario with no `Examples` section runs one time, also when its keyword is `Scenario Outline`. An `Examples` section with no rows makes no tests. A scenario with no steps runs no Background steps.
- The tags of a test are the Feature tags, then the Rule tags, then the scenario tags, then the `Examples` tags. Tag filters see all of them.
- The result kind of a scenario is `GherkinScenario(scenario_id:, feature:, rule:)`. `feature` is `Some("<feature>")` for a scenario in the group of its Feature (with `steps.feature_suite`, `steps.Feature`, the `feature.feature` builders and `discover.to_suite`), and `None` for one of `steps.Scenarios`. `rule` is `Some("Rule: <name>")` inside a Rule, and `None` outside one. The Gherkin reporter prints the Rule heading from this field, so a Feature named `Rule: refunds` prints as `Feature: Rule: refunds`.

## Gherkin step failures

- A scenario stops at its first step that fails. Its failure has the payload `types.StepFailure(keyword:, text:, file:, line:, cause:)`: the step as the feature writes it, the path of the `.feature` file (`None` for an inline feature or `parser.parse_string`), the line of the step (`None` for an inline step), and the payload of the failure inside the step.
- The reporters print `Step: <keyword> <text>` after the operator, with ` (<file>:<line>)`, ` (line N)` or nothing after it. In an Examples row, the text has the values of the row.
- A check that fails keeps its matcher as the operator, for example `be_equal`, and its message and values. A step function that returns `Error(message)`, an undefined step and a step that starts with `And`, `But` or `*` with no step before it give the operator `step`. A step function that crashes gives the operator `crash`, with the crash reason as the message.
- A failure that is not in one step, such as a duplicate step definition, has no `Step:` line. A scenario that times out fails with `timeout` and no step.
- The JSON report has the step as a `step` object with `keyword`, `text`, `file` and `line`, before the fields of the failure inside the step.

## Gherkin parse errors

- `parser.parse_string` returns a `ParseError(line, problem)`. `ParseProblem` has one variant for each kind of problem, such as `UnexpectedLine`, `InconsistentCellCount` or `MissingPreviousStep`. `parser.parse_error_to_string` gives a message that starts with `line N:`, and `parser.problem_to_string` gives the text of the problem alone.
- `parser.parse_file` returns a `FeatureFileError`: `UnreadableFeatureFile(error)` when the file can't be read, or `InvalidFeatureFile(path, error)` when the text isn't valid Gherkin. Two more variants come only from discovery: `NoMatchingFeatureFiles(pattern)` when a pattern matches no files, and `InvalidFeatureFilePattern(pattern, reason)` when a pattern can't be searched.
- `parser.feature_file_error_to_string` gives a message such as `test/cart.feature: line 3: ...` for a parse error. For the other errors it starts with `Failed to read feature file:`, `No feature files match the pattern` or `Cannot search for feature files with the pattern`.
- `discover.load` gives the same `FeatureFileError` values in `LoadResult.errors`.

## File helpers

`dream_test/file` reads and writes files with typed errors, for fixtures, temp files and snapshots. `read` and `write` (which makes the parent folders), `delete` (which gives `Ok` for a file that doesn't exist), `delete_files_matching(directory, extension)`, and `error_to_string` for a `FileError`: `NotFound`, `PermissionDenied`, `IsDirectory`, `NoSpace` or `FileSystemError`.

### File helpers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/file_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file.{
  NotFound, delete, delete_files_matching, error_to_string, read, write,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/result

fn tmp_path() {
  "./test/tmp/file_helpers_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn tests() {
  describe("File helpers", [
    it("write + read roundtrip", fn() {
      let path = tmp_path()

      // Setup: create the file (no assertions during setup)
      use _ <- result.try(
        write(path, "hello") |> result.map_error(error_to_string),
      )

      read(path)
      |> should
      |> be_equal(Ok("hello"))
      |> or_fail_with("expected to read back written content")
    }),

    it("delete removes a file", fn() {
      let path = tmp_path()

      // Setup: create the file, then delete it (no assertions during setup)
      use _ <- result.try(
        write(path, "hello") |> result.map_error(error_to_string),
      )
      use _ <- result.try(delete(path) |> result.map_error(error_to_string))

      read(path)
      |> should
      |> be_equal(Error(NotFound(path)))
      |> or_fail_with("expected deleted file to be NotFound")
    }),

    it("error_to_string formats NotFound", fn() {
      error_to_string(NotFound("/x"))
      |> should
      |> be_equal("File not found: /x")
      |> or_fail_with("expected NotFound formatting")
    }),

    it("delete_files_matching deletes files with a given extension", fn() {
      let directory = "./test/tmp/file_helpers_" <> int.to_string(unique_port())
      let a = directory <> "/a.snap"
      let b = directory <> "/b.snap"
      let keep = directory <> "/keep.txt"

      // Setup: create 2 matching files and 1 non-matching file
      use _ <- result.try(write(a, "a") |> result.map_error(error_to_string))
      use _ <- result.try(write(b, "b") |> result.map_error(error_to_string))
      use _ <- result.try(
        write(keep, "keep") |> result.map_error(error_to_string),
      )

      delete_files_matching(directory, ".snap")
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("expected two deleted snapshots")
    }),
  ])
}
```

## Process helpers

`dream_test/process` has small helpers for tests that use processes:

- A counter: `start_counter`, `start_counter_with`, `get_count`, `increment`, `decrement` and `set_count`.
- `unique_port()`: a random port from 10,000 to 59,999. It doesn't check that the port is free, and two calls can give the same port, so it makes a collision unlikely, not impossible.
- `start_actor` and `call_actor`: start an actor linked to the test, and call it.
- `await_ready` and `await_some`: poll a check until it gives a value or a timeout, with `default_poll_config` or `quick_poll_config`. They measure `timeout_ms` on the monotonic clock, so the time the check takes counts, and `interval_ms: 0` still times out.

### Counter and port helpers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/process_counter_and_port.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_between, be_equal, or_fail_with, should}
import dream_test/process.{get_count, increment, start_counter, unique_port}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Process helpers", [
    it("start_counter + increment + get_count work", fn() {
      let counter = start_counter()
      increment(counter)
      increment(counter)

      get_count(counter)
      |> should
      |> be_equal(2)
      |> or_fail_with("expected counter to be 2")
    }),

    it("unique_port returns a value in the safe range", fn() {
      unique_port()
      |> should
      |> be_between(10_000, 60_000)
      |> or_fail_with("expected unique_port to be within 10k..60k")
    }),
  ])
}
```

## Timing helpers

`dream_test/timing` gives monotonic time, `now_ms()` and `now_us()`, and readable durations, `format_duration_ms` and `format_duration_us`.

### Timing helpers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/timing_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Timing", [
    it("format_duration_ms scales milliseconds and seconds", fn() {
      // Arrange & Act
      let ms = timing.format_duration_ms(42)

      // Assert
      ms
      |> should
      |> be_equal("42ms")
      |> or_fail_with("expected 42ms")
    }),

    it("format_duration_ms formats 1500ms as seconds", fn() {
      timing.format_duration_ms(1500)
      |> should
      |> be_equal("1.5s")
      |> or_fail_with("expected 1.5s")
    }),

    it("format_duration_us formats sub-millisecond values", fn() {
      timing.format_duration_us(500)
      |> should
      |> be_equal("0.5ms")
      |> or_fail_with("expected 0.5ms")
    }),

    it("now_ms is monotonic (non-decreasing)", fn() {
      let t1 = timing.now_ms()
      let t2 = timing.now_ms()
      let ok = t2 >= t1

      ok
      |> should
      |> be_equal(True)
      |> or_fail_with("expected now_ms to be monotonic")
    }),

    it("now_us is monotonic (non-decreasing)", fn() {
      let t1 = timing.now_us()
      let t2 = timing.now_us()
      let ok = t2 >= t1

      ok
      |> should
      |> be_equal(True)
      |> or_fail_with("expected now_us to be monotonic")
    }),
  ])
}
```

## The sandbox

`dream_test/sandbox` is how the runner isolates tests: it runs a function in its own process, with a timeout, and turns a crash into a value. `run_isolated(config, run, input)` takes the function and its input. The module also has:

- `run_catching`: run a function in the calling process, and give a crash as an `Error`.
- `default_config` and `with_crash_reports`: a `SandboxConfig` with the default timeout, and one that shows crash reports.
- `run_in_setup_process`, `check_setup_process` and `stop_setup_process`: run functions one after another in a process that stays alive, as the runner does for a setup and its teardown.
- `kill_and_wait` and `format_exit_reason`: stop a process and wait for its exit, and give an exit reason as text.

### Sandboxed functions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/sandboxing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/unit.{describe, it}

fn double(number: Int) -> Int {
  number * 2
}

fn loop_forever(_input: Nil) -> Nil {
  loop_forever(Nil)
}

fn crash(message: String) -> Int {
  panic as message
}

pub fn tests() {
  describe("Sandboxing", [
    it("run_isolated returns SandboxCompleted(value) on success", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, double, 61)

      result
      |> should
      |> be_equal(SandboxCompleted(122))
      |> or_fail_with("expected SandboxCompleted(122)")
    }),

    it(
      "run_isolated returns SandboxTimedOut when the function is too slow",
      fn() {
        let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
        let result = sandbox.run_isolated(config, loop_forever, Nil)

        result
        |> should
        |> be_equal(SandboxTimedOut)
        |> or_fail_with("expected SandboxTimedOut")
      },
    ),

    it("run_isolated returns SandboxCrashed when the function panics", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, crash, "boom")

      let did_crash = case result {
        SandboxCrashed(_) -> True
        _ -> False
      }

      did_crash
      |> should
      |> be_equal(True)
      |> or_fail_with("expected SandboxCrashed(...)")
    }),
  ])
}
```

## Run the executor directly

The runner uses `dream_test/parallel` to run each tree. It's public so tools can embed the executor, but most projects never call it. The executor runs a typed tree, a `types.Tree(context)`: one top-level group with its children and one context. Build one with `types.tree`, not with `unit.describe`, which gives a `TestSuite`. `parallel.run_tree_parallel` returns a `RunReport`.

### Run the executor directly <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/parallel_direct.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{have_length, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/types
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Parallel executor", [
    it("can run a tree and return a report of the results", fn() {
      let tree =
        types.tree("Suite", Nil, [
          it("a", fn() { Ok(succeed()) }),
          it("b", fn() { Ok(succeed()) }),
        ])

      parallel.run_tree_parallel(parallel.default_config(), tree)
      |> types.report_tests
      |> should
      |> have_length(2)
      |> or_fail_with("expected two results")
    }),
  ])
}
```
