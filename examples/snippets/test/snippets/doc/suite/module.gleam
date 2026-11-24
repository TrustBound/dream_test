import dream_test/context
import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps.{type StepContext}
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type AssertionResult, type RunReport}
import dream_test/unit
import dream_test/unit_context

fn plain_suite() -> TestSuite {
  unit.describe("Plain", [unit.it("passes", fn() { Ok(succeed()) })])
}

fn number_suite() -> TestSuite {
  unit_context.describe("Numbers", context.value(41), [
    unit_context.it("is 41", fn(number: Int) {
      number
      |> should
      |> be_equal(41)
      |> or_fail_with("expected 41")
    }),
  ])
}

fn set_word(_word: String, _context: StepContext) -> Result(String, String) {
  Ok("hello")
}

fn check_word(
  word: String,
  _context: StepContext,
) -> Result(AssertionResult, String) {
  word
  |> should
  |> be_equal("hello")
  |> or_fail_with("expected hello")
}

fn word_feature() -> TestSuite {
  let steps =
    steps.new(initial: "")
    |> steps.given("the word hello", set_word)
    |> steps.then("the word is hello", check_word)

  feature("Words", steps, [
    scenario("Keeping a word", [
      given("the word hello"),
      then("the word is hello"),
    ]),
  ])
}

pub fn run_all_suites() -> RunReport {
  runner.new([plain_suite(), number_suite(), word_feature()])
  |> runner.run()
}
