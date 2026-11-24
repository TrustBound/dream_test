//// A test module whose `tests()` returns a `unit_context` suite with the
//// context 41, for discovery. Its test passes only when it gets 41.

import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit_context.{describe, it}

pub fn tests() {
  describe("context_suite", context.value(41), [
    it("gets the context", check_context),
  ])
}

fn check_context(context: Int) {
  context
  |> should
  |> be_equal(41)
  |> or_fail_with("the test should get the context 41")
}
