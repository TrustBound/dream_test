import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{SetupProcessReturned}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}

fn double(number: Int) -> Int {
  number * 2
}

fn stop(result: sandbox.SetupProcessResult(Int, Int)) -> Bool {
  case result {
    SetupProcessReturned(setup_process: setup_process, value: _) -> {
      sandbox.stop_setup_process(setup_process)
      True
    }
    _ -> False
  }
}

pub fn tests() -> TestSuite {
  describe("Setup processes", [
    it("stop_setup_process stops a setup process", fn() {
      sandbox.run_in_setup_process(None, 100, double, 21)
      |> stop
      |> should
      |> be_equal(True)
      |> or_fail_with("expected the setup process to stop")
    }),
  ])
}
