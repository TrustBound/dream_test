# Choose and read the test output

The same run has different readers. You, at a terminal, want to see it move and then see what broke. A CI log wants plain lines, no redraws, and the failures where you'll look for them. A dashboard or a bot wants JSON. A pull request wants an annotation on the test that failed. Dream Test splits its output into reporters so each reader gets what it needs from one run. This guide shows each built-in reporter with its real output, then a reporter of your own for GitHub annotations, a JSON file for tools, and what happens when a reporter crashes.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How reporting works](#how-reporting-works)
- [Which reporter to use](#which-reporter-to-use)
- [Step 1: Read the full report](#step-1-read-the-full-report)
- [Step 2: Make the report short for CI](#step-2-make-the-report-short-for-ci)
- [Step 3: Write JSON for tools](#step-3-write-json-for-tools)
- [Step 4: Write a reporter of your own](#step-4-write-a-reporter-of-your-own)
- [When a reporter crashes](#when-a-reporter-crashes)
- [Use the reports in your own code](#use-the-reports-in-your-own-code)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Read the full BDD report, the failures-only report and the summary-only report of the same run.
- Read the JSON report, key by key.
- Write a reporter that turns failures into GitHub Actions annotations.
- Write the JSON report to a file in the same run.
- See the error the runner writes when a reporter crashes.
- Test your reporter with a run report you build by hand.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

Every report on this page comes from one checkout suite with four tests: one passes, one fails, one is skipped and one is pending.

### The checkout suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/reporters_shop.gleam#L10-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn shop_tests() {
  describe("Checkout", [
    it("totals the cart", fn() {
      1000 + 250
      |> should
      |> be_equal(1250)
      |> or_fail_with("the total should be 1250")
    })
      |> with_tags(["smoke"]),
    it("adds the tax", fn() {
      1250 * 120 / 100
      |> should
      |> be_equal(1525)
      |> or_fail_with("20% tax on 1250 should be 1525")
    }),
    group("payment", [
      skip("charges the card", fn() { Ok(succeed()) }),
      pending("refunds a cancelled order"),
    ]),
  ])
}
```

The outputs are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## How reporting works

Reporting has two phases:

- **During the run**, the progress reporter, `runner.progress_reporter(progress.new())`, reacts to each test as it finishes, in the order they finish. In a terminal, it redraws one line with a carriage return (`\r`): a bar, the count, and the name of the last test. `progress_reporter` takes only a `progress.ProgressReporter`.
- **After the run**, the results reporters, `runner.results_reporters([...])`, each print one whole report of the final results. They see the results in the order of your suites, not the order the tests finished, so the report is the same on every run however the parallel tests raced.

You can have one progress reporter, and any number of results reporters. They print in list order.

## Which reporter to use

| Your situation | Use | Why |
|:---|:---|:---|
| Working at a terminal | `progress.new()` and `bdd.new()` | Live progress, then the full report with the failures again at the end. Add `bdd.color()` for colour. |
| A CI log | `bdd.new() \|> bdd.failures_only()`, no progress reporter | The log keeps every `\r` redraw of the progress line as a new line. Failures only keep the log short. |
| A quick yes or no, such as a pre-commit hook | `bdd.new() \|> bdd.summary_only()` | One line, plus any setup and teardown failures. |
| A tool, a dashboard or an archive | `json.new()`, or `json.new() \|> json.pretty()` | Every test with its status, tags and failures, in a fixed schema. |
| Gherkin features | `reporter_types.Custom(gherkin.format)` | A Cucumber-style report. See [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md). |
| Any other format: annotations, JUnit XML, a file | `reporter_types.Custom(your_function)` | Your function gets the whole run report and returns the text. |

## Step 1: Read the full report

`bdd.new()` prints every test in the shape of your suites, then repeats each failure under `Failures:`, then the summary line:

### The full report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_full.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Checkout
  ✓ totals the cart
  ✗ adds the tax
    be_equal
      Message: 20% tax on 1250 should be 1525
      Expected: 1525
      Actual:   1500
    Run it alone: gleam test -- --only "Checkout/adds the tax"
  payment
    - charges the card
    ~ refunds a cancelled order

Failures:
Checkout
  ✗ adds the tax
    be_equal
      Message: 20% tax on 1250 should be 1525
      Expected: 1525
      Actual:   1500
    Run it alone: gleam test -- --only "Checkout/adds the tax"

Summary: 4 run, 1 failed, 1 passed, 1 skipped, 1 pending in 0ms
```

The marks: `✓` passed, `✗` failed, `!` timed out, `⚠` setup failed, `-` skipped and `~` pending. The summary line counts each status, and shows a count only when it isn't 0, in this order after `passed`: skipped, pending, timed out, setup failed, teardown failed, setup stopped.

A failure whose expected or actual text has more than one line, such as a snapshot, shows a line diff in place of `Expected:` and `Actual:`: a line that starts with `-` is in the expected text only, and a line that starts with `+` is in the actual text only. [Lock down large output with snapshots](https://github.com/TrustBound/dream_test/blob/main/docs/guides/snapshot-testing.md) shows one. A failure in a Gherkin step has a `Step:` line that names the step, before the message.

Each failed, timed-out or setup-failed test ends with a `Run it alone:` line, also under `Failures:` and in the failures-only report. The line holds the command that runs only that test: its path is the suite name, the group names and the test name, joined with `/`. [Run one test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md#run-one-test) gives the rules of `--only`.

With `bdd.color()`, the marks and the summary get ANSI colours. Leave colour off when the output goes to a file or a tool that doesn't read ANSI codes.

## Step 2: Make the report short for CI

On a big suite, the full report is thousands of passing lines with a failure in the middle. Two modes cut it down. `bdd.new() |> bdd.failures_only()` prints only the failures, then the summary:

### The failures-only report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_failures_only.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Checkout
  ✗ adds the tax
    be_equal
      Message: 20% tax on 1250 should be 1525
      Expected: 1525
      Actual:   1500
    Run it alone: gleam test -- --only "Checkout/adds the tax"

Summary: 4 run, 1 failed, 1 passed, 1 skipped, 1 pending in 0ms
```

`bdd.new() |> bdd.summary_only()` prints only the summary line, after the setup and teardown failures when there are any:

### The summary-only report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_summary_only.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Summary: 4 run, 1 failed, 1 passed, 1 skipped, 1 pending in 0ms
```

Leave out the progress reporter on CI. A CI log isn't a terminal: it keeps each redraw of the progress line, so you'd get one partial line for every test.

A run that runs no test fails. In every mode, the BDD and Gherkin reports then end with a `No tests ran` line after the summary line. The JSON report gets no extra line, so it stays valid JSON: its `summary.total` is 0. The progress bar shows `0/0`. [When a filter keeps nothing](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md#when-a-filter-keeps-nothing) shows the run.

## Step 3: Write JSON for tools

`json.new()` prints one JSON object for the whole run, and `json.new() |> json.pretty()` indents it. Here's the pretty report of the checkout suite:

### The JSON report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_json.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
{
  "version": "2.0",
  "timestamp_ms": 0,
  "duration_ms": 0,
  "system": {
    "os": "unix",
    "otp_version": "<release>",
    "gleam_stdlib_version": "1.0.3"
  },
  "summary": {
    "total": 4,
    "passed": 1,
    "failed": 1,
    "skipped": 1,
    "pending": 1,
    "timed_out": 0,
    "setup_failed": 0,
    "teardown_failed": 0,
    "setup_stopped": 0
  },
  "tests": [
    {
      "name": "totals the cart",
      "full_name": [
        "Checkout",
        "totals the cart"
      ],
      "only_path": "Checkout/totals the cart",
      "run_alone": "gleam test -- --only \"Checkout/totals the cart\"",
      "status": "passed",
      "duration_ms": 0,
      "tags": [
        "smoke"
      ],
      "kind": "unit",
      "failures": []
    },
    {
      "name": "adds the tax",
      "full_name": [
        "Checkout",
        "adds the tax"
      ],
      "only_path": "Checkout/adds the tax",
      "run_alone": "gleam test -- --only \"Checkout/adds the tax\"",
      "status": "failed",
      "duration_ms": 0,
      "tags": [],
      "kind": "unit",
      "failures": [
        {
          "operator": "be_equal",
          "message": "20% tax on 1250 should be 1525",
          "expected": "1525",
          "actual": "1500"
        }
      ]
    },
    {
      "name": "charges the card",
      "full_name": [
        "Checkout",
        "payment",
        "charges the card"
      ],
      "only_path": "Checkout/payment/charges the card",
      "run_alone": "gleam test -- --only \"Checkout/payment/charges the card\"",
      "status": "skipped",
      "duration_ms": 0,
      "tags": [],
      "kind": "unit",
      "failures": []
    },
    {
      "name": "refunds a cancelled order",
      "full_name": [
        "Checkout",
        "payment",
        "refunds a cancelled order"
      ],
      "only_path": "Checkout/payment/refunds a cancelled order",
      "run_alone": "gleam test -- --only \"Checkout/payment/refunds a cancelled order\"",
      "status": "pending",
      "duration_ms": 0,
      "tags": [],
      "kind": "unit",
      "failures": []
    }
  ],
  "hook_failures": []
}
```

On this page, `timestamp_ms` is 0 and `otp_version` is `<release>`, because they change from run to run and from machine to machine. In your run, they're the time of the report in milliseconds since 1970, and the OTP release, such as `"28"`.

What each key holds:

| Key | What it holds |
|:---|:---|
| `version` | The schema version, `"2.0"`. |
| `timestamp_ms` | When the report was made, in milliseconds since 1970. |
| `duration_ms` | The sum of the test durations. |
| `system` | `os`, `otp_version`, and `gleam_stdlib_version`, the version of the `gleam_stdlib` package the tests ran with, or `"unknown"` when that application isn't loaded. The Gleam compiler version isn't in the report, because the compiled code doesn't record it. |
| `summary` | The counts by status: `total`, `passed`, `failed`, `skipped`, `pending`, `timed_out`, `setup_failed`, then `teardown_failed`, the teardown hooks that failed, and `setup_stopped`, the setups whose process stopped. |
| `tests` | One object for each test: `name`, `full_name` (the group names, then the test name), `only_path` (the path for `--only`), `run_alone` (the command that runs only this test), `status`, `duration_ms`, `tags`, `kind` and `failures`. Each failure has `operator` and `message`, plus the details of its kind, such as `expected` and `actual`. The `expected` and `actual` texts are whole: the JSON report has no diff. |
| `tests[].kind` | `"unit"`, or `"gherkin:<scenario id>"` for a scenario. The scenario id ends with a number that changes between runs, so compare Gherkin tests by `full_name`, not by `kind`. |
| `tests[].failures[].step` | Only on a failure in a Gherkin step: `keyword` and `text`, the step as the feature writes it, `file`, the path of the `.feature` file or `null`, and `line`, the line of the step or `null` for an inline step. The details of the failure inside the step, such as `expected` and `actual`, follow it. |
| `tests[].feature`, `tests[].rule` | Only on a Gherkin test, after `kind`. `feature` is the name of its Feature, or `null` for a scenario in no Feature group. `rule` is the name of its Rule group, such as `"Rule: Stock"`, or `null` outside a Rule. |
| `hook_failures` | One object for each teardown hook that failed and each setup that stopped, in the order they happened, each with `kind`, `hook`, `path` and `message`. |

The two kinds of `hook_failures`:

- `"kind": "teardown_failed"`: a teardown hook failed. `hook` names it, such as `"after_all"`, or `"context teardown"` for the teardown of a context setup. `path` is where it ran: the full test name for an `after_each` or `after_each_test` hook, the group path for an `after_all` hook or a context teardown, the suite name for `after_each_suite`, or `[]` for `after_all_suites`. `message` is the error or the crash text.
- `"kind": "setup_stopped"`: the process that keeps a setup alive exited while its tests ran. `hook` is `"before_all"`, `"before_each_suite"`, `"before_all_suites"` or `"context setup"`. `path` is the group path, the suite name, or `[]` for the whole run. `message` is the exit reason, and `not_run` lists the tests that hadn't started, each as its `full_name`, such as `[["root", "b"], ["root", "c"]]`.

The text ends with a newline, also in compact form.

## Step 4: Write a reporter of your own

A results reporter is any function from a `RunReport` to a `String`. Give it to the runner as `reporter_types.Custom(your_function)`, and the runner calls it once at the end of the run and writes what it returns. Here's a CI runner with three reporters: the failures, an annotation for each failure that GitHub Actions shows on the pull request, and a line that says where the JSON report went:

### A CI runner with two reporters of its own <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/reporters_ci.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file
import dream_test/reporters/bdd
import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type AssertionFailure, type RunReport, type TestResult}
import gleam/list
import gleam/string
import snippets/guides/reporters_shop

/// Where the JSON report goes.
pub const json_path = "build/test-report.json"

pub fn main() {
  runner.new([reporters_shop.shop_tests()])
  |> runner.results_reporters([
    bdd.new() |> bdd.failures_only(),
    reporter_types.Custom(github_annotations),
    reporter_types.Custom(write_json),
  ])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// Formats each failed test as a GitHub Actions error annotation, one
/// line for each test.
pub fn github_annotations(report: RunReport) -> String {
  types.report_tests(report)
  |> list.filter(is_failed)
  |> list.map(annotation)
  |> string.concat
}

fn is_failed(result: TestResult) -> Bool {
  types.is_failure(result.status)
}

fn annotation(result: TestResult) -> String {
  let name = string.join(types.full_name(result.groups, result.name), " > ")
  let messages = string.join(list.map(result.failures, message), "; ")
  "::error title=" <> name <> "::" <> messages <> "\n"
}

fn message(failure: AssertionFailure) -> String {
  failure.message
}

/// Writes the JSON report to a file, and says where it went.
pub fn write_json(report: RunReport) -> String {
  case file.write(json_path, json.format(report)) {
    Ok(Nil) -> "JSON report: " <> json_path <> "\n"
    Error(error) -> "No JSON report: " <> file.error_to_string(error) <> "\n"
  }
}
```

The run prints this, and the exit status is 1, because a test failed:

### The output of the CI runner <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_ci.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Checkout
  ✗ adds the tax
    be_equal
      Message: 20% tax on 1250 should be 1525
      Expected: 1525
      Actual:   1500
    Run it alone: gleam test -- --only "Checkout/adds the tax"

Summary: 4 run, 1 failed, 1 passed, 1 skipped, 1 pending in 0ms
::error title=Checkout > adds the tax::20% tax on 1250 should be 1525
JSON report: build/test-report.json
```

How it works:

- `types.report_tests(report)` gives the results, each with its `name`, `groups`, `status` and `failures`. `types.full_name(result.groups, result.name)` gives the whole path of a test.
- `types.is_failure(result.status)` is `True` for `Failed`, `SetupFailed` and `TimedOut`.
- A reporter can have side effects too. `write_json` writes the JSON report to a file with `dream_test/file`, and returns a line that says where it went. `json.format(report)` is the same text that `json.new()` prints.
- The runner adds no newline, so end the text with `"\n"`. A reporter that has nothing to say returns `""`.
- For counts, `summary.count(report)` from `dream_test/reporters/summary` gives every count of the summary line, with the teardown failures (`teardown_failed`) apart from the stopped setups (`setup_stopped`). `types.report_hook_failures(report)` gives the hook failures themselves.

The runner calls each reporter in the process of the run, so a reporter must return. An exit signal that reaches that process, for example from a process the reporter linked to it, isn't caught and ends the run. The runner writes every report before it checks coverage, so `runner.exit_on_failure()` is safe with a custom reporter: the report prints, then the program ends with exit status 1 when the run fails.

## When a reporter crashes

A reporter is code, and code has bugs. This runner has a reporter that panics:

### A reporter that crashes <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/reporters_crash.gleam#L8-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([cart_tests()])
  |> runner.results_reporters([
    bdd.new() |> bdd.summary_only(),
    reporter_types.Custom(broken_report),
  ])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// A report that crashes, as one with a bug does.
fn broken_report(_report: RunReport) -> String {
  panic as "the report template is missing"
}
```

The summary prints to the standard output as usual. The runner catches the crash, writes this to the error output, and ends with exit status 1:

### The error of a crashed reporter <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_crash.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text

Results reporter failed
  The Custom results reporter at position 2 in runner.results_reporters crashed: error:#{function => <<"broken_report">>,line => 20, message => <<"the report template is missing">>, module => <<"snippets/guides/reporters_crash">>, file => <<"test/snippets/guides/reporters_crash.gl ... (cut at 200 characters, and types.report_reporter_crashes has the full reason)
  Reason: its render function crashed, so this reporter wrote no report.
  Fix: make the render function return a String for every RunReport.

```

What the runner does:

- It names the reporter by its position in the list. The first reporter is at position 1, and every reporter counts, `bdd` and `json` too.
- It shows the crash on one line: the lines of the crash, each without its leading spaces, joined with a space. When that line is longer than 200 characters, it shows the first 200 and says so. `types.report_reporter_crashes(report)` has the position and the full reason of each crash.
- It goes on with the next reporter and with coverage.
- The crash makes the run fail: `types.failed(report)` is `True`, and with `exit_on_failure` the exit status is 1, even though every test passed.

`runner.silent()` drops every report, but still writes this error to the standard error stream.

## Use the reports in your own code

The formatters of the built-in reporters are plain functions, so you can use them without the runner's output:

- `bdd.render(config:, report:)`, `bdd.format(report:)` and `bdd.format_summary_only(report:)` return the BDD text as a `String`. `bdd.report(report:, write:)` passes it to your `write` function and returns the report.
- `json.format(report:)` and `json.format_pretty(report:)` return the JSON. `json.report` and `json.report_pretty` pass it to `write`.
- `runner.output(runner.Output(out:, error:))` sends everything the runner writes to your two functions, in place of the standard output and the error stream. Use it to capture a whole run, for a snapshot or for a tool that embeds Dream Test.
- `progress.line(progress.new(), event)` and `progress.render(columns, event)` give the text of the progress line for one `progress.ProgressEvent`, for a runner of your own.
- `bdd.format_incremental(result, previous_path)` and `bdd.format_incremental_with_test_indent` print one result at a time, with the group lines it needs, for a reporter that prints while the run goes. `bdd.format_incremental_parts_with_test_indent` gives the group lines and the test line apart.
- `gherkin.format(report)` and `gherkin.report(report, write)` give the Gherkin report. `gherkin.format_scenarios(results)` formats a list of results, and `gherkin.is_gherkin_result(result)` tells a scenario from a unit test.
- `diff.lines(expected:, actual:)` gives the line diff of two texts as `diff.DiffLine` values, `diff.format(expected:, actual:, indent:, color:)` gives it as the text that the BDD and Gherkin reporters show, and `diff.should_diff(expected:, actual:)` tells when they show it. A failure in a Gherkin step has the payload `types.StepFailure`, with the step, its file and line, and the payload of the failure inside it as `cause`.
- `summary.format(report)` and `summary.format_in_color(report)` give the summary line alone, and `hook_failures.format(types.report_hook_failures(report))` and `hook_failures.format_in_color` the `Setup and teardown failures:` section.

## Test your code

A reporter is a pure function from a `RunReport` to a `String`, so test it like one. `types.run_report(tests:, hook_failures:, reporter_crashes:)` builds a report from results you write by hand, so the test controls every name, status and message:

### Tests for the annotation reporter <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/reporters_annotation_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{
  AssertionFailure, Failed, Passed, TestResult, Unit, run_report,
}
import dream_test/unit.{describe, it}
import gleam/option.{None}
import snippets/guides/reporters_ci.{github_annotations}

pub fn tests() {
  describe("github_annotations", [
    it("writes one error line for a failed test", fn() {
      // Arrange
      let failed =
        TestResult(
          name: "adds the tax",
          groups: ["Checkout"],
          status: Failed,
          duration_ms: 3,
          tags: [],
          failures: [
            AssertionFailure(
              operator: "be_equal",
              message: "tax should be 20%",
              payload: None,
            ),
          ],
          kind: Unit,
        )
      let report =
        run_report(tests: [failed], hook_failures: [], reporter_crashes: [])

      // Act
      let text = github_annotations(report)

      // Assert
      text
      |> should
      |> be_equal("::error title=Checkout > adds the tax::tax should be 20%\n")
      |> or_fail_with("a failed test should give one annotation line")
    }),
    it("writes nothing for a run that passed", fn() {
      // Arrange
      let passed =
        TestResult(
          name: "totals the cart",
          groups: ["Checkout"],
          status: Passed,
          duration_ms: 1,
          tags: [],
          failures: [],
          kind: Unit,
        )
      let report =
        run_report(tests: [passed], hook_failures: [], reporter_crashes: [])

      // Act
      let text = github_annotations(report)

      // Assert
      text
      |> should
      |> be_equal("")
      |> or_fail_with("a run that passed should give no annotation")
    }),
  ])
}
```

The first test pins the exact annotation line. The second checks the case that's easy to forget: a run that passed must give no text at all. The report:

### The report of the reporter tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_reporters_check.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
github_annotations
  ✓ writes one error line for a failed test
  ✓ writes nothing for a run that passed

Summary: 2 run, 0 failed, 2 passed in 0ms
```

## Common pitfalls

**The progress reporter in CI.** *Symptom:* a CI log with hundreds of half lines. *Fix:* leave out `runner.progress_reporter` in CI, and use `bdd.failures_only()`.

**A custom report with no newline at the end.** *Symptom:* the next report starts on the same line. *Fix:* end the text with `"\n"`. The runner adds nothing.

**Printing a report after `runner.run()`.** *Symptom:* the report is missing when a test fails. *Fix:* with `exit_on_failure`, `runner.run()` doesn't return when the run fails. Give the formatter to `results_reporters` as `reporter_types.Custom`, so it prints before the program ends.

**Comparing Gherkin tests by `kind`.** *Symptom:* a tool that compares two JSON reports sees every scenario as new. *Fix:* the scenario id in `kind` changes between runs. Match tests by `full_name`.

**A reporter that blocks.** *Symptom:* the run never ends after the last test. *Fix:* the runner waits for each reporter in the run's own process. Keep reporters fast, and don't wait on other processes in them.

## Where to go next

- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): the exit status and the run report.
- [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md): the Gherkin reporter.
- [Measure line coverage and gate CI on it](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md): the coverage table and its files.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/reporters/bdd.html): `bdd`, `json`, `progress`, `gherkin` and `summary`.
