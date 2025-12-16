/// Tests for process helpers demonstrating BEAM isolation.
///
/// These tests show that:
/// - Each test gets its own isolated counter
/// - Counters don't share state across tests
/// - Spawned processes are automatically cleaned up
import dream_test/assertions/should.{
  be_at_least, be_false, be_ok, be_true, equal, or_fail_with, should,
}
import dream_test/process as test_process
import dream_test/unit.{describe, group, it}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

/// Custom message type for start_actor test
pub type AccumulatorMessage {
  Add(Int)
  GetTotal(Subject(Int))
}

pub fn tests() {
  describe("Process Helpers", [
    group("start_counter", [
      it("starts with count 0", fn(_) {
        let counter = test_process.start_counter()
        let count = test_process.get_count(counter)

        count
        |> should()
        |> equal(0)
        |> or_fail_with("Counter should start at 0")
      }),
      it("increments correctly", fn(_) {
        let counter = test_process.start_counter()

        test_process.increment(counter)
        test_process.increment(counter)
        test_process.increment(counter)

        let count = test_process.get_count(counter)

        count
        |> should()
        |> equal(3)
        |> or_fail_with("Counter should be 3 after 3 increments")
      }),
      it("decrements correctly", fn(_) {
        let counter = test_process.start_counter_with(10)

        test_process.decrement(counter)
        test_process.decrement(counter)

        let count = test_process.get_count(counter)

        count
        |> should()
        |> equal(8)
        |> or_fail_with("Counter should be 8 after 2 decrements from 10")
      }),
      it("sets value correctly", fn(_) {
        let counter = test_process.start_counter()

        test_process.set_count(counter, 42)

        let count = test_process.get_count(counter)

        count
        |> should()
        |> equal(42)
        |> or_fail_with("Counter should be 42 after set")
      }),
    ]),
    group("Counter Isolation", [
      it("test A: counter is independent (increment to 5)", fn(_) {
        // Each test gets its own counter
        let counter = test_process.start_counter()

        test_process.increment(counter)
        test_process.increment(counter)
        test_process.increment(counter)
        test_process.increment(counter)
        test_process.increment(counter)

        let count = test_process.get_count(counter)

        count
        |> should()
        |> equal(5)
        |> or_fail_with("Counter should be 5")
      }),
      it("test B: counter is independent (increment to 2)", fn(_) {
        // This runs in parallel with test A, but has its own counter
        let counter = test_process.start_counter()

        test_process.increment(counter)
        test_process.increment(counter)

        let count = test_process.get_count(counter)

        // Even though test A incremented 5 times, this counter is isolated
        count
        |> should()
        |> equal(2)
        |> or_fail_with("Counter should be 2 - isolated from test A")
      }),
      it("test C: fresh counter after previous tests", fn(_) {
        // This test runs after A and B, but gets a fresh counter
        let counter = test_process.start_counter()

        let count = test_process.get_count(counter)

        count
        |> should()
        |> equal(0)
        |> or_fail_with("Fresh counter should start at 0")
      }),
    ]),
    group("start_actor", [
      it("spawns a stateful actor with custom handler", fn(_) {
        // Note: handler receives (state, message) and returns Next(state, msg)
        let acc =
          test_process.start_actor(0, fn(total: Int, msg: AccumulatorMessage) {
            case msg {
              Add(n) -> actor.continue(total + n)
              GetTotal(reply_to) -> {
                process.send(reply_to, total)
                actor.continue(total)
              }
            }
          })

        // Add some values
        process.send(acc, Add(10))
        process.send(acc, Add(5))
        process.send(acc, Add(3))

        // Get the total using call_actor
        let total = test_process.call_actor(acc, GetTotal, 1000)

        total
        |> should()
        |> equal(18)
        |> or_fail_with("Accumulator should sum to 18")
      }),
    ]),
    group("unique_port", [
      it("generates ports in valid range", fn(_) {
        // Arrange
        let port = test_process.unique_port()

        // Act
        let ok = port >= 10_000 && port < 60_000

        // Assert
        ok
        |> should()
        |> be_true()
        |> or_fail_with("Port should be in range 10000-60000")
      }),
      it("generates different ports on subsequent calls", fn(_) {
        // Generate several ports and check they're not all the same
        let port1 = test_process.unique_port()
        let port2 = test_process.unique_port()
        let port3 = test_process.unique_port()

        // At least one should be different (extremely unlikely to get 3 same)
        let all_same = port1 == port2 && port2 == port3

        all_same
        |> should()
        |> be_false()
        |> or_fail_with("Ports should vary")
      }),
    ]),
    group("await_ready", [
      it("returns Ready immediately when condition is true", fn(_) {
        let config = test_process.PollConfig(timeout_ms: 1000, interval_ms: 10)

        // Act
        let result = test_process.await_ready(config, fn() { True })

        // Assert
        result
        |> should()
        |> equal(test_process.Ready(True))
        |> or_fail_with("Should return Ready(True) immediately")
      }),
      it("returns Ready when condition becomes true", fn(_) {
        // Use a counter to track calls - becomes true on 3rd check
        let counter = test_process.start_counter()
        let config = test_process.PollConfig(timeout_ms: 1000, interval_ms: 10)

        // Act
        let result =
          test_process.await_ready(config, fn() {
            test_process.increment(counter)
            test_process.get_count(counter) >= 3
          })

        // Assert
        result
        |> should()
        |> equal(test_process.Ready(True))
        |> or_fail_with(
          "Should return Ready(True) after condition becomes true",
        )
      }),
      it("returns TimedOut when condition never becomes true", fn(_) {
        // Very short timeout to make test fast
        let config = test_process.PollConfig(timeout_ms: 50, interval_ms: 10)

        // Act
        let result = test_process.await_ready(config, fn() { False })

        // Assert
        result
        |> should()
        |> equal(test_process.TimedOut)
        |> or_fail_with("Should return TimedOut")
      }),
    ]),
    group("await_some", [
      it("returns Ready with value when Ok is returned", fn(_) {
        let config = test_process.PollConfig(timeout_ms: 1000, interval_ms: 10)

        // Act
        let result = test_process.await_some(config, fn() { Ok(42) })

        // Assert
        result
        |> should()
        |> equal(test_process.Ready(42))
        |> or_fail_with("Should return Ready(42)")
      }),
      it("returns Ready when Ok is eventually returned", fn(_) {
        let counter = test_process.start_counter()
        let config = test_process.PollConfig(timeout_ms: 1000, interval_ms: 10)

        // Act
        let result =
          test_process.await_some(config, fn() {
            test_process.increment(counter)
            let count = test_process.get_count(counter)
            case count >= 3 {
              True -> Ok(count)
              False -> Error(Nil)
            }
          })

        let value_result = case result {
          test_process.Ready(value) -> Ok(value)
          test_process.TimedOut -> Error("TimedOut")
        }

        // Assert
        value_result
        |> should()
        |> be_ok()
        |> be_at_least(3)
        |> or_fail_with("Should return Ready(value) where value >= 3")
      }),
      it("returns TimedOut when Error is always returned", fn(_) {
        let config = test_process.PollConfig(timeout_ms: 50, interval_ms: 10)

        // Act
        let result =
          test_process.await_some(config, fn() { Error("not ready") })

        // Assert
        result
        |> should()
        |> equal(test_process.TimedOut)
        |> or_fail_with("Should return TimedOut")
      }),
    ]),
  ])
}
