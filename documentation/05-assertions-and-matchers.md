## Assertions & matchers (the `should` pipeline)

If you’ve used Jest/RSpec style assertions before, this is the Dream Test equivalent — but pipe-first and composable.

Dream Test assertions are designed around a single, composable pattern:

```gleam
value
|> should
|> matcher(...)
|> or_fail_with("human-friendly message")
```

Read it left-to-right:

- Start from the value you’re checking.
- `should` starts an assertion chain.
- Each matcher either confirms something (“equal”) or unwraps something (“be_ok”, “be_some”).
- `or_fail_with(...)` attaches the message you’ll see when this fails.

### Why this pattern?

- **No macros, no hidden magic**: everything is ordinary Gleam code.
- **Composable**: matchers can unwrap values (like `Option`/`Result`) and pass the unwrapped value onward.
- **Consistent failures**: failures are structured values that reporters can format well.

There’s also a human reason:

- Assertions become part of your test’s narrative. A good pipeline reads like a sentence and fails with a message that tells you what matters.

### Chaining matchers (unwrap + assert)

```gleam
import dream_test/matchers.{be_equal, be_ok, be_some, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import gleam/option.{Some}

pub fn tests() {
  describe("Chaining matchers", [
    // Unwrap Some, then check the value
    it("unwraps Option", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("Should contain 42")
    }),
    // Unwrap Ok, then check the value
    it("unwraps Result", fn() {
      Ok("success")
      |> should
      |> be_ok()
      |> be_equal("success")
      |> or_fail_with("Should be Ok with 'success'")
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/chaining.gleam)</sub>

### Built-in matcher catalogue (practical examples)

```gleam
import dream_test/matchers.{
  be_between, be_equal, be_false, be_ok, be_some, be_true, contain,
  contain_string, have_length, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Built-in matchers", [
    it("boolean: be_true", fn() {
      True
      |> should
      |> be_true()
      |> or_fail_with("expected True")
    }),

    it("boolean: be_false", fn() {
      False
      |> should
      |> be_false()
      |> or_fail_with("expected False")
    }),

    it("option: be_some + equal", fn() {
      Some(42)
      |> should
      |> be_some()
      |> be_equal(42)
      |> or_fail_with("expected Some(42)")
    }),

    it("result: be_ok + equal", fn() {
      Ok("hello")
      |> should
      |> be_ok()
      |> be_equal("hello")
      |> or_fail_with("expected Ok(\"hello\")")
    }),

    it("collection: have_length", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("expected list length 3")
    }),

    it("collection: contain", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("expected list to contain 2")
    }),

    it("comparison: be_between", fn() {
      5
      |> should
      |> be_between(1, 10)
      |> or_fail_with("expected 5 to be between 1 and 10")
    }),

    it("string: contain_string", fn() {
      "hello world"
      |> should
      |> contain_string("world")
      |> or_fail_with("expected substring match")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/matchers/builtin_matchers.gleam)</sub>

### Writing custom matchers (the matcher pattern)

Dream Test doesn’t require a special “custom matcher API.” Built-in and custom matchers follow the same simple pattern:

- A matcher is a function that **takes a `MatchResult(a)`** and **returns a `MatchResult(b)`**.
- If the incoming result is already a failure, the matcher should **propagate it unchanged**.
- Otherwise, it inspects the value and returns either `MatchOk(value)` or `MatchFailed(AssertionFailure(...))`.

Here’s a minimal custom matcher that checks “even number”:

```gleam
import dream_test/types.{
  AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import gleam/int
import gleam/option.{Some}

pub fn be_even(result) {
  case result {
    // If already failed, propagate the failure
    MatchFailed(failure) -> MatchFailed(failure)
    // Otherwise, check our condition
    MatchOk(value) -> check_even(value)
  }
}

fn check_even(value) {
  case value % 2 == 0 {
    True -> MatchOk(value)
    False ->
      MatchFailed(AssertionFailure(
        operator: "be_even",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(value),
          description: "expected an even number",
        )),
      ))
  }
}
```

This example uses a structured `payload` (`CustomMatcherFailure`) so reporters can display richer diagnostics without forcing you to bake everything into a string message.

<sub>🧪 [Tested source](../examples/snippets/test/snippets/matchers/custom_matchers.gleam)</sub>

### Why matchers unwrap values

The “unwrap then assert” flow is one of the biggest quality-of-life wins of the pipeline approach.

Instead of:

- Pattern matching in every test
- Copy/pasting error handling
- Producing unclear failures (“expected Ok(_) but got Error(_)”) without context

…you can write the story you mean: “this should be Ok, and the value should equal X.”

### Explicit success/failure (when branching is unavoidable)

Sometimes you need a conditional check that isn’t a good fit for the normal matcher pipeline.
Use `succeed()` and `fail_with("...")` to keep the return type consistent.

```gleam
import dream_test/matchers.{fail_with, succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import snippets.{divide}

pub fn tests() {
  describe("Explicit failures", [
    it("succeeds explicitly when division works", fn() {
      case divide(10, 2) {
        Ok(_) -> Ok(succeed())
        Error(_) -> Ok(fail_with("Should have succeeded"))
      }
    }),
    it("fails explicitly when expecting an error", fn() {
      case divide(10, 0) {
        Ok(_) -> Ok(fail_with("Should have returned an error"))
        Error(_) -> Ok(succeed())
      }
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/unit/explicit_failures.gleam)</sub>

### Common pitfalls (and how to avoid them)

- **Forgetting `or_fail_with(...)`**: without it, failures tend to be harder to interpret in CI logs. Treat it like part of the assertion, not an optional extra.
- **Asserting too much in one chain**: long chains can hide which step mattered. Split into smaller checks when it improves clarity.
- **Using snapshots where equality is clearer**: if a value is tiny, prefer `equal(...)` over snapshot matchers (see the snapshot chapter for the tradeoff).

### What's Next?

- Go back to [Context-aware unit tests](04-context-aware-tests.md)
- Go back to [Documentation README](README.md)
- Continue to [Lifecycle hooks](06-lifecycle-hooks.md)
