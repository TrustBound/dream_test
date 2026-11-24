import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, Passed}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/doc/context/setup as setup_example
import snippets/doc/context/value as value_example

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
  describe("Doc examples: context", [
    it("value.cart_suite passes with the fixed context", fn() {
      // Act
      let result = statuses(value_example.cart_suite())

      // Assert
      result
      |> should
      |> be_equal([#(["Cart", "starts empty"], Passed)])
      |> or_fail_with("expected the cart test to pass")
    }),
    it("setup.server_suite passes with the setup context", fn() {
      // Act
      let result = statuses(setup_example.server_suite())

      // Assert
      result
      |> should
      |> be_equal([#(["Server", "answers a ping"], Passed)])
      |> or_fail_with("expected the server test to pass")
    }),
  ])
}
