# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-01-31

### Added

- **Runner-level hooks** (`dream_test/runner`, `dream_test/parallel`)

  - New `before_each_test`, `after_each_test`, `before_each_suite`, `after_each_suite`,
    `before_all_suites`, and `after_all_suites` hooks
  - Hooks receive structured metadata via `types.TestInfo` and `types.SuiteInfo`
  - Per-test hooks run in the executor with sandboxing and correct ordering around suite hooks

- **Test/suite metadata** (`dream_test/types`)

  - New `TestInfo` and `SuiteInfo` types, including best-effort `source`
  - Source tracking for unit discovery (module name) and Gherkin discovery (feature path)

### Changed

- **Setup failure status** (`dream_test/parallel`)

  - Runner `before_each_test` failures now yield `SetupFailed` and skip test bodies

### Documentation

- Added runner hook section to the runner guide with a tested snippet
- Updated README and documentation index to highlight runner hooks
- Refreshed compatibility reports (`COMPATIBILITY.md`, `COMPATIBILITY_REPORT.md`, `CONSTRAINT_ANALYSIS.md`)

## [2.0.0] - 2025-12-27

### Added

- **Suite-first runner builder** (`dream_test/runner`)

  - New `runner.new([suite]) |> ... |> runner.run()` pipeline for configuring and running suites
  - Configuration is applied via builder functions (`max_concurrency`, `default_timeout_ms`, `progress_reporter`, `results_reporters`, `output`, `silent`, `exit_on_failure`, `filter_tests`)
  - Suite list can be built incrementally with `add_suites(...)`, and specific suites can run with an execution config override via `add_suites_with_config(...)`

- **Runtime test discovery** (`dream_test/discover`)

  - Builder for discovering compiled test modules under `./test/` via module path globs (e.g. `"unit/**_test.gleam"`)
  - Loads modules that export `tests/0` and calls them to obtain `TestSuite(Nil)` values

- **Reporting split** (`dream_test/reporters/types`, `dream_test/reporters/bdd`, `dream_test/reporters/json`, `dream_test/reporters/progress`)

  - Runner emits structured `ReporterEvent`s (`RunStarted`, `TestFinished`, `RunFinished`, plus hook events)
  - Live progress via `runner.progress_reporter(progress.new())`
  - End-of-run reporting via `runner.results_reporters([bdd.new(), json.new(), ...])`

- **Live progress bar reporter** (`dream_test/reporters/progress`)

  - In-place single-line progress bar that adapts to terminal width

- **Selective sandbox crash reports** (`dream_test/sandbox`)

  - New `SandboxConfig.show_crash_reports` flag (default `False`) to suppress noisy BEAM crash reports while still reporting failures
  - Convenience helper `sandbox.with_crash_reports` for local debugging

### Changed

- **Unit DSL is suite-first** (`dream_test/unit`, `dream_test/types`)

  - Suite items are now typed (`SuiteItem(ctx)`) and suites carry context (`TestSuite(ctx)`)
  - Test bodies now return `Result(AssertionResult, String)` for explicit failure reporting
  - Lifecycle hooks now return `Result(ctx, String)` for explicit failure reporting

- **Parallel runner API** (`dream_test/parallel`)

  - Added event-driven entrypoints for driving reporters during parallel execution

### Documentation

- Updated docs to the new v2 suite-first pipeline and event-driven reporter model.

### Breaking Changes

- `dream_test/runner`: replaced `run_all*` / `run_suite*` free functions with the `RunBuilder` pipeline (`runner.new(...) |> ... |> runner.run()`).
- `dream_test/unit`: test bodies now return `Result(AssertionResult, String)` instead of `AssertionResult`. Hooks now return `Result(ctx, String)` instead of `ctx`.
- `dream_test/unit`: replaced the old `UnitTest` tree + `to_test_suite` conversion with typed suite builders (`describe`, `group`, `describe_with_hooks`, `SuiteHooks`).
- `dream_test/types`: suites and test cases are now context-typed (`TestSuite(ctx)`, `SuiteTestCase(ctx)`), so user code matching these types must be updated.
- **Reporters refactored and split**: live output via `runner.progress_reporter(progress.new())`, end-of-run output via `runner.results_reporters([bdd.new(), json.new(), ...])`. The old `dream_test/reporter` module is replaced by `dream_test/reporters/*`.
- `dream_test/gherkin/world.get`: error type changed from `Result(a, Nil)` to `Result(a, String)` for more informative failures.

