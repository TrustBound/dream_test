import dream_test/matchers.{succeed}
import dream_test/parallel.{type RunTreeParallelWithReporterResult}
import dream_test/suite.{RunInput}
import dream_test/unit.{describe, it}
import gleam/option.{None}

pub fn run_one_suite() -> RunTreeParallelWithReporterResult {
  let cart_suite =
    describe("Cart", [
      it("starts empty", fn() { Ok(succeed()) }),
    ])
  suite.run(
    suite: cart_suite,
    input: RunInput(
      config: parallel.default_config(),
      keep: None,
      progress_reporter: None,
      write: ignore_output,
      total: 1,
      completed: 0,
      before_each_test: [],
      after_each_test: [],
      outer_setups: [],
    ),
  )
}

fn ignore_output(_text: String) -> Nil {
  Nil
}
