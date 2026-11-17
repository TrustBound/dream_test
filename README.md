<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>Feature-rich unit and integration testing for Gleam.</strong></p>

  <a href="https://hex.pm/packages/dream_test">
    <img src="https://img.shields.io/hexpm/v/dream_test?color=8e4bff&label=hex" alt="Hex.pm">
  </a>
  <a href="https://hexdocs.pm/dream_test/">
    <img src="https://img.shields.io/badge/docs-hexdocs-8e4bff" alt="Documentation">
  </a>
  <a href="https://github.com/TrustBound/dream_test/blob/main/LICENSE.md">
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  </a>
</div>

<br>

## Install Dream Test

```sh
gleam add --dev dream_test
```

Current version: `2.1.3`

## Why Dream Test?

Rapid application development needs testing tools that scale and support the growing needs of the application without slowing down progress. Dream test was designed to help engineers write expressive unit and integration tests for their applications using the tools and techniques they know from other ecosystems; adapted properly to gleam and the beam.

### Test Styles

| Feature                 | What you get                                     |
| ----------------------- | ------------------------------------------------ |
| 🧪 **Unit tests**       | `describe`/`group`/`it` for organizing tests     |
| 🥒 **Gherkin specs**    | `.feature` files or inline Gleam DSL             |
| 📸 **Snapshot testing** | Lock in complex output without manual assertions |

### Assertions

| Feature                      | What you get                                                      |
| ---------------------------- | ----------------------------------------------------------------- |
| ⛓️ **Pipe-first assertions** | Matchers that chain and compose                                   |
| 📦 **Built-in matchers**     | Equality, booleans, options, results, lists, strings, comparisons |
| 🎁 **Unwrapping matchers**   | Option/Result matchers that unwrap for continued assertion        |
| 🛠️ **Custom matchers**       | Write your own for your domain                                    |

### Test Organization

| Feature                    | What you get                                           |
| -------------------------- | ------------------------------------------------------ |
| 🔄 **Lifecycle hooks**     | `before_all`, `after_all`, `before_each`, `after_each` |
| 🔗 **Context-aware tests** | Shared setup across tests with `unit_context`          |
| 🏷️ **Tags**                | Filter and organize test runs                          |

### Execution

| Feature                                | What you get                                                                                              |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| ⚡ **Parallel execution**              | Configurable concurrency for fast runs                                                                    |
| 🛡️ **Isolation**                       | Crashes and timeouts don't break the run                                                                  |
| ⏱️ **Timeouts**                        | Per-test timeout control                                                                                  |
| 🔍 **Test discovery**                  | Find tests from file paths                                                                                |
| 🚨 **Exit-on-failure**                 | Fail fast for CI                                                                                          |
| 🪝 **Runner hooks**                    | Runner-level hooks for per-test/per-suite/per-run setup and teardown                                       |
| 🧩 **Suite-specific execution config** | Run some suites sequential/with custom timeouts in the same runner (`runner.add_suites_with_config(...)`) |

### Reporting

| Feature                      | What you get                                         |
| ---------------------------- | ---------------------------------------------------- |
| 📝 **BDD results reporter**  | Human-readable, hierarchical output (printed at end) |
| 📊 **Progress reporter**     | Live single-line progress bar during the run         |
| 📋 **JSON results reporter** | Machine-readable JSON (printed at end)               |
| 🌿 **Gherkin formatting**    | Dedicated output for feature tests                   |
| 📈 **Coverage**              | Opt-in line coverage, minimums, LCOV, HTML           |

Dream Test splits reporting into:

- **Progress** (during the run): `runner.progress_reporter(progress.new())`
- **Results** (after the run): `runner.results_reporters([bdd.new(), json.new(), ...])`

## Full Usage Guide

1. [Installation](documentation/01-installation.md)
2. [Quick Start](documentation/02-quick-start.md)
3. [Writing Tests](documentation/03-writing-tests.md)
4. [Context-Aware Tests](documentation/04-context-aware-tests.md)
5. [Assertions & Matchers](documentation/05-assertions-and-matchers.md)
6. [Lifecycle Hooks](documentation/06-lifecycle-hooks.md)
7. [Runner & Execution](documentation/07-runner-and-execution.md) — includes runner hooks
8. [Reporters](documentation/08-reporters.md)
9. [Snapshot Testing](documentation/09-snapshot-testing.md)
10. [Gherkin BDD](documentation/10-gherkin-bdd.md)
11. [Utilities](documentation/11-utilities.md)

## Unit Tests

### A unit test file <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/readme/unit_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/string

