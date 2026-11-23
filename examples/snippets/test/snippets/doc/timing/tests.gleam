import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/timing/format_duration_ms
import snippets/doc/timing/format_duration_us
import snippets/doc/timing/module
import snippets/doc/timing/now_ms
import snippets/doc/timing/now_us

pub fn tests() {
  describe("Doc examples: timing", [
    it("formats_one_and_a_half_seconds passes", fn() {
      // Act
      let result = module.formats_one_and_a_half_seconds()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected formats_one_and_a_half_seconds to pass")
    }),
    it("formats_forty_two_milliseconds passes", fn() {
      // Act
      let result = format_duration_ms.formats_forty_two_milliseconds()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected formats_forty_two_milliseconds to pass")
    }),
    it("formats_half_a_millisecond passes", fn() {
      // Act
      let result = format_duration_us.formats_half_a_millisecond()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected formats_half_a_millisecond to pass")
    }),
    it("now_ms_never_goes_back passes", fn() {
      // Act
      let result = now_ms.now_ms_never_goes_back()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected now_ms_never_goes_back to pass")
    }),
    it("now_us_never_goes_back passes", fn() {
      // Act
      let result = now_us.now_us_never_goes_back()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected now_us_never_goes_back to pass")
    }),
  ])
}
