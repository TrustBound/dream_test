## Reporters (BDD, JSON, Progress, Gherkin)

Reporters are the bridge between “test results” and “what someone sees.”

This chapter helps you choose an output style for humans (local dev), for machines (CI/tooling), and for scenarios where you want both.

### Mental model

Dream Test reporting is split into two phases:

- **Progress reporter (during the run)**: reacts to events in completion order and renders live progress.
- **Results reporters (end of run)**: print whole report blocks from the final, traversal-ordered results.

This keeps output readable under parallel execution:

- Progress stays responsive and keeps CI logs alive.
- Final reports are deterministic and easy to scan/tail.

### Recommended default: progress + BDD

This is the standard “human” output: live progress while tests run, then a full BDD report (with failures repeated near the end) and a summary.

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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/bdd_reporter.gleam)</sub>

### JSON results reporter (end of run)

Use JSON output for CI/CD integration and tooling (parsing, dashboards, artifact uploads).

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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/json_reporter.gleam)</sub>

### Progress reporter (during the run)

Use progress output when you want compact logs, especially for large suites.

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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/progress_reporter.gleam)</sub>

### Post-run formatting (render into a string)

Post-run formatting is useful when you want to:

- Save reports to disk
- Embed results into a larger tool
- Perform extra processing before output

```gleam
import dream_test/matchers.{
  contain_string, or_fail_with, should, succeed,
}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("BDD formatting", [
    it("format returns a report string", fn() {
      let results = runner.new([example_suite()]) |> runner.run()
      let report = bdd.format(results)

      report
      |> should
      |> contain_string("Example Suite")
      |> or_fail_with("Expected formatted report to include the suite name")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/bdd_formatting.gleam)</sub>

### Custom reporters

Dream Test currently supports **custom reporting** in two practical ways:

- **Custom output routing**: decide where runner output goes (stdout, stderr, file, in-memory buffer).
- **Custom post-run reporters**: write your own formatter over `List(TestResult)` and print it after `runner.run()`.

Note: the runner’s built-in “attach” points are intentionally small today:

- `runner.progress_reporter(...)` currently accepts only `progress.ProgressReporter`
- `runner.results_reporters([...])` currently accepts the built-in `bdd`/`json` results reporters

If you want “plug in an arbitrary reporter module” wired into the runner, you can still do it by building your own driver around `runner.run()` (post-run), or by implementing a custom executor/event loop (advanced).

#### Custom output routing (capture output)

Use `runner.output(...)` to route any reporter output into your own sinks.
This is useful for snapshots, embedding Dream Test in other tools, or writing reports to files.

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

#### Custom post-run reporter (format `List(TestResult)`)

If you want a new report format (JUnit XML, GitHub annotations, your own table layout),
write a pure formatter over `List(TestResult)` and run it after `runner.run()`.

```gleam
import dream_test/types.{
  type Status, type TestResult, Failed, Passed, Pending, SetupFailed, Skipped,
  TimedOut,
}
import gleam/int
import gleam/list
import gleam/string

pub fn render_my_report(results: List(TestResult)) -> String {
  let total = list.length(results)
  let failed = count(results, Failed)
  let timed_out = count(results, TimedOut)
  let setup_failed = count(results, SetupFailed)
  let skipped = count(results, Skipped)
  let pending = count(results, Pending)
  let passed = total - failed - timed_out - setup_failed - skipped - pending

  string.concat([
    "MyReport: ",
    int.to_string(total),
    " total; ",
    int.to_string(passed),
    " passed; ",
    int.to_string(failed + timed_out + setup_failed),
    " failed\n",
  ])
}

fn count(results: List(TestResult), wanted: Status) -> Int {
  count_loop(results, wanted, 0)
}

fn count_loop(results: List(TestResult), wanted: Status, n: Int) -> Int {
  case results {
    [] -> n
    [r, ..rest] ->
      case r.status == wanted {
        True -> count_loop(rest, wanted, n + 1)
        False -> count_loop(rest, wanted, n)
      }
  }
}
```

Then call it from your runner `main()`:

```gleam
import dream_test/runner
import gleam/io

pub fn main() {
  let results = runner.new([tests()]) |> runner.run()
  io.print(render_my_report(results))
}
```

#### Driving the progress reporter manually (advanced)

If you’re building a custom tool that already receives `ReporterEvent` values, you can reuse
the built-in progress renderer:

- `progress.handle_event(progress.new(), event)` returns `Option(String)`
- You decide where to write it, and when (or whether) to print it

This is intentionally **not** the common path; most users should attach progress via
`runner.progress_reporter(progress.new())`.

### Gherkin reporter (post-run, Cucumber-style)

If you’re using `dream_test/gherkin`, you can render results in Gherkin-friendly formatting.

```gleam
import dream_test/matchers.{succeed}
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{step}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import gleam/io

fn step_ok(_context) {
  Ok(succeed())
}

pub fn tests() {
  let steps = steps.new() |> step("everything is fine", step_ok)

  feature("Gherkin Reporting", steps, [
    scenario("A passing scenario", [
      given("everything is fine"),
      then("everything is fine"),
    ]),
  ])
}

pub fn main() {
  let results = runner.new([tests()]) |> runner.run()
  let _ = gherkin_reporter.report(results, io.print)
  Nil
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/gherkin_reporter.gleam)</sub>

### Choosing a reporter (a quick heuristic)

- **Local dev**: start with BDD output.
- **Big suites / noisy logs**: progress output.
- **Tooling / CI integration**: JSON output (and/or post-run formatting to write files).
- **Behavior specs**: use the Gherkin reporter when your suites are authored via `dream_test/gherkin`.

### What's Next?

- Go back to [Runner & execution model](07-runner-and-execution.md)
- Go back to [Documentation README](README.md)
- Continue to [Snapshot testing](09-snapshot-testing.md)
