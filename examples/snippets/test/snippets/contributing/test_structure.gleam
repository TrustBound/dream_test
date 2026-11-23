import dream_test/matchers.{fail_with}
import dream_test/suite.{type TestSuite}
import dream_test/types.{AssertionOk, MatchFailed, MatchOk}
import dream_test/unit.{describe, it}

pub fn tests() -> TestSuite {
  describe("Feature name", [
    it("does something when condition", fn() {
      let result = some_function()

      case result {
        MatchOk(_) -> Ok(AssertionOk)
        MatchFailed(_) -> Ok(fail_with("Expected success"))
      }
    }),
  ])
}

/// The function under test of the example. It matches, so the test
/// passes.
fn some_function() -> types.MatchResult(Int) {
  MatchOk(42)
}
