import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/timing
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn tests() {
  describe("dream_test/timing", [
    it("format_duration_ms formats common ranges", fn() {
      timing.format_duration_ms(0)
      |> should
      |> be_equal("0ms")
      |> or_fail_with("0ms should format as 0ms")
    }),

    it("format_duration_us formats common ranges", fn() {
      timing.format_duration_us(500)
      |> should
      |> be_equal("0.5ms")
      |> or_fail_with("500us should format as 0.5ms")
    }),

    it("now_ms is monotonic", fn() {
      let a = timing.now_ms()
      let b = timing.now_ms()
      case b >= a {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "now_ms",
              message: "expected now_ms to be monotonic",
              payload: None,
            )),
          )
      }
    }),

    it("now_us is monotonic", fn() {
      let a = timing.now_us()
      let b = timing.now_us()
      case b >= a {
        True -> Ok(types.AssertionOk)
        False ->
          Ok(
            types.AssertionFailed(types.AssertionFailure(
              operator: "now_us",
              message: "expected now_us to be monotonic",
              payload: None,
            )),
          )
      }
    }),
  ])
}
