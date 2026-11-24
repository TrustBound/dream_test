import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}

fn double(number: Int) -> Int {
  number * 2
}

pub fn tests() -> TestSuite {
  describe("run_catching", [
    it("returns the value of a function that returns", fn() {
      sandbox.run_catching(double, 61)
      |> should
      |> be_equal(Ok(122))
      |> or_fail_with("expected Ok(122)")
    }),
  ])
}
