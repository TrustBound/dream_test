## Utilities (file, process, timing, sandbox)

These modules exist because real test suites always accumulate a little infrastructure: temp files, unique ports, timing, and “run this safely.”

Rather than forcing every project to reinvent these helpers slightly differently (and slightly incorrectly), Dream Test provides small, intentionally-minimal building blocks.

### Mental model

These are small helper modules that make tests more reliable and less repetitive:

- `file`: predictable IO + structured errors (great for temp files/snapshots)
- `process`: small helpers for tests (counters, random ports, actors, polling)
- `timing`: monotonic time + formatting
- `sandbox`: run code in an isolated process with timeout/crash reporting

### `dream_test/file` (safe filesystem helpers)

Use these helpers when you want predictable, structured error handling around file IO (snapshots, temp files, fixtures).

#### File helpers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/file_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file.{
  NotFound, delete, delete_files_matching, error_to_string, read, write,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/result

fn tmp_path() {
  "./test/tmp/file_helpers_" <> int.to_string(unique_port()) <> ".txt"
}

pub fn tests() {
  describe("File helpers", [
    it("write + read roundtrip", fn() {
      let path = tmp_path()

      // Setup: create the file (no assertions during setup)
      use _ <- result.try(
        write(path, "hello") |> result.map_error(error_to_string),
      )

      read(path)
      |> should
      |> be_equal(Ok("hello"))
      |> or_fail_with("expected to read back written content")
    }),

    it("delete removes a file", fn() {
      let path = tmp_path()

      // Setup: create the file, then delete it (no assertions during setup)
      use _ <- result.try(
        write(path, "hello") |> result.map_error(error_to_string),
      )
      use _ <- result.try(delete(path) |> result.map_error(error_to_string))

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

    it("delete_files_matching deletes files with a given extension", fn() {
      let directory = "./test/tmp/file_helpers_" <> int.to_string(unique_port())
      let a = directory <> "/a.snap"
      let b = directory <> "/b.snap"
      let keep = directory <> "/keep.txt"

      // Setup: create 2 matching files and 1 non-matching file
      use _ <- result.try(write(a, "a") |> result.map_error(error_to_string))
      use _ <- result.try(write(b, "b") |> result.map_error(error_to_string))
      use _ <- result.try(
        write(keep, "keep") |> result.map_error(error_to_string),
      )

      delete_files_matching(directory, ".snap")
      |> should
      |> be_equal(Ok(2))
      |> or_fail_with("expected two deleted snapshots")
    }),
  ])
}
```

### `dream_test/process` (small helpers for tests)

These are practical testing helpers: a simple counter and a random port. `unique_port` gives a random port from 10,000 to 59,999. It does not check that the port is free, and two calls can give the same port, so it makes a collision unlikely, not impossible.

#### Counter and port helpers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/process_counter_and_port.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

The module has more helpers. See [`dream_test/process` on HexDocs](https://hexdocs.pm/dream_test/dream_test/process.html):

- `start_counter_with`, `decrement` and `set_count`: more counter control
- `start_actor` and `call_actor`: start an actor that is linked to the test, and call it
- `await_ready` and `await_some`: poll a check until it gives a value or a timeout, with `default_poll_config` or `quick_poll_config`

### `dream_test/timing` (durations + monotonic time)

Use `timing.now_ms()` / `timing.now_us()` for monotonic timing, and format helpers for readable output.

#### Timing helpers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/timing_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

    it("now_us is monotonic (non-decreasing)", fn() {
      let t1 = timing.now_us()
      let t2 = timing.now_us()
      let ok = t2 >= t1

      ok
      |> should
      |> be_equal(True)
      |> or_fail_with("expected now_us to be monotonic")
    }),
  ])
}
```

### `dream_test/sandbox` (timeouts + crash isolation)

This is the mechanism Dream Test uses to make test execution resilient: run code in an isolated process, detect timeouts, and catch crashes.

#### Sandboxed functions <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/utils/sandboxing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{
  SandboxCompleted, SandboxConfig, SandboxCrashed, SandboxTimedOut,
}
import dream_test/unit.{describe, it}

fn double(number: Int) -> Int {
  number * 2
}

fn loop_forever(_input: Nil) -> Nil {
  loop_forever(Nil)
}

fn crash(message: String) -> Int {
  panic as message
}

pub fn tests() {
  describe("Sandboxing", [
    it("run_isolated returns SandboxCompleted(value) on success", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, double, 61)

      result
      |> should
      |> be_equal(SandboxCompleted(122))
      |> or_fail_with("expected SandboxCompleted(122)")
    }),

    it(
      "run_isolated returns SandboxTimedOut when the function is too slow",
      fn() {
        let config = SandboxConfig(timeout_ms: 10, show_crash_reports: False)
        let result = sandbox.run_isolated(config, loop_forever, Nil)

        result
        |> should
        |> be_equal(SandboxTimedOut)
        |> or_fail_with("expected SandboxTimedOut")
      },
    ),

    it("run_isolated returns SandboxCrashed when the function panics", fn() {
      let config = SandboxConfig(timeout_ms: 100, show_crash_reports: False)
      let result = sandbox.run_isolated(config, crash, "boom")

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

The module has more functions. See [`dream_test/sandbox` on HexDocs](https://hexdocs.pm/dream_test/dream_test/sandbox.html):

- `run_catching`: run a function in the calling process, and give a crash as an `Error`
- `default_config` and `with_crash_reports`: a `SandboxConfig` with the default timeout, and one that shows crash reports
- `run_in_setup_process`, `check_setup_process` and `stop_setup_process`: run functions one after another in a process that stays alive, as the runner does for a setup and its teardown
- `kill_and_wait` and `format_exit_reason`: stop a process and wait for its exit, and give an exit reason as text

### What's Next?

- Go back to [Gherkin / BDD testing](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md)
- Go on to [Coverage](https://github.com/TrustBound/dream_test/blob/main/docs/guides/coverage.md)
- Go back to [Documentation README](https://github.com/TrustBound/dream_test/blob/main/docs/guides/index.md)
- Jump to the API reference on Hexdocs: [Dream Test on Hexdocs](https://hexdocs.pm/dream_test/)

