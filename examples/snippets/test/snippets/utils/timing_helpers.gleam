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
