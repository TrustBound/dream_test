## Reporters (BDD, JSON, Progress, Gherkin)

Reporters are the bridge between “test results” and “what someone sees.”

This chapter helps you choose an output style for humans (local dev), for machines (CI/tooling), and for scenarios where you want both.

### Mental model

Dream Test reporting is split into two phases:

- **Progress reporter (during the run)**: reacts to events in completion order and renders live progress.
- **Results reporters (end of run)**: print whole report blocks from the final, traversal-ordered results.

This keeps output readable under parallel execution:

- Progress redraws one line in an interactive terminal while tests finish.
- Final reports are deterministic and easy to scan/tail.

### Recommended default: progress + BDD

This is the standard “human” output: live progress while tests run, then a full BDD report (with failures repeated near the end) and a summary.

#### Progress and BDD output <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/bdd_reporter.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("BDD reporter", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### JSON results reporter (end of run)

Use JSON output for CI/CD integration and tooling (parsing, dashboards, artifact uploads).

#### JSON output <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/json_reporter.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/json
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("JSON Reporter", [
    it("outputs JSON format", fn() {
      // `json.new()` prints machine-readable JSON at the end of the run.
      Ok(succeed())
    }),
    it("includes test metadata", fn() {
      // JSON output includes name, full_name, status, duration, tags
      Ok(succeed())
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([json.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

The JSON schema version is `2.0`. The object has `version`, `timestamp_ms`, `duration_ms`, `system`, `summary`, `tests` and `teardown_failures`:

- `summary` counts the tests by status (`total`, `passed`, `failed`, `skipped`, `pending`, `timed_out`, `setup_failed`), `teardown_failed` counts the tear-down hooks that failed, and `setup_stopped` counts the set-ups whose process stopped.
- `tests` has one object for each test, with `name`, `full_name`, `status`, `duration_ms`, `tags`, `kind` and `failures`. `kind` is `"unit"` or `"gherkin:<scenario id>"`. The scenario id ends with a number that changes on each run, so do not compare `kind` of a Gherkin test between runs. Compare `full_name`. Only a Gherkin test has `rule`, after `kind`: the name of its Rule group, for example `"Rule: Stock"`, or `null` for a scenario outside a Rule.
- `teardown_failures` has one object for each tear-down hook that failed and each set-up that stopped, in the order that they happened. Each object has `kind`, `hook`, `groups` and `message`:
  - `"kind": "hook_failed"`: a tear-down hook failed. `hook` is the hook (for example `"after_all"`, or `"suite tear-down"` for the tear-down of a suite with a set-up), `groups` is the full test name for an `after_each` or `after_each_test` hook, the group path for an `after_all` hook or a `suite tear-down`, the suite name for `after_each_suite`, or `[]` for `after_all_suites`, and `message` is the error message or the crash text.
  - `"kind": "setup_stopped"`: the process that keeps a set-up alive exited while its tests ran. `hook` is the set-up hook (`"before_all"`, `"before_each_suite"`, `"before_all_suites"` or `"suite set-up"`), `groups` is the group path, the suite name, or `[]` for the whole run, `message` is the exit reason of the process, and `not_run` is the tests that had not started and were not run, each one as its `full_name` list, for example `[["root", "b"], ["root", "c"]]`.
- Version `1.0` put a failed tear-down hook in `tests`, as a test named `<after_all>`, `<after_each_suite>` or `<after_all_suites>`. Version `2.0` does not.

### Progress reporter (during the run)

Use progress output in an interactive terminal. It redraws one line with a carriage return (`\r`), so a CI log that keeps every write shows many partial lines. For CI logs, use the BDD or JSON results reporter.

#### Progress output <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/progress_reporter.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Progress reporter", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.exit_on_failure()
  |> runner.run()
}
```

### Post-run formatting (render into a string)

Post-run formatting is useful when you want to:

- Save reports to disk
- Embed results into a larger tool
- Perform extra processing before output

#### Format a report into a string <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/bdd_formatting.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{match_snapshot, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/types
import dream_test/unit.{describe, it}

fn sample_results() -> List(types.TestResult) {
  [
    types.TestResult(
      name: "passes",
      groups: ["Example Suite"],
      status: types.Passed,
      duration_ms: 0,
      tags: [],
      failures: [],
      kind: types.Unit,
    ),
  ]
}

pub fn tests() {
  describe("BDD formatting", [
    it("format returns a report string", fn() {
      let report =
        bdd.format(
          types.run_report(tests: sample_results(), teardown_failures: []),
        )

      report
      |> should
      |> match_snapshot("./test/snapshots/bdd_format_report.snap")
      |> or_fail_with("expected formatted report snapshot match")
    }),
  ])
}
```

### Custom reporters

Dream Test supports **custom reporting** in two ways:

- **Custom output routing**: decide where runner output goes (stdout, stderr, file, in-memory buffer).
- **Custom results reporters**: write your own formatter over the `types.RunReport`, and give it to `runner.results_reporters` as `reporter_types.Custom(..)`.

`runner.progress_reporter(...)` accepts only `progress.ProgressReporter`.

#### Custom output routing (capture output)

Use `runner.output(...)` to route any reporter output into your own sinks.
This is useful for snapshots, embedding Dream Test in other tools, or writing reports to files.

##### Capture the runner output <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/output_routing.gleam#L1-L65"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{succeed}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/erlang/process as beam_process
import gleam/list
import gleam/otp/actor
import gleam/string

pub type OutMsg {
  Write(String)
  GetAll(beam_process.Subject(List(String)))
}

fn handle_out(
  state: List(String),
  msg: OutMsg,
) -> actor.Next(List(String), OutMsg) {
  case msg {
    Write(line) -> actor.continue([line, ..state])
    GetAll(reply) -> {
      beam_process.send(reply, state)
      actor.continue(state)
    }
  }
}

fn start_out() -> beam_process.Subject(OutMsg) {
  let assert Ok(started) =
    actor.new([])
    |> actor.on_message(handle_out)
    |> actor.start
  started.data
}

fn read_out(out: beam_process.Subject(OutMsg)) -> String {
  actor.call(out, waiting: 1000, sending: GetAll)
  |> list.reverse
  |> string.concat
}

pub fn main() {
  let out = start_out()
  let write = fn(s: String) { beam_process.send(out, Write(s)) }
  let output = runner.Output(out: write, error: write)

  let _results =
    runner.new([example_suite()])
    |> runner.progress_reporter(progress.new())
    |> runner.results_reporters([bdd.new() |> bdd.summary_only()])
    |> runner.output(output)
    |> runner.run()

  let captured = read_out(out)
  // Now you can snapshot/parse/write `captured` however you want.
  let _ = captured
  Nil
}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}
```

#### Custom post-run reporter (format a `RunReport`)

If you want a new report format (JUnit XML, GitHub annotations, your own table layout),
write a pure formatter over the `types.RunReport`. Read the tests with `types.report_tests` and the set-up and tear-down failures with `types.report_teardown_failures`, or get all the counts with `summary.count`. It counts the tear-down hooks that failed (`teardown_failed`) apart from the set-ups whose process stopped (`setup_stopped`).

##### A post-run report formatter <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/custom_post_run_reporter.gleam#L1-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/reporters/summary
import dream_test/reporters/types as reporter_types
import dream_test/runner
import dream_test/types.{type RunReport}
import dream_test/unit.{describe, it}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/string

pub fn render_my_report(report: RunReport) -> String {
  // `summary.count` counts the tests by status. It counts the tear-down
  // hooks that failed apart from the set-ups whose process stopped.
  let counts = summary.count(report)

  string.concat([
    "MyReport: ",
    int.to_string(counts.run),
    " total; ",
    int.to_string(counts.passed),
    " passed; ",
    int.to_string(counts.failed + counts.timed_out + counts.setup_failed),
    " failed; ",
    int.to_string(counts.teardown_failed),
    " tear-down failed; ",
    int.to_string(counts.setup_stopped),
    " set-up stopped\n",
  ])
}
```

Then give the formatter to the runner as `reporter_types.Custom(render_my_report)`. At the end of the run, the runner calls the formatter one time and writes the text that it returns. The runner adds no newline, so end the text with `"\n"`. The reports print in list order, with `bdd` and `json` reports in the same list.

The runner writes every report before it checks coverage. Thus `runner.exit_on_failure()` is safe here: the report prints first, then the program ends with exit status 1 when the run fails. The run fails when a test fails, times out or has a failed set-up, when a hook fails, or when coverage is below a minimum.

##### Give the formatter to the runner <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/custom_post_run_reporter.gleam#L31-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([reporter_types.Custom(render_my_report)])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

For a run with one passing and one failing test, this `main` prints `MyReport: 2 total; 1 passed; 1 failed; 0 tear-down failed; 0 set-up stopped`, then ends with exit status 1.

#### Driving the progress reporter manually (advanced)

If you’re building a custom tool, you can reuse the built-in progress renderer:

- `progress.line(progress.new(), event)` returns the text for one `progress.ProgressEvent`:
  `RunStartedProgress`, `TestFinishedProgress` or `RunFinishedProgress`
- `progress.render(columns, event)` returns the bar for a fixed width, with no carriage return
- You decide where to write it, and when (or whether) to print it

This is intentionally **not** the common path; most users should attach progress via
`runner.progress_reporter(progress.new())`.

### Gherkin reporter (post-run, Cucumber-style)

If your suites come from the Gherkin modules (`dream_test/gherkin/feature`, `dream_test/gherkin/discover`), `dream_test/reporters/gherkin` renders the results in a Cucumber-like format.

#### Gherkin report <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/reporters/gherkin_reporter.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps
import dream_test/matchers.{succeed}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/reporters/types as reporter_types
import dream_test/runner

fn step_ok(state: Nil, _context: steps.StepContext) {
  Ok(state)
}

fn check_ok(_state: Nil, _context: steps.StepContext) {
  Ok(succeed())
}

pub fn tests() {
  let steps =
    steps.new(initial: Nil)
    |> steps.given("everything is fine", step_ok)
    |> steps.then("everything is fine", check_ok)

  feature("Gherkin Reporting", steps, [
    scenario("A passing scenario", [
      given("everything is fine"),
      then("everything is fine"),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([
    reporter_types.Custom(gherkin_reporter.format),
  ])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

`gherkin_reporter.format` takes a `RunReport` and gives a `String`, so it goes in `results_reporters` as `reporter_types.Custom(gherkin_reporter.format)`, as in [the custom report](#custom-post-run-reporter-format-a-runreport) above. With `runner.exit_on_failure()`, the report prints, then the program ends with exit status 1 when the run fails.

### Choosing a reporter (a quick heuristic)

- **Local dev**: start with BDD output.
- **Big suites in an interactive terminal**: progress output, with a results reporter for the end.
- **CI logs**: BDD output without progress, or with `bdd.failures_only`.
- **Tooling / CI integration**: JSON output (and/or post-run formatting to write files).
- **Behavior specs**: use `dream_test/reporters/gherkin` when your suites come from `dream_test/gherkin/feature` or `dream_test/gherkin/discover`.

### What's Next?

- Go back to [Runner & execution model](07-runner-and-execution.md)
- Go back to [Documentation README](README.md)
- Continue to [Snapshot testing](09-snapshot-testing.md)
