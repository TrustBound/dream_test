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

    it("format_duration_us formats a negative duration as zero", fn() {
      timing.format_duration_us(-500)
      |> should
      |> be_equal("0.0ms")
      |> or_fail_with("-500us should format as 0.0ms")
    }),

    it("format_duration_us formats a negative duration over 1ms as zero", fn() {
      timing.format_duration_us(-1500)
      |> should
      |> be_equal("0.0ms")
      |> or_fail_with("-1500us should format as 0.0ms")
    }),

    it("format_duration_ms formats a duration in minutes and seconds", fn() {
      timing.format_duration_ms(90_000)
      |> should
      |> be_equal("1m 30s")
      |> or_fail_with("90_000 should format as 1m 30s")
    }),

    it("format_duration_ms formats a duration in whole minutes", fn() {
      timing.format_duration_ms(120_000)
      |> should
      |> be_equal("2m")
      |> or_fail_with("120_000 should format as 2m")
    }),

    it("format_duration_ms formats a duration in hours and minutes", fn() {
      timing.format_duration_ms(5_400_000)
      |> should
      |> be_equal("1h 30m")
      |> or_fail_with("5_400_000 should format as 1h 30m")
    }),

    it("format_duration_ms formats a duration in whole hours", fn() {
      timing.format_duration_ms(3_600_000)
      |> should
      |> be_equal("1h")
      |> or_fail_with("3_600_000 should format as 1h")
    }),

    it(
      "format_duration_us formats a duration over 1ms with the ms format",
      fn() {
        timing.format_duration_us(1_500_000)
        |> should
        |> be_equal("1.5s")
        |> or_fail_with("1_500_000 should format as 1.5s")
      },
    ),

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
