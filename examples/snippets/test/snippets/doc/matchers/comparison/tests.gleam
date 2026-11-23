import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import snippets/doc/matchers/comparison/be_at_least
import snippets/doc/matchers/comparison/be_at_most
import snippets/doc/matchers/comparison/be_between
import snippets/doc/matchers/comparison/be_greater_than
import snippets/doc/matchers/comparison/be_greater_than_float
import snippets/doc/matchers/comparison/be_in_range
import snippets/doc/matchers/comparison/be_less_than
import snippets/doc/matchers/comparison/be_less_than_float

pub fn tests() {
  describe("Doc examples: matchers/comparison", [
    it("ten_is_greater_than_zero passes", fn() {
      // Act
      let result = be_greater_than.ten_is_greater_than_zero()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ten_is_greater_than_zero to pass")
    }),
    it("ten_is_less_than_one_hundred passes", fn() {
      // Act
      let result = be_less_than.ten_is_less_than_one_hundred()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ten_is_less_than_one_hundred to pass")
    }),
    it("ten_is_at_least_ten passes", fn() {
      // Act
      let result = be_at_least.ten_is_at_least_ten()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ten_is_at_least_ten to pass")
    }),
    it("ten_is_at_most_ten passes", fn() {
      // Act
      let result = be_at_most.ten_is_at_most_ten()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ten_is_at_most_ten to pass")
    }),
    it("five_is_between_one_and_ten passes", fn() {
      // Act
      let result = be_between.five_is_between_one_and_ten()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected five_is_between_one_and_ten to pass")
    }),
    it("ten_is_in_range_zero_to_one_hundred passes", fn() {
      // Act
      let result = be_in_range.ten_is_in_range_zero_to_one_hundred()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected ten_is_in_range_zero_to_one_hundred to pass")
    }),
    it("half_is_greater_than_zero passes", fn() {
      // Act
      let result = be_greater_than_float.half_is_greater_than_zero()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected half_is_greater_than_zero to pass")
    }),
    it("half_is_less_than_one passes", fn() {
      // Act
      let result = be_less_than_float.half_is_less_than_one()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected half_is_less_than_one to pass")
    }),
  ])
}
