## Dream Test Documentation

This folder is a **guided series** for engineers adopting Dream Test. It’s written as narrative documentation: each chapter explains the problem it solves, the mental model you need to use it safely, and the rationale behind the API shape.

If you want a complete “everything in one place” reference, see [Dream Test on Hexdocs](https://hexdocs.pm/dream_test/). This series is intentionally more opinionated: it’s meant to help you develop good instincts and avoid the common failure modes (flaky tests, hidden setup, unreadable failures).

### Target support

Dream Test targets the **BEAM (Erlang)**.

### The 30-second mental model

Dream Test tries to keep three ideas explicit:

- **Suites are data**: you build a nested set of suites/groups/tests (unit suites or Gherkin features) rather than relying on hidden global test discovery.
- **The runner is a policy decision**: your `main()` chooses output style, concurrency, timeouts, and CI behavior.
- **Assertions are pipelines**: you start from a value, run matchers, then end with a failure message you’ll want to read at 2am.

### Why the docs read like this

Testing frameworks often optimize for “look how short this example is.” Dream Test optimizes for “why did this fail, and what do I do next?”

That’s why you’ll see the same patterns repeated:

- **Explicit runner module** instead of magic auto-discovery everywhere (with an opt-in discovery helper when you want it).
- **Pipe-first assertions** instead of fluent builders or macros.
- **Process isolation + timeouts** so a single bad test can’t hang or crash the whole run.

### Recommended reading order (the full story)

1. [Installation](01-installation.md) — get to a green run, and understand why `main()` exists.
2. [Quick Start](02-quick-start.md) — the first “real” test, with two runner styles.
3. [Writing unit tests](03-writing-tests.md) — naming, structure, skipping, tags.
4. [Context-aware unit tests](04-context-aware-tests.md) — when “setup returns a value” and you need to pass it into tests.
5. [Assertions & matchers](05-assertions-and-matchers.md) — how and why the `should` pipeline works.
6. [Lifecycle hooks](06-lifecycle-hooks.md) — power tools, and how to keep them from hiding meaning.
7. [Runner & execution model](07-runner-and-execution.md) — concurrency, timeouts, CI, reliability, and runner hooks.
8. [Reporters](08-reporters.md) — humans vs machines, streaming vs post-run.
9. [Snapshot testing](09-snapshot-testing.md) — when snapshots make tests clearer (and when they make them worse).
10. [Gherkin / BDD](10-gherkin-bdd.md) — scenario testing with a world state and placeholder captures.
11. [Utilities](11-utilities.md) — small helpers that make tests less repetitive and more reliable.

### If you only need one thing…

- **I want to get a test running**: start at [Quick Start](02-quick-start.md).
- **My tests are flaky**: read [Runner & execution model](07-runner-and-execution.md) and [Lifecycle hooks](06-lifecycle-hooks.md).
- **I need better CI integration**: jump to [Reporters](08-reporters.md) (JSON) and [Runner & execution model](07-runner-and-execution.md) (exit codes).
