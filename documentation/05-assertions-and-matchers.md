## Assertions & matchers (the `should()` pipeline)

If you’ve used Jest/RSpec style assertions before, this is the Dream Test equivalent — but pipe-first and composable.

Dream Test assertions are designed around a single, composable pattern:

```gleam
value
|> should()
|> matcher(...)
|> or_fail_with("human-friendly message")
```

Read it left-to-right:

- Start from the value you’re checking.
- `should()` starts an assertion chain.
- Each matcher either confirms something (“equal”) or unwraps something (“be_ok”, “be_some”).
- `or_fail_with(...)` attaches the message you’ll see when this fails.

### Why this pattern?

- **No macros, no hidden magic**: everything is ordinary Gleam code.
- **Composable**: matchers can unwrap values (like `Option`/`Result`) and pass the unwrapped value onward.
- **Consistent failures**: failures are structured values that reporters can format well.

### Chaining matchers (unwrap + assert)

```gleam
import dream_test/assertions/should.{be_ok, be_some, equal, or_fail_with, should}
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
      |> should()
      |> be_some()
      |> equal(42)
      |> or_fail_with("Should contain 42")
    }),
    // Unwrap Ok, then check the value
    it("unwraps Result", fn() {
      Ok("success")
      |> should()
      |> be_ok()
      |> equal("success")
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
import dream_test/assertions/should.{
  be_between, be_false, be_ok, be_some, be_true, contain, contain_string, equal,
  have_length, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/option.{Some}

pub fn tests() {
  describe("Built-in matchers", [
    it("boolean: be_true", fn() {
      True
      |> should()
      |> be_true()
      |> or_fail_with("expected True")
    }),

    it("boolean: be_false", fn() {
      False
      |> should()
      |> be_false()
      |> or_fail_with("expected False")
    }),

    it("option: be_some + equal", fn() {
      Some(42)
      |> should()
      |> be_some()
      |> equal(42)
      |> or_fail_with("expected Some(42)")
    }),

    it("result: be_ok + equal", fn() {
      Ok("hello")
      |> should()
      |> be_ok()
      |> equal("hello")
      |> or_fail_with("expected Ok(\"hello\")")
    }),

    it("collection: have_length", fn() {
      [1, 2, 3]
      |> should()
      |> have_length(3)
      |> or_fail_with("expected list length 3")
    }),

    it("collection: contain", fn() {
      [1, 2, 3]
      |> should()
      |> contain(2)
      |> or_fail_with("expected list to contain 2")
    }),

    it("comparison: be_between", fn() {
      5
      |> should()
      |> be_between(1, 10)
      |> or_fail_with("expected 5 to be between 1 and 10")
    }),

    it("string: contain_string", fn() {
      "hello world"
      |> should()
      |> contain_string("world")
      |> or_fail_with("expected substring match")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/matchers/builtin_matchers.gleam)</sub>

### Explicit success/failure (when branching is unavoidable)

Sometimes you need a conditional check that isn’t a good fit for the normal matcher pipeline.
Use `succeed()` and `fail_with("...")` to keep the return type consistent.

```gleam
import dream_test/assertions/should.{fail_with, succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, it}
import gleam/io
import snippets.{divide}

pub fn tests() {
  describe("Explicit failures", [
    it("succeeds explicitly when division works", fn() {
      let result = divide(10, 2)
      Ok(case result {
        Ok(_) -> succeed()
        Error(_) -> fail_with("Should have succeeded")
      })
    }),
    it("fails explicitly when expecting an error", fn() {
      let result = divide(10, 0)
      Ok(case result {
        Ok(_) -> fail_with("Should have returned an error")
        Error(_) -> succeed()
      })
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
