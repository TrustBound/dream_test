## Dream Test Documentation

Dream Test is a **testing framework for Gleam** focused on fast feedback and clean test code.

### What is it good for?

- **Everyday unit tests**: readable `describe`/`it` suites
- **Reliable CI**: good failure output, optional JSON output, and exit codes
- **Speed**: parallel execution by default (configurable)
- **Stability**: timeouts and crash isolation so one bad test doesn’t wreck the whole run
- **Behavior specs**: optional Gherkin / Given-When-Then workflows

For the full API reference, see **Hexdocs**: [Dream Test on Hexdocs](https://hexdocs.pm/dream_test/).

Dream Test is designed around a simple workflow:

- You write tests with `describe` and `it`
- You run them with `runner.new([...]) |> runner.run()`
- You assert with a pipe-friendly pattern: `value |> should() |> matcher(...) |> or_fail_with("...")`

### How does it work? (the short version)

- Your tests run in isolated BEAM processes (crashes are contained).
- The runner can execute many tests at once (parallelism), while still producing readable output.
- Timeouts prevent hanging tests from stalling a run.

### Start here (in order)

1. [Installation](01-installation.md)
2. [Quick Start](02-quick-start.md)
3. [Writing unit tests (describe/it/group/skip)](03-writing-tests.md)
4. [Context-aware unit tests (`unit_context`)](04-context-aware-tests.md)
5. [Assertions & matchers (the `should()` pipeline)](05-assertions-and-matchers.md)
6. [Lifecycle hooks (before/after)](06-lifecycle-hooks.md)
7. [Runner & execution model (parallelism, timeouts, CI)](07-runner-and-execution.md)
8. [Reporters (BDD, JSON, Progress, Gherkin)](08-reporters.md)
9. [Snapshot testing](09-snapshot-testing.md)
10. [Gherkin BDD (Given/When/Then, placeholders, discovery)](10-gherkin-bdd.md)
11. [Utilities (file/process/timing/sandbox helpers)](11-utilities.md)
