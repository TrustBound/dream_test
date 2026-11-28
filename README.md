<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>Testing for Gleam, with coverage and recorded tests built in.</strong></p>

  <a href="https://hex.pm/packages/dream_test"><img src="https://img.shields.io/hexpm/v/dream_test?color=8e4bff&label=hex" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/dream_test/"><img src="https://img.shields.io/badge/docs-hexdocs-8e4bff" alt="Documentation"></a>
  <a href="https://github.com/TrustBound/dream_test/actions/workflows/ci.yml?query=branch%3Amain"><img src="https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/TrustBound/dream_test/badges/coverage.json" alt="Coverage"></a>
  <a href="https://github.com/TrustBound/dream_test/blob/main/LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License"></a>
</div>

<br>

## What is Dream Test?

Dream Test is a testing framework for Gleam that measures line coverage and plays back recorded HTTP calls and database queries without extra tools. Turn coverage on with one line in your test `main`, and the run prints a per-file table of the lines your tests never ran. Record an API client or a PostgreSQL query one time, and every later run needs no network and no database. Unit tests, Gherkin features and snapshots all run in the same runner.

## Features

### Built-in coverage

One line in your test `main` turns it on. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md).

| Feature                        | What you get                                                             |
| ------------------------------ | ------------------------------------------------------------------------ |
| 📈 **Line coverage**           | A per-file table after your results, with the lines your tests never ran |
| 🎯 **Minimums**                | Fail the run below a total or per-file percent                           |
| 🙈 **Exclusions with reasons** | Skip files, lines, blocks or whole functions, and say why in the report  |
| 📤 **Every format**            | LCOV, JSON, Cobertura XML, Markdown, and HTML with annotated source      |
| 🔀 **Merged runs**             | Combine coverage from servers and other BEAM instances into one report   |
| 🧭 **Exact lines**             | Every line maps to its Gleam source line on Gleam 1.19+                  |

### Recorded tests

Record HTTP calls and database queries one time, then play them back in each run. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md).

| Feature                       | What you get                                                                                                                                                                        |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🎙️ **Recorded HTTP calls**    | Tests of an API client with no network, from files that `dream_http_client` writes                                                                                                  |
| 🐘 **Recorded queries**       | Tests of database code with no PostgreSQL, from files that `dream_postgres` writes. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-queries.md) |
| 🔁 **One command to refresh** | `RECORDER_MODE=record gleam test` records, and `gleam test` plays back                                                                                                              |
| 🚫 **Clear misses**           | A request or a query with no recording fails, and the report shows the nearest recording and what differs                                                                           |

### Write tests

Unit tests, Gherkin features and snapshots, with setup you share. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md).

| Feature                 | What you get                                                                                                                                                    |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 🧪 **Unit tests**       | `describe`, `group` and `it` to organize tests                                                                                                                  |
| 🥒 **Gherkin specs**    | `.feature` files or the inline Gleam DSL. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md)                            |
| 📸 **Snapshot testing** | Lock in complex output without manual assertions. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/snapshot-testing.md)               |
| 🔄 **Lifecycle hooks**  | `before_all`, `after_all`, `before_each` and `after_each`. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md)       |
| 🔗 **Shared context**   | Pass a typed value to every test, and start a resource once. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md) |
| 🏷️ **Tags**             | Filter and organize test runs                                                                                                                                   |

### Check values

Assertions that read as a pipe. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md).

| Feature                     | What you get                                                                                                                   |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| ⛓️ **Pipe-first assertions** | Matchers that chain and compose                                                                                                |
| 📦 **Built-in matchers**    | Equality, booleans, options, results, lists, strings and comparisons                                                           |
| 🎁 **Unwrapping matchers**  | Option and Result matchers that unwrap, so you keep asserting on what is inside                                                |
| 🛠️ **Custom matchers**      | Write your own for your domain. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/custom-matchers.md) |

### Run and report

A fast, isolated run, and output you choose. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md).

| Feature                   | What you get                                                                                                                             |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| ⚡ **Parallel execution** | Configurable concurrency for fast runs                                                                                                   |
| 🛡️ **Isolation**          | Crashes and timeouts do not break the run                                                                                                |
| ⏱️ **Timeouts**            | A default timeout for each test and hook, and one for each group of suites                                                               |
| 🎯 **Run one test**       | Each failed test prints `gleam test -- --only "<path>"`, the command that runs only that test                                            |
| 🚨 **Exit status for CI** | Exit status 1 when the run fails, after every test ran and all output is written                                                         |
| 📊 **Reporters**          | BDD, progress and JSON reporters, and your own. [Read more](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md) |

