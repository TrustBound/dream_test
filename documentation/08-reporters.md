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
