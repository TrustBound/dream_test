# Measure line coverage and gate CI on it

Your tests pass. But which lines of your code did they run? Line coverage answers that: for each source file, how many executable lines ran, and which ones never did. Dream Test measures it in the same run as your tests, with no extra tool. This guide takes you from turning it on, to a minimum that fails CI when coverage drops, to exclusions with reasons, report files for other tools, and code that runs outside the test run.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which way to measure](#which-way-to-measure)
- [Step 1: Turn coverage on](#step-1-turn-coverage-on)
- [Step 2: Read the table](#step-2-read-the-table)
- [Step 3: Measure only in CI](#step-3-measure-only-in-ci)
- [Step 4: Fail the run below a minimum](#step-4-fail-the-run-below-a-minimum)
- [Step 5: Leave out code you don't test, and say why](#step-5-leave-out-code-you-dont-test-and-say-why)
- [Step 6: Shape the table](#step-6-shape-the-table)
- [Step 7: Write files for other tools](#step-7-write-files-for-other-tools)
- [Step 8: Measure a server that your tests start](#step-8-measure-a-server-that-your-tests-start)
- [Measure without the runner](#measure-without-the-runner)
- [When coverage fails](#when-coverage-fails)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Turn on coverage in your test `main`, and read the table it prints.
- Measure only in CI, from an environment variable.
- Set a minimum, and see the run fail when coverage is below it.
- Exclude generated code and debug helpers with a reason, and see the run pass.
- Ignore single lines, ranges and functions with comment markers.
- Write LCOV, JSON, Cobertura, Markdown and HTML files, and read the JSON summary.
- Merge the coverage of a server that your integration tests start.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

Dream Test counts lines with the native line counters of the BEAM. They need Erlang/OTP 27 or later with the JIT, which is the default on x86-64 and ARM64. Use Gleam 1.19 or later for exact line numbers: older versions map only the first line of each function to its source line, so other lines can show the wrong number in the `Missing` column, the LCOV file and the markers. When an older Gleam built a measured file, the table prints a warning that names the file. The warning doesn't fail the run.

The examples measure a small app in `src/app` with three modules: `cart.gleam`, which the tests cover, `generated/db.gleam`, generated code, and `internal/debug.gleam`, debug helpers. The outputs are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## Which way to measure

| Your situation | Use | Why |
|:---|:---|:---|
| Measure on every `gleam test` | `runner.coverage(config)` | Always on. The table prints after the results. |
| Measure only in CI, keep local runs fast | `runner.coverage_from_environment(config)` | On when `DREAM_TEST_COVERAGE` is `1` or `true`. |
| Code that runs in another BEAM, such as a server your tests start | `coverage.start` and `coverage.finish` in that BEAM, `coverage.merge_lcov` in the test run | Each BEAM measures itself, and the test run merges the files. |
| Code under another test runner, or a script | `coverage.start` and `coverage.finish` | Measures anything between the two calls. |

## Step 1: Turn coverage on

Coverage is off until you turn it on. One call in your test `main` does it:

### Turn on coverage <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/runner_coverage.gleam#L19-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

`coverage.new()` makes a config with the defaults: measure every module under `src`, and write an LCOV file to `build/coverage/lcov.info`. `coverage.show_missing()` adds a column with the lines that never ran. Here's a complete test module for the app, with coverage of `src/app` only:

### Tests of the cart, with coverage <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/guide_coverage_first.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import app/cart
import dream_test/coverage
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Cart", [
    it("totals an empty cart", fn() {
      cart.total([])
      |> should
      |> be_equal(0)
      |> or_fail_with("an empty cart should cost nothing")
    }),
    it("totals two prices", fn() {
      cart.total([250, 1000])
      |> should
      |> be_equal(1250)
      |> or_fail_with("the total should be the sum of the prices")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage(
    coverage.new()
    |> coverage.source_directory("src/app")
    |> coverage.show_missing(),
  )
  |> runner.exit_on_failure()
  |> runner.run()
}
```

`coverage.source_directory("src/app")` measures only that folder. The run prints the test report, then the coverage table, and the exit status is 0:

### The first coverage run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_coverage_first.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Cart
  ✓ totals an empty cart
  ✓ totals two prices

Summary: 2 run, 0 failed, 2 passed in 0ms

Coverage
File                          Lines  Cover   Missing
src/app/cart.gleam            3/3    100.0%
src/app/generated/db.gleam    0/1    0.0%    6
src/app/internal/debug.gleam  0/1    0.0%    6
Total                         3/5    60.0%
LCOV: build/coverage/lcov.info
```

The cart is fully covered: its 3 executable lines ran. The generated code and the debug helpers have one line each, and no test ran them, so the total is 3 of 5 lines, 60.0%.

## Step 2: Read the table

Here's a table from a bigger cart, with two lines no test runs:

### The coverage table <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/coverage_table_missing.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Coverage
File                Lines  Cover  Missing
src/app/cart.gleam  18/20  90.0%  12-13
Total               18/20  90.0%
LCOV: build/coverage/lcov.info
```

- `Lines` is the executable lines that ran, then all executable lines. Comments and blank lines don't count.
- `Cover` is the percent, rounded down to one decimal. A file at 99.99% shows `99.9%`, never `100.0%`.
- `Missing` lists the lines that never ran, with ranges for neighbors, such as `12-13`. Open the file at those lines, and you see what no test reached.
- `Total` adds up every measured file. The last line says where the LCOV file went.

## Step 3: Measure only in CI

Coverage makes a run a little slower. To measure only in CI, use `runner.coverage_from_environment` in place of `runner.coverage`:

### Coverage from the environment <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_environment.gleam#L24-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage_from_environment(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
```

Coverage then runs only when `DREAM_TEST_COVERAGE` is `1` or `true`:

### Run with coverage from the environment <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/scripts/examples.sh#L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
DREAM_TEST_COVERAGE=1 gleam test
```

When the variable isn't set, or is `0` or `false`, coverage is off. Any other value is a coverage error (`coverage.InvalidEnvironmentValue`), and the run fails, so a typo in CI can't turn coverage off by accident.

## Step 4: Fail the run below a minimum

A number nobody looks at doesn't stop coverage from sliding. A minimum does: below it, the run fails, and with `runner.exit_on_failure()` the exit status is 1, so CI goes red. There are two kinds:

### Set the minimums <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_minimum.gleam#L25-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.minimum_percent(80.0)
  |> coverage.minimum_percent_per_file(60.0)
}
```

`coverage.minimum_percent(80.0)` is the minimum for the total. `coverage.minimum_percent_per_file(60.0)` is the minimum for each file, so a well-tested module can't hide an untested one. The comparison uses the exact line counts, not the rounded percent.

Add a minimum of 90% to the app's coverage:

### A coverage gate of 90% <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/guide_coverage_gate.gleam#L17-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.source_directory("src/app")
  |> coverage.show_missing()
  |> coverage.minimum_percent(90.0)
}
```

The tests still pass and the table is the same as in Step 1, but the total is 60.0%, so the run fails with exit status 1 and writes this to the error output:

### The error of a total below the minimum <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_coverage_gate_error.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text

Coverage failed
  Coverage 60.0% is below the minimum 90.0% (needs 2 more lines).
  Reason: 3 of 5 executable lines ran, and the minimum needs 5.
  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).

Tests: 2 passed. Exit status 1, because coverage is below the minimum.
```

The error says what failed, why, and what to do. The last line sums up the run: every test passed, and the exit status is 1 because of coverage. Now decide: write tests for the missing lines, or, if the lines don't need tests, exclude them with a reason.

## Step 5: Leave out code you don't test, and say why

Generated code and debug helpers don't need tests, and they shouldn't count against your minimum. Exclude them by pattern, with a reason:

### Exclude files with a reason <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_exclusions.gleam#L28-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.exclude_with_reason("src/app/internal/**", "debug helpers")
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.require_exclusion_reasons()
  |> coverage.show_excluded()
}
```

- `coverage.exclude(pattern)` leaves out the files that match. `coverage.exclude_with_reason(pattern, reason)` also records why.
- `coverage.require_exclusion_reasons()` fails the run when a pattern or a marker has no reason, so every exclusion explains itself.
- An exclusion is never silent: a count line follows the total. `coverage.show_excluded()` adds an `Excluded` column with each reason.

### The table with exclusions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/coverage_table_excluded.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Coverage
File                        Lines  Cover  Excluded
src/app/cart.gleam          18/20  90.0%  40-44 (debug only), 71
src/app/generated/db.gleam  excluded: matches src/app/generated/** (generated code)
Total                       18/20  90.0%
Excluded: 1 file, 6 lines in 1 file
```

Do the same for the app. This config keeps the 90% minimum, and excludes the two folders:

### The gate with exclusions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/guide_coverage_excluded.gleam#L16-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.source_directory("src/app")
  |> coverage.show_missing()
  |> coverage.minimum_percent(90.0)
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.exclude_with_reason("src/app/internal/**", "debug helpers")
  |> coverage.show_excluded()
  |> coverage.json_path("build/coverage/guide_coverage.json")
}
```

Now the run passes, with exit status 0. Each excluded file says which pattern matched and why:

### The run with exclusions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_coverage_excluded.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Cart
  ✓ totals an empty cart
  ✓ totals two prices

Summary: 2 run, 0 failed, 2 passed in 0ms

Coverage
File                          Lines  Cover   Missing  Excluded
src/app/cart.gleam            3/3    100.0%
src/app/generated/db.gleam    excluded: matches src/app/generated/** (generated code)
src/app/internal/debug.gleam  excluded: matches src/app/internal/** (debug helpers)
Total                         3/3    100.0%
Excluded: 2 files
LCOV: build/coverage/lcov.info
```

To leave out part of a file, put a marker comment on its own line. Text after a marker is its reason. In `.erl` files, write the marker after `%` or `%%`.

### Ignore a line, a range and a function <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_markers.gleam#L17-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Step 6: Shape the table

On a big project, the table is long. These settings make it easier to read:

### Table settings <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_table.gleam#L31-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
- `coverage.sort_by_coverage()`: the lowest coverage comes first, where you'll look.
- `coverage.hide_complete()`: files at 100% aren't shown. The total still counts them.

## Step 7: Write files for other tools

Coverage writes LCOV unless you set `coverage.no_lcov()`. It can also write JSON, Cobertura XML (for GitLab, Jenkins and Azure DevOps), Markdown (for `$GITHUB_STEP_SUMMARY` or a pull request comment) and HTML (an index page and one page for each source file, or one combined page with the same table and source):

### Write every format <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_outputs.gleam#L25-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

- `coverage.html_file` writes one self-contained page: the table, then the source of each file, with each file name linked to its source. Attach it to a CI run, or send it as one file. You can turn on `html_path`, `html_file` or both.
- Before it writes the HTML pages, coverage deletes the `files` folder in the HTML directory, so no page of a removed source file stays. It deletes only that folder.
- When a file can't be written, coverage fails with a `Coverage failed` message that names the format and the path.

The JSON summary is the file to read from a script, such as the badge step of [Publish a coverage badge from your own CI](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage-badge.md). The run with exclusions in Step 5 wrote this one:

### The JSON summary of the run with exclusions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_coverage_json.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
{"version":1,"files":[{"path":"src/app/cart.gleam","lines_hit":3,"lines_total":3,"percent":100.0,"missing":[],"ignored":[]}],"excluded_files":[{"path":"src/app/generated/db.gleam","pattern":"src/app/generated/**","reason":"generated code"},{"path":"src/app/internal/debug.gleam","pattern":"src/app/internal/**","reason":"debug helpers"}],"total":{"lines_hit":3,"lines_total":3,"percent":100.0},"minimum_percent":90.0,"minimum_percent_per_file":null}
```

The keys are always in this order. A new key is only added at the end of an object, and `version` changes when a key changes meaning:

| Key | What it holds |
|:---|:---|
| `version` | The schema version, `1`. |
| `files` | One object for each measured file, sorted by path: `path` (from the project folder), `lines_hit`, `lines_total`, `percent` (rounded down, `null` for a file with no executable lines), `missing` (ranges of lines that didn't run, each with `first` and `last`) and `ignored` (ranges that markers ignored, each with `first`, `last` and `reason`). |
| `excluded_files` | One object for each excluded file: `path`, the `pattern` that matched, and the `reason`, or `null` when there's none. |
| `total` | `lines_hit`, `lines_total` and `percent` of all measured files. |
| `minimum_percent` | The value of `coverage.minimum_percent`, or `null`. |
| `minimum_percent_per_file` | The value of `coverage.minimum_percent_per_file`, or `null`. |

Excluded files and ignored lines never count in `lines_hit` or `lines_total`.

## Step 8: Measure a server that your tests start

Integration tests often start the application as its own OS process, in its own BEAM. Code there isn't in the test run. So the server measures itself with `coverage.start` and `coverage.finish`, and writes an LCOV file when it stops. The test run adds that file with `coverage.merge_lcov`:

### A server that measures itself <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_server.gleam#L10-L47"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
  |> runner.exit_on_failure()
  |> runner.run()
}
```

- Start the server from the project root, so the paths in its LCOV file are project paths.
- Stop the server through its own stop path. A killed BEAM doesn't run `finish`, and writes no file.
- Delete the old file before the server starts, as the `before_all` hook does here. Then a missing file fails the run with `NoLcovFilesMatched`, and old counts are never merged.
- Give each server its own file name.

## Measure without the runner

`coverage.start` and `coverage.finish` measure any code, for example under another test runner. `dream_test/reporters/coverage` renders the table, and `dream_test/coverage/report` reads the numbers:

### Measure without the runner <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_start_finish.gleam#L19-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

`coverage.check_minimum` and `coverage.check_minimum_per_file` apply the minimums to a report. A per-file failure is `Error(FilesBelowMinimumPercent(minimum_percent:, files:))`, and `below_minimum_source_path`, `below_minimum_hit`, `below_minimum_total` and `below_minimum_lines_needed` read each file in it. In `dream_test/coverage/report`, `files` gives the measured files, `source_path`, `hit_line_count`, `executable_line_count` and `missed_ranges` read one file, and `total_hit_line_count` and `total_executable_line_count` read the total. `excluded_files` and `ignored_ranges` give what the exclusions and markers left out. The modules `coverage/json_summary`, `coverage/cobertura`, `coverage/markdown` and `coverage/html` render each file format from a report, and `reporters/coverage.render_failure` renders a coverage error, for a tool of your own.

## When coverage fails

Every coverage error fails the run, so with `runner.exit_on_failure()` the exit status is 1. The runner prints the error under `Coverage failed`, with what failed, the reason and the fix, as in Step 4. The ones you'll meet:

| You see | It means |
|:---|:---|
| `Coverage 60.0% is below the minimum 90.0%` | The total, or a file with `minimum_percent_per_file`, is below its minimum. |
| An invalid `DREAM_TEST_COVERAGE` value | The variable is set to something other than `1`, `true`, `0` or `false`. |
| A start marker without an end marker | A `coverage:ignore-start` has no `coverage:ignore-end`, or a `coverage:ignore-function` has no function after it. The error names the file and the line. |
| A file that can't be written | An output path is in a folder you can't write. The error names the format and the path. |
| `No LCOV files match` | A `merge_lcov` pattern found no file: the server didn't stop cleanly, or wrote somewhere else. |

More than one coverage run can measure in one BEAM, but a module can be in only one run at a time. `runner.silent()` drops the coverage table, but still writes a coverage error to the standard error stream.

## Test your code

Your coverage config decides whether CI fails, so a wrong value in it costs you a gate you think you have. The config is a value, and `dream_test/coverage` has a reader for each setting: `minimum`, `minimum_per_file`, `shows_missing`, `shows_excluded`, `uses_color`, `sorts_by_coverage`, `hides_complete` and `lcov_file`. The gate module checks its own minimum:

### Check the coverage gate <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/guide_coverage_gate.gleam#L24-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() {
  describe("The coverage gate", [
    it("sets a minimum of 90%", fn() {
      // Act
      let minimum = coverage.minimum(coverage_config())

      // Assert
      minimum
      |> should
      |> be_equal(Some(90.0))
      |> or_fail_with("the minimum should be 90.0")
    }),
  ])
}
```

To check the gate end to end, run the `main` in CI on purpose with a minimum you know is too high, as the run in Step 4 does, and see it fail.

## Common pitfalls

**Coverage on, but no gate.** *Symptom:* the total slides from 90% to 70% over a year, and nobody noticed. *Fix:* set `coverage.minimum_percent`, and `runner.exit_on_failure()` in `main`.

**An exclusion without a reason.** *Symptom:* a reviewer can't tell why a folder is left out. *Fix:* use `exclude_with_reason`, and add `require_exclusion_reasons()` so the run enforces it.

**Coverage off in CI.** *Symptom:* no table in the CI log. *Fix:* with `coverage_from_environment`, set `DREAM_TEST_COVERAGE: "1"` on the test step.

**A server killed at the end of the tests.** *Symptom:* `No LCOV files match`, or old numbers from an earlier run. *Fix:* stop the server through its own stop path so it runs `finish`, and delete its old file before it starts.

**Wrong line numbers in `Missing`.** *Symptom:* the missing lines point at comments or blank lines. *Fix:* build with Gleam 1.19 or later. The table warns about each file an older Gleam built.

## Where to go next

- [Publish a coverage badge from your own CI](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage-badge.md): show the total in your README.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): the exit status and CI.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/coverage.html): `dream_test/coverage`, `coverage/report` and the formats.
