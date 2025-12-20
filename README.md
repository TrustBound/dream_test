<div align="center">
  <img src="./ricky_and_lucy.png" alt="Dream Test logo" width="180">
  <h1>Dream Test</h1>
  <p><strong>A feature-rich testing framework for Gleam.</strong></p>

  <a href="https://hex.pm/packages/dream_test">
    <img src="https://img.shields.io/hexpm/v/dream_test?color=8e4bff&label=hex" alt="Hex.pm">
  </a>
  <a href="https://hexdocs.pm/dream_test/">
    <img src="https://img.shields.io/badge/docs-hexdocs-8e4bff" alt="Documentation">
  </a>
  <a href="./LICENSE.md">
    <img src="https://img.shields.io/badge/license-MIT-blue" alt="License">
  </a>
</div>

<br>

## What is Dream Test?

Dream Test is a **testing framework for Gleam** that feels like Gleam:

| Feature                                       | What you get                                                                                                                          |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Built-in + custom matchers**                | A rich built-in matcher library, plus a clean custom matcher pattern so you can write reusable matchers and keep assertions readable. |
| **Straight Gleam**                            | No macros or hidden runtime tricks—just Gleam modules and functions.                                                                  |
| **Parallel by default**                       | Fast test runs with bounded concurrency, plus a single dial to go fully sequential when you need it.                                  |
| **Crash + timeout isolation**                 | Each test is isolated so crashes and timeouts don’t take down the whole run.                                                          |
| **Explicit runner (with optional discovery)** | You control what runs and how it’s reported: list suites explicitly, or opt into discovery when that’s cleaner.                       |
| **Reporters for humans + CI**                 | Event-driven reporters (BDD/Progress/JSON) and post-run formatting.                                                                   |
| **Context-aware tests**                       | Share setup and values cleanly with `unit_context` when tests need more structure than plain `describe`/`it`.                         |
| **Lifecycle hooks**                           | Compose setup/teardown with `before_*` / `after_*` hooks without turning tests into a maze.                                           |
| **Snapshot testing**                          | Lock in complex output with snapshots when “assert everything” would be noisy.                                                        |
| **Gherkin BDD feature specs**                 | Write clear `Given/When/Then` specs that bridge product and engineering—authored as standard `.feature` files or directly in Gleam.   |
| **A path from small to large**                | Start with `describe`/`it`, then add contexts, hooks, snapshots, or Gherkin only when they actually help.                             |

It’s designed for the common case (unit + integration tests) and it scales cleanly as your suite grows (contexts, snapshots, BDD/Gherkin, CI reporting).

**Target:** Dream Test runs on the **BEAM (Erlang)**.

## Feature Showcase

### Showcase: discovery runner

