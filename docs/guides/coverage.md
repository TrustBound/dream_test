## Coverage

Dream Test measures line coverage with the native line counters of the BEAM. They need Erlang/OTP 27 or later with the JIT (the default on x86-64 and ARM64). Coverage is opt-in. Turn it on in your test `main`:

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


After the results, the runner prints a table and writes an LCOV file to `build/coverage/lcov.info`:

### The coverage table <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/coverage_table_missing.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Coverage
File                Lines  Cover  Missing
src/app/cart.gleam  18/20  90.0%  12-13
Total               18/20  90.0%
LCOV: build/coverage/lcov.info
```

`coverage.show_missing()` adds the `Missing` column. `coverage.source_directory("src/app")` measures only one folder. The default is `src`.

### Turn coverage on from the environment

Use `runner.coverage_from_environment` in place of `runner.coverage`. Coverage then runs only when `DREAM_TEST_COVERAGE` is `1` or `true`, for example in CI. When the variable is not set, or is `0` or `false`, coverage is off. Any other value is a coverage error (`coverage.InvalidEnvironmentValue`), and the run fails:

#### Coverage from the environment <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_environment.gleam#L24-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.coverage_from_environment(coverage_config())
  |> runner.exit_on_failure()
  |> runner.run()
}
```

#### Run with coverage from the environment <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/scripts/examples.sh#L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
DREAM_TEST_COVERAGE=1 gleam test
```

### Minimum coverage

`coverage.minimum_percent` fails the run when the total is below the minimum. `coverage.minimum_percent_per_file` fails the run when one file is below its minimum. With `runner.exit_on_failure()`, the exit status is then 1.

#### Set the minimums <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_minimum.gleam#L25-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.minimum_percent(80.0)
  |> coverage.minimum_percent_per_file(60.0)
}
```


### Exclude files

`coverage.exclude` removes files that match a pattern, for example generated code. `coverage.exclude_with_reason` also records why. `coverage.require_exclusion_reasons()` fails the run when a pattern or a marker has no reason. An exclusion is never silent: a count line follows the total. `coverage.show_excluded()` adds an `Excluded` column with each reason.

#### Exclude files with a reason <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_exclusions.gleam#L28-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn coverage_config() {
  coverage.new()
  |> coverage.exclude_with_reason("src/app/internal/**", "debug helpers")
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.require_exclusion_reasons()
  |> coverage.show_excluded()
}
```


#### The table with exclusions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/coverage_table_excluded.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### Ignore a line, a range and a function <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_markers.gleam#L17-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### Table settings <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_table.gleam#L31-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### Write every format <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_outputs.gleam#L25-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

#### A server that measures itself <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_server.gleam#L10-L47"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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
- Stop the server through its own stop path. A killed BEAM does not run `finish` and writes no file.
- Delete the old file before the server starts. Then a missing file fails the run with `NoLcovFilesMatched`, and old counts are never merged.
- Give each server its own file name.

### Without the runner

`coverage.start` and `coverage.finish` measure any code, for example under another test runner. `dream_test/reporters/coverage` renders the table, and `dream_test/coverage/report` reads the numbers:

#### Measure without the runner <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/coverage/coverage_start_finish.gleam#L19-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

Every coverage error fails the run, so with `runner.exit_on_failure()` the exit status is 1. The runner prints the error under `Coverage failed`, with what failed, the reason and the fix. More than one coverage run can measure in one BEAM instance, but a module can be in only one run at a time.

### Coverage badge

To show a live coverage badge in your README, see [Coverage badge on GitHub](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage-badge.md). Your own CI writes the badge file to a `badges` branch, and shields.io draws it. No outside coverage service is needed.

### Line accuracy (Gleam 1.19)

Use Gleam 1.19 or later for exact line numbers. Older Gleam versions map only the first line of each function to its source line, so other lines can show the wrong number in the `Missing` column, the LCOV file and the markers. When an older Gleam built a measured file, the table prints a warning that names the file. The warning does not fail the run.

### What's Next?

- Go back to [Utilities](https://github.com/TrustBound/dream_test/blob/main/docs/guides/utilities.md)
- Go back to [Documentation README](https://github.com/TrustBound/dream_test/blob/main/docs/guides/index.md)
- Continue to [Coverage badge on GitHub](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage-badge.md)
