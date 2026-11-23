import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/sandbox.{SetupProcessReturned}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{None}

fn double(number: Int) -> Int {
  number * 2
}

fn is_alive(setup_process: sandbox.SetupProcess(Int, Int)) -> Bool {
  case sandbox.check_setup_process(setup_process) {
    Ok(_setup_process) -> True
    Error(_reason) -> False
  }
}

fn still_alive(result: sandbox.SetupProcessResult(Int, Int)) -> Bool {
  case result {
    SetupProcessReturned(setup_process: setup_process, value: _) -> {
      let alive = is_alive(setup_process)
      sandbox.stop_setup_process(setup_process)
      alive
    }
    _ -> False
  }
}

pub fn tests() -> TestSuite {
  describe("Setup processes", [
    it("check_setup_process gives back a setup process that is alive", fn() {
      sandbox.run_in_setup_process(None, 100, double, 21)
      |> still_alive
      |> should
      |> be_equal(True)
      |> or_fail_with("expected the setup process to be alive")
    }),
  ])
}
