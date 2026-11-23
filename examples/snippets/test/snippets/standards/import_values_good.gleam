// ✅ Good: Unqualified for pipe-friendly DSL
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("STANDARDS.md rule 7, Good: unqualified DSL imports", [
    it("reads well in a pipe", fn() {
      1 + 1
      |> should
      |> be_equal(2)
      |> or_fail_with("1 + 1 should be 2")
    }),
  ])
}