```gleam
import dream_test/discover.{from_path, to_suites}
import dream_test/reporters
import dream_test/runner
import gleam/io

pub fn main() {
  let suites =
    discover.new()
    |> from_path("unit/**_test.gleam")
    |> to_suites()

  runner.new(suites)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/runner/discovery_runner.gleam)</sub>
<sub>📖 [Guide](documentation/02-quick-start.md)</sub>

### Showcase: explicit suites + assertions

This is the simplest thing that can work: one module exports `tests()`, and `main()` runs it.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
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
    it("finds substrings", fn() {
      "hello world"
      |> string.contains("world")
      |> should
      |> be_equal(True)
      |> or_fail_with("Should find 'world' in string")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/unit/quick_start.gleam)</sub>
<sub>📖 [Guide](documentation/02-quick-start.md)</sub>

## Built-in matchers (table)

All built-in matchers are re-exported from `dream_test/matchers` and are designed to be used in the `should |> matcher(...) |> or_fail_with(...)` pipeline.

| Category               | Matcher                        | What it asserts / does                                               |
| ---------------------- | ------------------------------ | -------------------------------------------------------------------- |
| **Equality**           | `be_equal(expected)`           | Structural equality (`==`).                                          |
| **Equality**           | `not_equal(unexpected)`        | Structural inequality (`!=`).                                        |
| **Boolean**            | `be_true()`                    | Value is `True`.                                                     |
| **Boolean**            | `be_false()`                   | Value is `False`.                                                    |
| **Option**             | `be_some()`                    | Value is `Some(_)` and **unwraps** to the inner value for chaining.  |
| **Option**             | `be_none()`                    | Value is `None`.                                                     |
| **Result**             | `be_ok()`                      | Value is `Ok(_)` and **unwraps** to the `Ok` value for chaining.     |
| **Result**             | `be_error()`                   | Value is `Error(_)` and **unwraps** to the error value for chaining. |
| **Collections (List)** | `contain(item)`                | List contains `item`.                                                |
| **Collections (List)** | `not_contain(item)`            | List does not contain `item`.                                        |
| **Collections (List)** | `have_length(n)`               | List length is exactly `n`.                                          |
| **Collections (List)** | `be_empty()`                   | List is empty (`[]`).                                                |
| **Comparison (Int)**   | `be_greater_than(n)`           | Value is `> n`.                                                      |
| **Comparison (Int)**   | `be_less_than(n)`              | Value is `< n`.                                                      |
| **Comparison (Int)**   | `be_at_least(n)`               | Value is `>= n`.                                                     |
| **Comparison (Int)**   | `be_at_most(n)`                | Value is `<= n`.                                                     |
| **Comparison (Int)**   | `be_between(min, max)`         | Value is strictly between: `min < value < max`.                      |
| **Comparison (Int)**   | `be_in_range(min, max)`        | Value is in inclusive range: `min <= value <= max`.                  |
| **Comparison (Float)** | `be_greater_than_float(n)`     | Value is `> n`.                                                      |
| **Comparison (Float)** | `be_less_than_float(n)`        | Value is `< n`.                                                      |
| **String**             | `start_with(prefix)`           | String starts with `prefix`.                                         |
| **String**             | `end_with(suffix)`             | String ends with `suffix`.                                           |
| **String**             | `contain_string(substring)`    | String contains `substring`.                                         |
| **Snapshot**           | `match_snapshot(path)`         | Compares a `String` to a snapshot file (creates it on first run).    |
| **Snapshot**           | `match_snapshot_inspect(path)` | Snapshot testing for any value via `string.inspect` serialization.   |

### Showcase: runner configuration (parallelism + timeouts)

Building on the `tests()` function above, you can tune parallelism and timeouts:

```gleam
import dream_test/reporters
import dream_test/runner
import gleam/io

pub fn main() {
  runner.new([tests()])
  |> runner.max_concurrency(8)
  |> runner.default_timeout_ms(10_000)
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/runner/runner_config.gleam)</sub>
<sub>📖 [Guide](documentation/07-runner-and-execution.md)</sub>

### More showcases (tested examples)

- **Snapshot testing**: [Snapshot testing example](examples/snippets/test/snippets/matchers/snapshot_testing.gleam)
- **Lifecycle hooks**: [Lifecycle hooks](examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam)
- **Context-aware tests**: [Context-aware tests](examples/snippets/test/snippets/hooks/context_aware_tests.gleam)
- **Gherkin BDD**:
  - Standard `.feature` file: [Shopping cart feature](examples/shopping_cart/features/shopping_cart.feature)
  - Inline Gleam DSL: [Feature in Gleam](examples/shopping_cart/test/features/shopping_cart.gleam)
  - Runner + steps: [Example runner](examples/shopping_cart/test/shopping_cart_test.gleam) and [step definitions](examples/shopping_cart/test/steps/)

## Integration testing (behavior over time)

Unit tests are great for “input → output.” Integration tests often look like “a sequence of behavior over time.”

Dream Test gives you a few ways to keep integration tests readable:

- **Inline Gherkin in Gleam** (works great when engineers own the specs)
- **Standard `.feature` files** (great when specs come from tickets/QA)
- **Snapshot testing** (great for “rendered output” and other complex results)

### Inline Gherkin (authored in Gleam)

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporters
import dream_test/runner
import gleam/io
import gleam/result

