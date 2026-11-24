import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{SetupProcessReturned}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}

fn double(number: Int) -> Int {
  number * 2
}

fn value(result: sandbox.SetupProcessResult(Int, Int)) -> Result(Int, Nil) {
  case result {
    SetupProcessReturned(setup_process: setup_process, value: value) -> {
      sandbox.stop_setup_process(setup_process)
      Ok(value)
    }
    _ -> Error(Nil)
  }
}

pub fn tests() -> TestSuite {
  describe("Setup processes", [
    it("run_in_setup_process returns the value of the function", fn() {
      sandbox.run_in_setup_process(None, 100, double, 21)
      |> value
      |> should
      |> be_equal(Ok(42))
      |> or_fail_with("expected Ok(42)")
    }),
  ])
}
