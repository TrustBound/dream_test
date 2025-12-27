import dream_test/matchers.{or_fail_with, should}
import dream_test/matchers/option as option_matcher
import dream_test/unit.{describe, it}
import gleam/option.{None, Some}

pub fn tests() {
  describe("dream_test/matchers/option", [
    it("be_some passes for Some", fn() {
      Some(123)
      |> should
      |> option_matcher.be_some()
      |> or_fail_with("Some(123) should be some")
    }),

    it("be_none passes for None", fn() {
      None
      |> should
      |> option_matcher.be_none()
      |> or_fail_with("None should be none")
    }),
  ])
}