pub fn tests() {
  describe("String utilities", [
    it("trims whitespace", fn() {
      "  hello  "
      |> string.trim()
      |> should
      |> be_equal("hello")
      |> or_fail_with("Should remove surrounding whitespace")
    }),
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

<sub>📖 [Guide](documentation/02-quick-start.md)</sub>

## Gherkin Integration Tests

### The feature file <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/features/shopping_cart.feature"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gherkin
Feature: Shopping Cart
  Scenario: Adding items
    Given I have 3 items in my cart
    When I add 2 more items
    Then I should have 5 items total
```

### The steps for the feature file <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/readme/gherkin_file.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

fn step_have_items(context: StepContext) {
  put(context.world, "cart", get_int(context.captures, 0) |> result.unwrap(0))
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  put(
    context.world,
    "cart",
    current + { get_int(context.captures, 0) |> result.unwrap(0) },
  )
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(get_int(context.captures, 0) |> result.unwrap(0))
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items in my cart", step_have_items)
    |> step("I add {int} more items", step_add_items)
    |> step("I should have {int} items total", step_verify_count)

  let assert Ok(feature) =
    parser.parse_file("test/features/shopping_cart.feature")
  to_test_suite(FeatureConfig(feature: feature, step_registry: steps))
}
```

<sub>📖 [Guide](documentation/10-gherkin-bdd.md)</sub>

## Gherkin Syntax in Gleam

### A feature in Gleam <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/readme/gherkin_inline.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import gleam/result

pub fn tests() {
  let steps =
    steps.new()
    |> step("I have {int} items", fn(ctx: StepContext) {
      put(ctx.world, "cart", get_int(ctx.captures, 0) |> result.unwrap(0))
      Ok(succeed())
    })
    |> step("I add {int} more", fn(ctx: StepContext) {
      let current = get_or(ctx.world, "cart", 0)
      put(
        ctx.world,
        "cart",
        current + { get_int(ctx.captures, 0) |> result.unwrap(0) },
      )
      Ok(succeed())
    })
    |> step("I should have {int} items", fn(ctx: StepContext) {
      get_or(ctx.world, "cart", 0)
      |> should
      |> be_equal(get_int(ctx.captures, 0) |> result.unwrap(0))
      |> or_fail_with("Cart count mismatch")
    })

  feature("Shopping Cart", steps, [
    scenario("Adding items", [
      given("I have 3 items"),
      when("I add 2 more"),
      then("I should have 5 items"),
    ]),
  ])
}
```

<sub>📖 [Guide](documentation/10-gherkin-bdd.md)</sub>

## Coverage

Dream Test measures line coverage with the BEAM `cover` tool. Coverage is opt-in. Turn it on in your test `main`:

### Turn on coverage <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/runner_coverage.gleam#L19-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.show_missing()
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
```


After the results, the runner prints a table and writes an LCOV file to `build/coverage/lcov.info`:

### The coverage table <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/readme/coverage_output.gleam#L73-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Coverage
File                Lines  Cover  Missing
src/app/cart.gleam  18/20  90.0%  12-13
Total               18/20  90.0%
LCOV: build/coverage/lcov.info
```

`coverage.show_missing()` adds the `Missing` column. `coverage.source_directory("src/app")` measures only one folder. The default is `src`.

### Turn coverage on from the environment

Use `runner.coverage_from_environment` in place of `runner.coverage`. Coverage then runs only when `DREAM_TEST_COVERAGE` is `1` or `true`, for example in CI:

#### Coverage from the environment <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_environment.gleam#L24-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage_from_environment(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
```


```sh
DREAM_TEST_COVERAGE=1 gleam test
```

### Minimum coverage

`coverage.minimum_percent` fails the run when the total is below the minimum. `coverage.minimum_percent_per_file` fails the run when one file is below its minimum. With `runner.exit_on_failure()`, the exit status is then 1.

#### Set the minimums <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_minimum.gleam#L25-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.minimum_percent(80.0)
  |> coverage.minimum_percent_per_file(60.0)
}
```


### Exclude files

`coverage.exclude` removes files that match a pattern, for example generated code. `coverage.exclude_with_reason` also records why. `coverage.require_exclusion_reasons()` fails the run when a pattern or a marker has no reason. An exclusion is never silent: a count line follows the total. `coverage.show_excluded()` adds an `Excluded` column with each reason.

#### Exclude files with a reason <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_exclusions.gleam#L17-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.exclude("src/app/internal/**")
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.require_exclusion_reasons()
  |> coverage.show_excluded()
}
```


#### The table with exclusions <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/readme/coverage_output.gleam#L88-L102"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Coverage
File                        Lines  Cover  Excluded
src/app/cart.gleam          18/20  90.0%  40-44 (debug only), 71
src/app/generated/db.gleam  excluded: matches src/app/generated/** (generated code)
Total                       18/20  90.0%
Excluded: 1 file, 6 lines in 1 file
```

### Ignore lines with markers

Put each marker on its own line. Text after a marker is its reason. In `.erl` files, write the marker after `%` or `%%`.

#### Ignore a line, a range and a function <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_markers.gleam#L17-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn log(message: String) -> Nil {
  // coverage:ignore
  io.println(message)
}

// coverage:ignore-start debug helpers
pub fn dump(value: a) -> a {
  echo value
}

// coverage:ignore-end

// coverage:ignore-function only old callers use this
/// Converts the old record format.
pub fn convert_legacy(record: String) -> String {
  string.replace(record, ";", ",")
}
```


- `coverage:ignore` ignores the next line that holds code.
- `coverage:ignore-start` and `coverage:ignore-end` ignore every line between them.
- `coverage:ignore-function` ignores the function after it. Doc comments and attributes can be between the marker and `fn`.
- A start marker without an end marker, or a function marker with no function after it, is an error that names the file and the line.

### Table options

#### Table settings <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_table.gleam#L31-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.show_missing()
  |> coverage.color()
  |> coverage.sort_by_coverage()
  |> coverage.hide_complete()
}
```


- `coverage.color()`: the `Cover` cell is green at 100%, red below the minimum and yellow between them.
- `coverage.sort_by_coverage()`: the lowest coverage comes first.
- `coverage.hide_complete()`: files at 100% are not shown. The total still counts them.

### Output files

Coverage writes LCOV unless you set `coverage.no_lcov()`. It can also write JSON, Cobertura XML (for GitLab, Jenkins and Azure DevOps), Markdown (for `$GITHUB_STEP_SUMMARY` or a pull request comment) and HTML (an index page and one page for each source file, or one combined page with the same table and source):

#### Write every format <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_outputs.gleam#L25-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.lcov_path("build/coverage/app.info")
  |> coverage.json_path("build/coverage/coverage.json")
  |> coverage.cobertura_path("build/coverage/cobertura.xml")
  |> coverage.markdown_path("build/coverage/coverage.md")
  |> coverage.html_path("build/coverage/html")
  |> coverage.html_file("build/coverage/all.html")
}
```


When a file cannot be written, coverage fails with a `Coverage failed` message that names the format and the path.

Before it writes the HTML pages, coverage deletes the `files` folder in the HTML directory, so no page of a removed source file stays. It deletes only that folder. Other files in the HTML directory stay.

`coverage.html_file` writes one self-contained page: the table, then the source of each file, with each file name linked to its source. Attach it to a CI run, or send it as one file. You can turn on `html_path`, `html_file` or both.

### Coverage from a server

Code in another BEAM instance, for example an application server that integration tests start as an OS process, is not in the test run. The server measures itself with `coverage.start` and `coverage.finish` and writes an LCOV file when it stops. The test run adds that file with `coverage.merge_lcov`:

#### A server that measures itself <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_server.gleam#L10-L46"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// The server: it measures itself and writes an LCOV file when it stops.

pub fn server_main() {
  let config =
    coverage.new()
    |> coverage.lcov_path("build/coverage/servers/app.info")
  let assert Ok(session) = coverage.start(config)
  serve_until_stop_requested()
  let assert Ok(_) = coverage.finish(session)
}

fn serve_until_stop_requested() -> Nil {
  io.println("Serving until a stop request comes")
}

// The test run: it starts the server, stops it, and merges its LCOV file.

pub fn app_tests() {
  describe("app", [
    before_all(fn() {
      file.delete("build/coverage/servers/app.info")
      |> result.map_error(file.error_to_string)
    }),
    before_all(start_server),
    after_all(stop_server_and_wait_for_exit),
    it("serves the home page", get_home_page),
  ])
}

pub fn main() {
  runner.new([app_tests()])
  |> runner.coverage(
    coverage.new()
    |> coverage.merge_lcov("build/coverage/servers/*.info"),
  )
  |> runner.run()
}
```


- Start the server from the project root, so the paths in its LCOV file are project paths.
- Stop the server through its own stop path. A killed BEAM does not run `finish` and writes no file.
- Delete the old file before the server starts. Then a missing file fails the run with `NoLcovFilesMatched`, and old counts are never merged.
- Give each server its own file name.

### Without the runner

`coverage.start` and `coverage.finish` measure any code, for example under another test runner. `dream_test/reporters/coverage` renders the table, and `dream_test/coverage/report` reads the numbers:

#### Measure without the runner <a href="https://github.com/TrustBound/dream_test/blob/2.2.0/examples/snippets/test/snippets/coverage/coverage_start_finish.gleam#L18-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_table() -> String {
  let config =
    coverage.new()
    |> coverage.no_lcov()
  let assert Ok(session) = coverage.start(config)
  let _sum = snippets.add(1, 2)
  let assert Ok(coverage_report) = coverage.finish(session)
  coverage_reporter.render(report: coverage_report, config: config)
}
```


`coverage.check_minimum` and `coverage.check_minimum_per_file` apply the minimums to a report.

### Errors

Every coverage error fails the run. The runner prints the error under `Coverage failed`, with what failed, the reason and the fix. Coverage measures one run per BEAM instance.

### Line accuracy (Gleam 1.19)

Use Gleam 1.19 or later for exact line numbers. Older Gleam versions map only the first line of each function to its source line, so other lines can show the wrong number in the `Missing` column, the LCOV file and the markers. When an older Gleam built a measured file, the table prints a warning that names the file. The warning does not fail the run.


## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

MIT — see [LICENSE.md](LICENSE.md)

---

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a> ❤️</sub>
</div>
