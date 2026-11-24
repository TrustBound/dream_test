import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/option.{Some}
import snippets/doc/suite/from_tree as from_tree_example
import snippets/doc/suite/group as group_example
import snippets/doc/suite/join as join_example
import snippets/doc/suite/module as module_example
import snippets/doc/suite/name as name_example
import snippets/doc/suite/new as new_example
import snippets/doc/suite/run as run_example
import snippets/doc/suite/tests_of_suite as tests_of_suite_example
import snippets/doc/suite/with_source as with_source_example

fn statuses(suite: TestSuite) -> List(#(List(String), Status)) {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
  |> list.map(fn(result) {
    #(types.full_name(result.groups, result.name), result.status)
  })
}

pub fn tests() -> TestSuite {
  describe("Doc examples: suite", [
    it("run_one_suite runs the test of the suite", fn() {
      // Act
      let result = run_example.run_one_suite()

      // Assert
      #(
        list.map(result.results, fn(test_result) {
          #(test_result.name, test_result.status)
        }),
        result.hook_failures,
        result.completed,
      )
      |> should
      |> be_equal(#([#("starts empty", Passed)], [], 1))
      |> or_fail_with("expected one passed test and a count of one")
    }),
    it("module.run_all_suites passes the test of each suite", fn() {
      // Act
      let result =
        module_example.run_all_suites()
        |> types.report_tests
        |> list.map(fn(test_result) { #(test_result.name, test_result.status) })

      // Assert
      result
      |> should
      |> be_equal([
        #("passes", Passed),
        #("is 41", Passed),
        #("Keeping a word", Passed),
      ])
      |> or_fail_with("expected the three suites to pass")
    }),
    it("from_tree.numbers_suite passes with the context 41", fn() {
      // Act
      let result = statuses(from_tree_example.numbers_suite())

      // Assert
      result
      |> should
      |> be_equal([#(["numbers", "is 41"], Passed)])
      |> or_fail_with("expected the numbers test to pass")
    }),
    it("new.server_suite passes with the setup context", fn() {
      // Act
      let result = statuses(new_example.server_suite())

      // Assert
      result
      |> should
      |> be_equal([#(["server", "answers"], Passed)])
      |> or_fail_with("expected the server test to pass")
    }),
    it("name.cart_name is Cart", fn() {
      // Act
      let result = name_example.cart_name()

      // Assert
      result
      |> should
      |> be_equal("Cart")
      |> or_fail_with("expected the name Cart")
    }),
    it("tests_of_suite.cart_test_names lists the test names", fn() {
      // Act
      let result = tests_of_suite_example.cart_test_names()

      // Assert
      result
      |> should
      |> be_equal(["is empty"])
      |> or_fail_with("expected the test is empty")
    }),
    it("group.all_suites puts all in front of each test", fn() {
      // Act
      let result = statuses(group_example.all_suites())

      // Assert
      result
      |> should
      |> be_equal([
        #(["all", "Plain", "passes"], Passed),
        #(["all", "Numbers", "is 41"], Passed),
      ])
      |> or_fail_with("expected the group name first")
    }),
    it("join.checkout_suite keeps the names of each test", fn() {
      // Act
      let result = statuses(join_example.checkout_suite())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Cart", "starts empty"], Passed),
        #(["Payment", "takes a card"], Passed),
      ])
      |> or_fail_with("expected the names of the joined suites")
    }),
    it("with_source.cart_suite_with_source sets the source", fn() {
      // Act
      let result =
        suite.tests(with_source_example.cart_suite_with_source())
        |> list.map(fn(info) { info.source })

      // Assert
      result
      |> should
      |> be_equal([Some("cart_test")])
      |> or_fail_with("expected the source cart_test")
    }),
  ])
}
