import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it, pending}

pub fn tests() {
  describe("Cart", [
    it("starts empty", fn() {
      []
      |> should
      |> be_equal([])
      |> or_fail_with("a new cart should be empty")
    }),
    pending("adds an item"),
    pending("removes an item"),
  ])
}
