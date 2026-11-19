//// One run with suites whose contexts have different types.

import dream_test/gherkin/feature.{feature, given, scenario, then}
import dream_test/gherkin/steps
import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/runner
import dream_test/types.{type Status, type TestInfo, type TestResult, Passed}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/result

pub fn tests() {
  describe("mixed suites", [
    it("runner.new runs a unit, a context and a feature suite", fn() {
      runner.new([plain_suite(), number_suite(), word_feature()])
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(full_name_and_status)
      |> should
      |> be_equal(all_passed())
      |> or_fail_with("each suite should run with its own context")
    }),

    it("add_suites adds suites with another context type", fn() {
      runner.new([plain_suite()])
      |> runner.add_suites([number_suite()])
      |> runner.add_suites_with_config(
        config: parallel.default_config(),
        suites: [word_feature()],
      )
      |> runner.silent()
      |> runner.run()
      |> types.report_tests
      |> list.map(full_name_and_status)
      |> should
      |> be_equal(all_passed())
      |> or_fail_with("added suites should keep their own context")
    }),

    it("before_each_test gets the TestInfo of a test of each suite", fn() {
      let names = process.new_subject()
      runner.new([plain_suite(), number_suite(), word_feature()])
      |> runner.max_concurrency(1)
      |> runner.before_each_test(fn(info) { send_name(names, info) })
      |> runner.silent()
      |> runner.run()
      receive_names(names, [])
      |> should
      |> be_equal(all_names())
      |> or_fail_with("the hook should get each test")
    }),

    it("after_each_test gets the TestInfo of a test of each suite", fn() {
      let names = process.new_subject()
      runner.new([plain_suite(), number_suite(), word_feature()])
      |> runner.max_concurrency(1)
      |> runner.after_each_test(fn(info) { send_name(names, info) })
      |> runner.silent()
      |> runner.run()
      receive_names(names, [])
      |> should
      |> be_equal(all_names())
      |> or_fail_with("the hook should get each test")
    }),
  ])
}

fn plain_suite() {
  describe("plain", [it("passes", fn() { Ok(succeed()) })])
}

fn number_suite() {
  unit_context.describe("number", 41, [
    unit_context.it("gets 41", check_number),
  ])
}

fn check_number(number: Int) {
  number
  |> should
  |> be_equal(41)
  |> or_fail_with("the test should get 41")
}

fn word_feature() {
  let registry =
    steps.new(initial: "")
    |> steps.given("the word {string}", set_word)
    |> steps.then("the word is {string}", check_word)
  feature("word", registry, [
    scenario("keeps a word", [
      given("the word \"dream\""),
      then("the word is \"dream\""),
    ]),
  ])
}

fn set_word(_word: String, context: steps.StepContext) {
  steps.get_string(context.captures, 0)
}

fn check_word(word: String, context: steps.StepContext) {
  use expected <- result.try(steps.get_string(context.captures, 0))
  word
  |> should
  |> be_equal(expected)
  |> or_fail_with("the scenario should keep the word")
}

fn all_passed() -> List(#(List(String), Status)) {
  list.map(all_names(), passed)
}

fn all_names() -> List(List(String)) {
  [["plain", "passes"], ["number", "gets 41"], ["word", "keeps a word"]]
}

fn passed(name: List(String)) -> #(List(String), Status) {
  #(name, Passed)
}

fn full_name_and_status(result: TestResult) -> #(List(String), Status) {
  #(types.full_name(result.groups, result.name), result.status)
}

fn send_name(names: Subject(List(String)), info: TestInfo) {
  process.send(names, types.full_name(info.groups, info.name))
  Ok(Nil)
}

fn receive_names(
  names: Subject(List(String)),
  received_rev: List(List(String)),
) -> List(List(String)) {
  case process.receive(names, 0) {
    Ok(name) -> receive_names(names, [name, ..received_rev])
    Error(Nil) -> list.reverse(received_rev)
  }
}
