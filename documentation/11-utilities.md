## Utilities (file, process, timing, sandbox)

These modules exist because real test suites always accumulate a little infrastructure: temp files, unique ports, timing, and “run this safely.”

Rather than forcing every project to reinvent these helpers slightly differently (and slightly incorrectly), Dream Test provides small, intentionally-minimal building blocks.

### Mental model

These are small helper modules that make tests more reliable and less repetitive:

- `file`: predictable IO + structured errors (great for temp files/snapshots)
- `process`: small helpers for test isolation (counters, unique ports)
- `timing`: monotonic time + formatting
- `sandbox`: run code in an isolated process with timeout/crash reporting

Dream Test ships a few small helper modules that support testing workflows.
They’re public because they’re useful in real test suites, but they’re intentionally minimal.

### `dream_test/file` (safe filesystem helpers)

Use these helpers when you want predictable, structured error handling around file IO (snapshots, temp files, fixtures).

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/file.{NotFound, delete, error_to_string, read, write}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, it}
import gleam/int

fn tmp_path() {
  "./test/tmp/file_helpers_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn tests() {
  describe("File helpers", [
    it("write + read roundtrip", fn() {
      let path = tmp_path()
      let _ = write(path, "hello")

      read(path)
      |> should
      |> be_equal(Ok("hello"))
      |> or_fail_with("expected to read back written content")
    }),

    it("delete removes a file", fn() {
      let path = tmp_path()
      let _ = write(path, "hello")
      let _ = delete(path)

      read(path)
      |> should
      |> be_equal(Error(NotFound(path)))
      |> or_fail_with("expected deleted file to be NotFound")
    }),

    it("error_to_string formats NotFound", fn() {
      error_to_string(NotFound("/x"))
      |> should
      |> be_equal("File not found: /x")
      |> or_fail_with("expected NotFound formatting")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/utils/file_helpers.gleam)</sub>

### `dream_test/process` (small helpers for tests)

These are practical testing helpers: a simple counter and a “unique port” generator for avoiding collisions.

```gleam
import dream_test/matchers.{be_between, be_equal, or_fail_with, should}
import dream_test/process.{get_count, increment, start_counter, unique_port}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Process helpers", [
    it("start_counter + increment + get_count work", fn() {
      let counter = start_counter()
      increment(counter)
      increment(counter)

      get_count(counter)
      |> should
      |> be_equal(2)
      |> or_fail_with("expected counter to be 2")
    }),

    it("unique_port returns a value in the safe range", fn() {
      unique_port()
      |> should
      |> be_between(10_000, 60_000)
      |> or_fail_with("expected unique_port to be within 10k..60k")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/utils/process_helpers.gleam)</sub>

### `dream_test/timing` (durations + monotonic time)

Use `timing.now_ms()` / `timing.now_us()` for monotonic timing, and format helpers for readable output.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Timing", [
    it("format_duration_ms scales milliseconds and seconds", fn() {
      // Arrange & Act
      let ms = timing.format_duration_ms(42)

      // Assert
      ms
      |> should
      |> be_equal("42ms")
      |> or_fail_with("expected 42ms")
    }),

    it("format_duration_ms formats 1500ms as seconds", fn() {
      timing.format_duration_ms(1500)
      |> should
      |> be_equal("1.5s")
      |> or_fail_with("expected 1.5s")
    }),

    it("format_duration_us formats sub-millisecond values", fn() {
      timing.format_duration_us(500)
      |> should
      |> be_equal("0.5ms")
      |> or_fail_with("expected 0.5ms")
    }),

    it("now_ms is monotonic (non-decreasing)", fn() {
      let t1 = timing.now_ms()
      let t2 = timing.now_ms()
      let ok = t2 >= t1

      ok
      |> should
      |> be_equal(True)
      |> or_fail_with("expected now_ms to be monotonic")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/utils/timing_helpers.gleam)</sub>

### `dream_test/sandbox` (timeouts + crash isolation)

This is the mechanism Dream Test uses to make test execution resilient: run code in an isolated process, detect timeouts, and catch crashes.

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/unit.{describe, it}

fn loop_forever() {
  loop_forever()
}

pub fn tests() {
  describe("Sandboxing", [
    it("run_isolated returns SandboxCompleted(value) on success", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, fn() { 123 })

      result
      |> should
      |> be_equal(SandboxCompleted(123))
      |> or_fail_with("expected SandboxCompleted(123)")
    }),

    it(
      "run_isolated returns SandboxTimedOut when the function is too slow",
      fn() {
        let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
        let result = sandbox.run_isolated(config, loop_forever)

        result
        |> should
        |> be_equal(SandboxTimedOut)
        |> or_fail_with("expected SandboxTimedOut")
      },
    ),

    it("run_isolated returns SandboxCrashed when the function panics", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, fn() { panic as "boom" })

      let did_crash = case result {
        SandboxCrashed(_) -> True
        _ -> False
      }

      did_crash
      |> should
      |> be_equal(True)
      |> or_fail_with("expected SandboxCrashed(...)")
    }),
  ])
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/utils/sandboxing.gleam)</sub>

### What's Next?

- Go back to [Gherkin / BDD testing](10-gherkin-bdd.md)
- Go back to [Documentation README](README.md)
- Jump to the API reference on Hexdocs: [Dream Test on Hexdocs](https://hexdocs.pm/dream_test/)