## A Quick Example

### A first test module <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/getting_started_first_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a> <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/docs/guides/getting-started.md#a-first-test-module-"><img align="right" alt="Guide: Write and run your first test" title="Guide: Write and run your first test" src="https://img.shields.io/badge/%F0%9F%93%96_read-guide-blue.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, be_ok, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, it}
import snippets.{add, divide}

pub fn tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should
      |> be_equal(5)
      |> or_fail_with("2 + 3 should be 5")
    }),
    it("divides two numbers", fn() {
      divide(10, 2)
      |> should
      |> be_ok()
      |> be_equal(5)
      |> or_fail_with("10 / 2 should be 5")
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

**Run this:** `gleam test` → the Calculator suite runs in the BDD report with both tests passing, and the exit status is 0.

## Installation

```sh
gleam add --dev dream_test
```

## Guides

- [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md): from an empty test folder to a green run, a red run you can read, and a CI job that fails when a test fails.
- [Organize tests with groups, skips and tags](https://github.com/TrustBound/dream_test/blob/main/docs/guides/writing-tests.md): groups, pending and skipped tests, tags, and filters that run part of a suite.
- [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md): the assertion pipeline, which matcher fits which value, and what each failure prints.
- [Write your own matcher](https://github.com/TrustBound/dream_test/blob/main/docs/guides/custom-matchers.md): a matcher for your own types, its failure output, and tests for it.
- [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md): `before_all`, `before_each`, `after_each`, `after_all` and runner hooks, and what the report shows when one fails or hangs.
- [Share a context between tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/context-aware-tests.md): pass a typed value to every test, and start a resource once with `context.setup`.
- [Choose and read the test output](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md): the BDD, progress and JSON reporters, a reporter of your own for CI, and reporter crashes.
- [Lock down large output with snapshots](https://github.com/TrustBound/dream_test/blob/main/docs/guides/snapshot-testing.md): snapshot files, a changed snapshot, and how to update one.
- [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md): features in Gleam and in `.feature` files, Rules and Examples, a shared server, and tests for your steps.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): concurrency, timeouts, suites with their own settings, and every case that gives exit status 1.
- [Measure line coverage and gate CI on it](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md): the coverage table, minimums, exclusions with reasons, report files and coverage from servers.
- [Publish a coverage badge from your own CI](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage-badge.md): a live badge from your own GitHub Actions workflow, with no outside service.
- [Mock at the system boundary](https://github.com/TrustBound/dream_test/blob/main/docs/guides/mock-at-the-boundary.md): why the tests keep the real code and change only what answers at the dependency boundary, and what a recording proves.
- [Test HTTP calls with recordings](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-http.md): record the calls of an API client one time, play them back in CI with no network, and keep the token out of the files.
- [Test database code with recorded queries](https://github.com/TrustBound/dream_test/blob/main/docs/guides/recorded-queries.md): record PostgreSQL queries one time, play them back with no database, and test a transaction.
- [Upgrade from Dream Test 2.x to 3.0.0](https://github.com/TrustBound/dream_test/blob/main/docs/guides/upgrading-to-3.md): every breaking change, with the 2.x code and the 3.0.0 code.
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md): every matcher, the runner settings, the rules of hook processes, the Gherkin rules and the helper modules.
- [API reference](https://hexdocs.pm/dream_test): every module and function on HexDocs

## Requirements

- Gleam 1.19.2 or newer (the version CI uses). Gleam 1.19 or later gives exact line numbers in coverage.
- Erlang/OTP 28 in CI. Dream Test runs on the BEAM only. Coverage needs Erlang/OTP 27 or later with the JIT.

## About Dream

[Dream](https://github.com/TrustBound/dream) is a collection of Gleam packages for building production web applications. Each package implements its standards completely, shares the same naming and style as the others, and is fully tested. TrustBound builds Dream for its own production systems and shares it in the hope that it helps yours.

Dream Test works on its own. You don't need the rest of Dream to use it.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE.md](LICENSE.md)