fn step_have_items(context: StepContext) {
  let count = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", count)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_should_have(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    new_registry()
    |> step("I have {int} items in my cart", step_have_items)
    |> step("I add {int} more items", step_add_items)
    |> step("I should have {int} items total", step_should_have)

  feature("Shopping Cart", steps, [
    scenario("Adding items to cart", [
      given("I have 3 items in my cart"),
      when("I add 2 more items"),
      then("I should have 5 items total"),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/gherkin/gherkin_hero.gleam)</sub>
<sub>📖 [Guide](documentation/10-gherkin-bdd.md)</sub>

### `.feature` files (authored as standard Gherkin)

```gherkin
Feature: Shopping Cart
  Background:
    Given the server is running

  Scenario: Adding items
    Given the cart is empty
    When I add 3 items
    Then the cart should have 3 items
```

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/gherkin/feature.{FeatureConfig, to_test_suite}
import dream_test/gherkin/parser
import dream_test/gherkin/steps.{type StepContext, get_int, new_registry, step}
import dream_test/gherkin/world.{get_or, put}
import dream_test/reporters
import dream_test/runner
import gleam/io
import gleam/result

fn step_server_running(context: StepContext) {
  put(context.world, "server_running", True)
  Ok(succeed())
}

fn step_empty_cart(context: StepContext) {
  put(context.world, "cart", 0)
  Ok(succeed())
}

fn step_add_items(context: StepContext) {
  let current = get_or(context.world, "cart", 0)
  let to_add = get_int(context.captures, 0) |> result.unwrap(0)
  put(context.world, "cart", current + to_add)
  Ok(succeed())
}

fn step_verify_count(context: StepContext) {
  let expected = get_int(context.captures, 0) |> result.unwrap(0)
  get_or(context.world, "cart", 0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("Cart count mismatch")
}

pub fn tests() {
  let steps =
    new_registry()
    |> step("the server is running", step_server_running)
    |> step("the cart is empty", step_empty_cart)
    |> step("I add {int} items", step_add_items)
    |> step("the cart should have {int} items", step_verify_count)

  // Save the feature text above as `test/cart.feature`
  let assert Ok(feature) = parser.parse_file("test/cart.feature")

  let config = FeatureConfig(feature: feature, step_registry: steps)
  to_test_suite("cart_test", config)
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source (.feature)](examples/snippets/test/cart.feature)</sub>
<sub>🧪 [Tested source (runner + steps)](examples/snippets/test/snippets/gherkin/gherkin_file.gleam)</sub>
<sub>📖 [Guide](documentation/10-gherkin-bdd.md)</sub>

### Snapshot testing (handy for integration outputs too)

```gleam
import dream_test/matchers.{
  match_snapshot, match_snapshot_inspect, or_fail_with, should,
}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/string

fn render_profile(name, age) {
  string.concat([
    "<div class=\"profile\">\n",
    "  <h1>",
    name,
    "</h1>\n",
    "  <p>Age: ",
    int.to_string(age),
    "</p>\n",
    "</div>",
  ])
}

pub type Config {
  Config(host: String, port: Int, debug: Bool)
}

fn build_config() {
  Config(host: "localhost", port: 8080, debug: True)
}

pub fn tests() {
  describe("Snapshot testing", [
    it("renders user profile", fn() {
      render_profile("Alice", 30)
      |> should
      |> match_snapshot("./test/snapshots/user_profile.snap")
      |> or_fail_with("Profile should match snapshot")
    }),
    it("builds config correctly", fn() {
      build_config()
      |> should
      |> match_snapshot_inspect("./test/snapshots/config.snap")
      |> or_fail_with("Config should match snapshot")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](examples/snippets/test/snippets/matchers/snapshot_testing.gleam)</sub>
<sub>📖 [Guide](documentation/09-snapshot-testing.md)</sub>

## Guides (start here)

If you’re new to Dream Test, this is the shortest path from “it runs” to “it scales”.

1. [Installation](documentation/01-installation.md)
2. [Quick Start](documentation/02-quick-start.md)
3. [Writing unit tests (`describe`/`it`/`group`/`skip`)](documentation/03-writing-tests.md)
4. [Context-aware tests (`unit_context`)](documentation/04-context-aware-tests.md)
5. [Assertions & matchers (the `should` pipeline)](documentation/05-assertions-and-matchers.md)
6. [Lifecycle hooks (`before_*` / `after_*`)](documentation/06-lifecycle-hooks.md)
7. [Runner & execution model (parallelism, timeouts, CI)](documentation/07-runner-and-execution.md)
8. [Reporters (BDD, JSON, Progress, Gherkin)](documentation/08-reporters.md)
9. [Snapshot testing](documentation/09-snapshot-testing.md)
10. [Gherkin BDD (Given/When/Then, placeholders, discovery)](documentation/10-gherkin-bdd.md)
11. [Utilities (file/process/timing/sandbox helpers)](documentation/11-utilities.md)

API reference lives on Hexdocs: `https://hexdocs.pm/dream_test/`

## Contributing

If you’re working in this repo, use the Makefile targets (tests, checks, etc.).

- `CONTRIBUTING.md`
- `STANDARDS.md`

<div align="center">
  <sub>Built in Gleam, on the BEAM, by the <a href="https://github.com/trustbound/dream">Dream Team</a>.</sub>
</div>
