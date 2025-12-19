import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/collection.{
  be_empty, contain, have_length, not_contain,
}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("dream_test/matchers/collection", [
    it("contain passes when the item exists", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("list should contain 2")
    }),

    it("not_contain passes when the item does not exist", fn() {
      [1, 2, 3]
      |> should
      |> not_contain(4)
      |> or_fail_with("list should not contain 4")
    }),

    it("have_length passes when the length matches", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("list should have length 3")
    }),

    it("be_empty passes for an empty list", fn() {
      []
      |> should
      |> be_empty()
      |> or_fail_with("empty list should be empty")
    }),
  ])
}
