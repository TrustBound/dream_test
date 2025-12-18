## Reporters (BDD, JSON, Progress, Gherkin)

### Mental model

Dream Test has two reporting styles:

- **During the run (event-driven)**: `runner.reporter(reporter.*(...))`
- **After the run (post-run formatting)**: take `List(TestResult)` and format/report later

Dream Test supports two “reporting modes”:

- **Event-driven reporters**: stream output while tests run (best for humans + CI logs).
- **Post-run formatting/reporting**: take `List(TestResult)` and render later (best for tooling, saving artifacts, custom output).

### BDD reporter (event-driven)

This is the default “human” output: nested suite names, checkmarks, and failures.

```gleam
import dream_test/assertions/should.{succeed}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("BDD reporter", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/bdd_reporter.gleam)</sub>

### JSON reporter (event-driven)

Use JSON output for CI/CD integration and tooling (parsing, dashboards, artifact uploads).

```gleam
import dream_test/assertions/should.{succeed}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("JSON Reporter", [
    it("outputs JSON format", fn() {
      // The json.report function outputs machine-readable JSON
      // while bdd.report outputs human-readable text
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
  |> runner.reporter(reporter.json(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/reporters/json_reporter.gleam)</sub>

### Progress reporter (event-driven)

Use progress output when you want compact logs, especially for large suites.

```gleam
import dream_test/assertions/should.{succeed}
import dream_test/reporter
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io

pub fn tests() {
  describe("Progress reporter", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporter.progress(io.print))
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
import dream_test/assertions/should.{
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
      |> should()
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
import dream_test/assertions/should.{succeed}
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{new_registry, step}
import dream_test/reporters/gherkin as gherkin_reporter
import dream_test/runner
import gleam/io

fn step_ok(_context) {
  Ok(succeed())
}

pub fn tests() {
  let steps = new_registry() |> step("everything is fine", step_ok)

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