## [1.2.0] - 2025-12-04

### Added

- **Snapshot Testing** (`dream_test/matchers/snapshot`, `dream_test/assertions/should`)

  - `match_snapshot()` matcher for comparing string output against stored files
  - `match_snapshot_inspect()` for testing non-string values via `string.inspect`
  - Auto-creates snapshots on first run; compares on subsequent runs
  - Delete snapshot file to regenerate (no magic flags or environment variables)
  - `clear_snapshot()` to programmatically delete individual snapshots
  - `clear_snapshots_in_directory()` to bulk-delete `.snap` files
  - `SnapshotFailure` payload for rich error reporting with diffs

- **File Module** (`dream_test/file`)

  - Generalized file I/O module for internal use
  - `read()`, `write()`, `delete()`, `delete_files_matching()` functions
  - Structured `Error` type with variants: `NotFound`, `PermissionDenied`, `IsDirectory`, `NoSpace`, `FileSystemError`
  - `error_to_string()` for human-readable error messages
  - Auto-creates parent directories on write

### Changed

- **Gherkin Parser** now uses the generalized `dream_test/file` module
- **README restructured** with table of contents and teaching-optimized section order

### Documentation

- Added "Snapshot Testing" section to README with usage examples
- Added table of contents under hero for quick navigation
- Reordered sections for optimal learning flow
- Added "Snapshot" to available matchers table
- Added "Snapshot testing" to feature status table
- Added `snapshot_testing.gleam` example in `examples/snippets/test/`
- World-class hexdocs for all new public functions and types

## [1.1.0] - 2025-12-02

### Added

- **Test tagging and filtering** (`dream_test/unit`, `dream_test/runner`)

  - `with_tags()` function to tag unit tests for categorization
  - `RunnerConfig.test_filter` predicate for selective test execution
  - Filter by tags, name, kind, or any `SingleTestConfig` field
  - Works with both flat mode (`run_all`) and suite mode (`run_suite`)
  - Unified tagging across unit tests and Gherkin scenarios

- **`succeed()` function** (`dream_test/assertions/should`)

  - Explicit success counterpart to `fail_with()` for conditional branches
  - Use in `case` expressions where all branches must return `AssertionResult`
  - Recommended over importing `AssertionOk` directly in user code

- **Gherkin/Cucumber BDD Support**

  - Full Cucumber-style Given/When/Then testing with typed step definitions
  - Inline DSL for defining features directly in Gleam (`feature`, `scenario`, `given`, `when`, `then`)
  - `.feature` file parser supporting standard Gherkin syntax
  - Step registry with radix trie for O(words) step lookup
  - Typed placeholders: `{int}`, `{float}`, `{string}`, `{word}`
  - Prefix/suffix support for placeholders (e.g., `${float}` matches `$19.99`)
  - World state management with ETS-backed mutable scenario state
  - Background steps for shared setup across scenarios
  - Tag support for filtering scenarios (`@smoke`, `@slow`, etc.)
  - Scenario Outline with Examples table expansion
  - Data tables and doc strings in steps
  - Gherkin-style reporter with scenario-level output

- **Feature Discovery** (`dream_test/gherkin/discover`)

  - Builder pattern for loading `.feature` files with glob patterns
  - `features()` → `with_registry()` → `to_suite()` fluent API
  - Graceful error handling for parse failures

- **Per-Test Timing** (`dream_test/timing`)

  - Human-readable duration formatting (ms, s, m, h)
  - Per-test and total duration in BDD and Gherkin reporters
  - Monotonic time measurement for accurate elapsed time

- **JSON Reporter** (`dream_test/reporters/json`)

  - Machine-readable JSON output for CI/CD integration
  - `format` and `format_pretty` for string output
  - `report` and `report_pretty` for pipeline integration
  - Includes system info (OS, OTP version, Gleam version)
  - Detailed failure payloads with expected/actual values
  - Composable with BDD reporter for dual output

### Dependencies

- Added `gleam_regexp` dependency for step pattern tokenization
- Added `gleam_json` dependency for JSON reporter

### Documentation

- Added comprehensive Gherkin/BDD section to README
- Added JSON reporter section to README
- Added shopping cart example in `examples/shopping_cart/`
- Added Gherkin and JSON reporter snippets in `examples/snippets/`
- Updated feature status table with Gherkin/Cucumber BDD and JSON Reporter
- Added custom matchers documentation with example snippet
- Updated hexdocs for all new public functions

