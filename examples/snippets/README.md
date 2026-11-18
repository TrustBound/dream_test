## Dream Test snippets

This project contains **small, compile-ready examples** for every `dream_test` feature.

### Running

- **Run all snippet tests** (recommended):
  - `gleam test`
- **Run a single snippet as an app** (for snippets that have `main`):
  - `gleam run -m snippets/unit/quick_start`
  - `gleam run -m snippets/reporters/progress_reporter`
  - `gleam run -m snippets/reporters/gherkin_reporter`
  - `gleam run -m snippets/hooks/context_aware_tests`

### Feature map (one file per feature)

- **Unit DSL (0-arg tests + hooks)**:
  - `test/snippets/unit/quick_start.gleam`
  - `test/snippets/unit/hero.gleam`
  - `test/snippets/unit/chaining.gleam`
  - `test/snippets/unit/skipping_tests.gleam`
  - `test/snippets/hooks/lifecycle_hooks.gleam`
  - `test/snippets/hooks/hook_inheritance.gleam`
  - `test/snippets/hooks/hook_failure.gleam`
  - `test/snippets/unit/explicit_failures.gleam`
- **Runner configuration (parallel/sequential, timeouts, exit-on-failure)**:
  - `test/snippets/runner/runner_config.gleam`
  - `test/snippets/runner/sequential_execution.gleam`
  - `test/snippets/runner/execution_modes.gleam`
- **Reporters**:
  - **Progress (live) + BDD (end-of-run)**: `test/snippets/reporters/bdd_reporter.gleam` (and `snippets_test.gleam` uses progress + BDD by default)
  - **JSON (end-of-run)**: `test/snippets/reporters/json_reporter.gleam`
  - **BDD (formatting)**: `test/snippets/reporters/bdd_formatting.gleam`
  - **Progress bar (live)**: `test/snippets/reporters/progress_reporter.gleam`
  - **Gherkin formatting**: `test/snippets/reporters/gherkin_reporter.gleam` (runs, then formats results)
  - **JSON (formatting)**: `test/snippets/reporters/json_formatting.gleam`
  - **Reporter events (advanced/custom tooling)**: `test/snippets/reporters/reporter_api_progress_line.gleam`
- **Coverage (opt-in, minimums, exclusions, markers, table options, output files, server recipe)**:
  - `test/snippets/coverage/runner_coverage.gleam`
  - `test/snippets/coverage/coverage_environment.gleam`
  - `test/snippets/coverage/coverage_minimum.gleam`
  - `test/snippets/coverage/coverage_exclusions.gleam`
  - `test/snippets/coverage/coverage_markers.gleam`
  - `test/snippets/coverage/coverage_table.gleam`
  - `test/snippets/coverage/coverage_outputs.gleam`
  - `test/snippets/coverage/coverage_server.gleam`
  - `test/snippets/coverage/coverage_start_finish.gleam` (runs `coverage.start` and `coverage.finish` for real)
- **Sandboxing (timeouts + crash isolation)**:
  - `test/snippets/utils/sandboxing.gleam`
- **Timing helpers**:
  - `test/snippets/utils/timing_helpers.gleam`
- **File helpers**:
  - `test/snippets/utils/file_helpers.gleam`
- **Process helpers (actors, unique ports)**:
  - `test/snippets/utils/process_helpers.gleam`
- **Parallel executor (direct usage)**:
  - `test/snippets/utils/parallel_direct.gleam`
- **Core types helpers**:
  - `test/snippets/utils/types_helpers.gleam`
- **Custom matchers**:
  - `test/snippets/matchers/custom_matchers.gleam`
- **Snapshot testing**:
  - `test/snippets/matchers/snapshots.gleam`
- **Gherkin (inline DSL, placeholders, step registry, discovery, feature files)**:
  - `test/snippets/gherkin/gherkin_hero.gleam`
  - `test/snippets/gherkin/gherkin_feature.gleam`
  - `test/snippets/gherkin/gherkin_step_handler.gleam`
  - `test/snippets/gherkin/gherkin_placeholders.gleam`
  - `test/snippets/gherkin/gherkin_file.gleam` (parsing `.feature` files)
  - `test/snippets/gherkin/gherkin_discover.gleam` (glob discovery)
- **Context-aware tests (`unit_context`)**:
  - `test/snippets/hooks/context_aware_tests.gleam`
    - Note: uses a custom context type, so it’s run standalone via `gleam run -m snippets/hooks/context_aware_tests`.
