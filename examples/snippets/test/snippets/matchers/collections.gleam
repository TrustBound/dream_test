import dream_test/matchers.{
  be_empty, contain, have_length, not_contain, or_fail_with, should,
}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("Matchers: collections", [
    it("have_length checks the length of a list", fn() {
      [1, 2, 3]
      |> should
      |> have_length(3)
      |> or_fail_with("expected list length 3")
    }),
    it("contain passes when the item is present", fn() {
      [1, 2, 3]
      |> should
      |> contain(2)
      |> or_fail_with("expected list to contain 2")
    }),
    it("not_contain passes when the item is absent", fn() {
      ["a", "b", "c"]
      |> should
      |> not_contain("d")
      |> or_fail_with("expected list to not contain \"d\"")
    }),
    it("be_empty passes for an empty list", fn() {
      []
      |> should
      |> be_empty()
      |> or_fail_with("expected empty list")
    }),
  ])
}
