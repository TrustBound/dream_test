// ❌ Bad: Redundant alias
import dream_test/matchers as should
import dream_test/unit.{describe, it}

pub fn tests() {
  describe("STANDARDS.md rule 7, Bad: a redundant alias", [
    it("works, but every matcher needs the prefix", fn() {
      1 + 1
      |> should.should
      |> should.be_equal(2)
      |> should.or_fail_with("1 + 1 should be 2")
    }),
  ])
}
