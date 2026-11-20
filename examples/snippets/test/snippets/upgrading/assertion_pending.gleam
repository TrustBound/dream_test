import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{
  type AssertionResult, type Status, AssertionFailed, AssertionOk,
  AssertionPending, AssertionSkipped, Failed, Passed, Pending, Skipped,
}
import dream_test/unit.{describe, it}

pub fn status_of(result: AssertionResult) -> Status {
  case result {
    AssertionOk -> Passed
    AssertionFailed(_) -> Failed
    AssertionSkipped -> Skipped
    AssertionPending -> Pending
  }
}

pub fn tests() -> TestSuite {
  describe("AssertionPending", [
    it("is the result of a pending test", fn() {
      status_of(AssertionPending)
      |> should
      |> be_equal(Pending)
      |> or_fail_with("expected the status Pending")
    }),
  ])
}
