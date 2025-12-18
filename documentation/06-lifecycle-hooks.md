## Lifecycle hooks (`before_all`, `before_each`, `after_each`, `after_all`)

### Mental model

Hooks are nodes in the suite tree that the runner executes around tests:

- Setup flows **outer → inner**
- Teardown flows **inner → outer**
- Failures in setup can mark tests as setup-failed without running the body

Hooks let you run setup/teardown logic around tests while keeping the test bodies focused on behavior.

### When to use hooks

- **Use hooks** for repetitive setup/cleanup (opening DB connections, starting servers, creating temp directories).
- **Avoid hooks** when they hide important context. Prefer explicit setup in the test body for small cases.

### The four hooks

- `before_all`: runs once before any tests in the group
- `before_each`: runs before each test in the group
- `after_each`: runs after each test in the group (even if the test fails)
- `after_all`: runs once after all tests in the group

### Basic lifecycle example

```gleam
import dream_test/assertions/should.{be_empty, or_fail_with, should}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{
  after_all, after_each, before_all, before_each, describe, it,
}
import gleam/io

pub fn tests() {
  describe("Database tests", [
    before_all(fn() {
      // Start database once for all tests
      start_database()
    }),
    before_each(fn() {
      // Begin transaction before each test
      begin_transaction()
    }),
    it("creates a record", fn() {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Placeholder test")
    }),
    it("queries records", fn() {
      []
      |> should()
      |> be_empty()
      |> or_fail_with("Placeholder test")
    }),
    after_each(fn() {
      // Rollback transaction after each test
      rollback_transaction()
    }),
    after_all(fn() {
      // Stop database after all tests
      stop_database()
    }),
  ])
}

fn start_database() {
  Ok(Nil)
}

fn stop_database() {
  Ok(Nil)
}

fn begin_transaction() {
  Ok(Nil)
}

fn rollback_transaction() {
  Ok(Nil)
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/hooks/lifecycle_hooks.gleam)</sub>

### Hook inheritance (nested groups)

Nested groups inherit hooks. Setup runs **outer → inner**, teardown runs **inner → outer**.

```gleam
import dream_test/assertions/should.{succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{after_each, before_each, describe, group, it}
import gleam/io

pub fn tests() {
  describe("Outer", [
    before_each(fn() {
      io.println("1. outer setup")
      Ok(Nil)
    }),
    after_each(fn() {
      io.println("4. outer teardown")
      Ok(Nil)
    }),
    group("Inner", [
      before_each(fn() {
        io.println("2. inner setup")
        Ok(Nil)
      }),
      after_each(fn() {
        io.println("3. inner teardown")
        Ok(Nil)
      }),
      it("test", fn() {
        io.println("(test)")
        Ok(succeed())
      }),
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

<sub>🧪 [Tested source](../examples/snippets/test/snippets/hooks/hook_inheritance.gleam)</sub>

### Hook failure behavior (important for reliability)

If a hook fails, Dream Test records that failure and marks affected tests appropriately (e.g. setup failures).

```gleam
import dream_test/assertions/should.{succeed}
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{before_all, describe, it}
import gleam/io

fn connect_to_database() {
  Ok(Nil)
}

pub fn tests() {
  describe("Handles failures", [
    before_all(fn() {
      case connect_to_database() {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error("Database connection failed: " <> e)
      }
    }),
    // If before_all fails, these tests are marked SetupFailed (not run)
    it("test1", fn() { Ok(succeed()) }),
    it("test2", fn() { Ok(succeed()) }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/hooks/hook_failure.gleam)</sub>