## [1.0.3] - 2025-12-01

### Changed

- **Improved Pipeline Composability**
  - `report` now returns results, enabling cleaner pipelines:
    `run_all() |> report(io.print) |> exit_on_failure()`

### Documentation

- Added "CI integration" section to README with `exit_on_failure` examples
- Updated Quick Start example to demonstrate full pipeline with exit codes
- Added "CI exit codes" to the feature status table

## [1.0.2] - 2025-12-01

### Added

- **Test Skipping**

  - New `skip` function as an analog to `it` for temporarily disabling tests
  - Simply change `it` to `skip` to skip a test; the body is preserved but not executed
  - Skipped tests appear with `-` marker in output and are counted in summary

- **Exit Code Handling**

  - New `exit_on_failure` function exits with code 1 if any tests failed
  - New `has_failures` function to check if test results contain failures
  - Proper CI integration: test suites now fail builds when tests fail

- **AssertionSkipped Result Type**
  - New `AssertionSkipped` variant in `AssertionResult` for skip support

### Documentation

- Added "Skipping tests" section to README with examples
- Added new `skipping_tests.gleam` snippet in `examples/snippets/test/`

## [1.0.1] - 2025-12-01

### Changed

- **Documentation Improvements**
  - All README code examples are now backed by tested source files
  - Each snippet has its own file in `examples/snippets/test/` for stable linking
  - Added Quick Start example with string utilities
  - README code blocks now include 🧪 links to verified source

### Removed

- Removed redundant `examples/math_app/` and `examples/string_app/` directories
- Consolidated all README examples into `examples/snippets/`

## [1.0.0] - 2025-11-30

### Added

- **Core Testing Framework**

  - `describe` and `it` blocks for BDD-style test organization
  - Nested describe blocks with proper scoping
  - Test tagging and filtering support

- **Assertions Module** (`dream_test/assertions/should`)

  - Fluent assertion API with `should` builder
  - `or_fail_with` for custom failure messages
  - Chainable assertion pattern

- **Matchers**

  - `equality` - `equal`, `not_equal`, `be_same_as`
  - `boolean` - `be_true`, `be_false`
  - `comparison` - `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`
  - `string` - `contain`, `start_with`, `end_with`, `match_pattern`
  - `collection` - `be_empty`, `have_length`, `contain_element`, `contain_exactly`
  - `option` - `be_some`, `be_none`, `unwrap_some`
  - `result` - `be_ok`, `be_error`, `unwrap_ok`, `unwrap_error`

- **Test Runner**

  - Parallel test execution with configurable concurrency
  - Sequential test support for tests requiring isolation
  - Test timeout handling
  - Comprehensive test result reporting

- **BDD Reporter** (`dream_test/reporters/bdd`)

  - Colorized terminal output
  - Hierarchical test result display
  - Summary statistics (passed, failed, skipped)
  - Failure details with context

- **Lifecycle Support**

  - `before_each` and `after_each` hooks
  - Setup and teardown at describe block level
  - Context passing between lifecycle hooks and tests

- **Sandbox Module** (`dream_test/sandbox`)

  - Isolated test execution environment
  - Process isolation for test safety

- **Process Testing** (`dream_test/process`)
  - Utilities for testing OTP processes
  - Process lifecycle testing support

### Documentation

- Comprehensive README with usage examples
- CONTRIBUTING guide for contributors
- STANDARDS document for code conventions
- API documentation for all public modules

[Unreleased]: https://github.com/TrustBound/dream_test/compare/2.1.0...HEAD
[2.1.0]: https://github.com/TrustBound/dream_test/compare/2.0.0...2.1.0
[2.0.0]: https://github.com/TrustBound/dream_test/compare/1.2.0...2.0.0
[1.2.0]: https://github.com/TrustBound/dream_test/compare/1.1.0...1.2.0
[1.1.0]: https://github.com/TrustBound/dream_test/compare/1.0.3...1.1.0
[1.0.3]: https://github.com/TrustBound/dream_test/compare/1.0.2...1.0.3
[1.0.2]: https://github.com/TrustBound/dream_test/compare/1.0.1...1.0.2
[1.0.1]: https://github.com/TrustBound/dream_test/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/TrustBound/dream_test/releases/tag/1.0.0
