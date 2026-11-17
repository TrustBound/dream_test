# Dream Test 2.2.0 Release Notes

**Release Date:** 2026-11-17

Dream Test 2.2.0 adds line coverage. Turn it on with one line in your test
`main`, and the runner shows which lines your tests ran and which they did
not. Nothing changes for projects that do not turn it on.

## Highlights

### 📈 Line coverage

`runner.coverage(coverage.new())` measures the modules in `src` with the
native line counters of the BEAM. After the test results, the runner prints a
table per file and writes an LCOV file to `build/coverage/lcov.info`.

- `coverage.show_missing` lists the lines that did not run.
- `coverage.minimum_percent` and `coverage.minimum_percent_per_file` fail the
  run below a total or per-file percent.
- `runner.coverage_from_environment` turns coverage on only when
  `DREAM_TEST_COVERAGE` is `1` or `true`, for example only in CI.
- More than one coverage run can measure in one BEAM, as long as no module is
  in two runs at the same time.

### 🙈 Exclusions with reasons

- `coverage.exclude` and `coverage.exclude_with_reason` leave out files that
  match a pattern.
- `// coverage:ignore`, `coverage:ignore-start` / `coverage:ignore-end` and
  `coverage:ignore-function` markers leave out lines, blocks and whole
  functions. Text after a marker is its reason.
- The table always says what was excluded. `coverage.show_excluded` lists it,
  and `coverage.require_exclusion_reasons` fails the run when a reason is
  missing.

### 📤 Output formats

LCOV, JSON (`coverage.json_path`), Cobertura XML (`coverage.cobertura_path`),
Markdown for GitHub job summaries (`coverage.markdown_path`), and HTML with
annotated source, as a directory (`coverage.html_path`) or one combined page
(`coverage.html_file`).

### 🔀 Coverage from other BEAM instances

`coverage.merge_lcov` adds LCOV files from other runs, for example an
application server that measures itself with `coverage.start` and
`coverage.finish` and writes its LCOV file when it stops.

### 🏷️ Coverage badge

A new guide, `documentation/12-coverage-badge.md`, shows how to publish a live
coverage badge from GitHub Actions to a `badges` branch, with no outside
service.

## Requirements

- Gleam 1.19 or later for exact line numbers. Older Gleam versions map only
  the first line of each function, and the coverage table warns about it.
- Erlang/OTP 27 or later with the JIT (the default on x86-64 and ARM64) for
  coverage. On another runtime, `coverage.start` fails with
  `NativeCoverageUnsupported`.

## Upgrading

No breaking changes. Coverage is opt-in.
