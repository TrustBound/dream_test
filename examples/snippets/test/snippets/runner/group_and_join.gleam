import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type TestResult}
import dream_test/unit.{describe, it}
import dream_test/unit_context
import gleam/list

fn cart_suite() -> TestSuite {
  describe("Cart", [it("starts empty", fn() { Ok(succeed()) })])
}

fn stock_suite() -> TestSuite {
  unit_context.describe("Stock", 3, [
    unit_context.it("has 3 items", fn(items: Int) {
      items
      |> should
      |> be_equal(3)
      |> or_fail_with("the stock should have 3 items")
    }),
  ])
}

/// Each suite becomes a group inside "Shop".
pub fn grouped() -> TestSuite {
  suite.group(name: "Shop", suites: [cart_suite(), stock_suite()])
}

/// One suite named "Shop" that holds both suites as they are.
pub fn joined() -> TestSuite {
  suite.join(name: "Shop", suites: [cart_suite(), stock_suite()])
}

fn full_names(suites: List(TestSuite)) -> List(List(String)) {
  runner.new(suites)
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
  |> list.map(full_name)
}

fn full_name(result: TestResult) -> List(String) {
  types.full_name(result.groups, result.name)
}

pub fn tests() {
  describe("suite.group and suite.join", [
    it("group adds the group name to each test", fn() {
      full_names([grouped()])
      |> should
      |> be_equal([
        ["Shop", "Cart", "starts empty"],
        ["Shop", "Stock", "has 3 items"],
      ])
      |> or_fail_with("expected the group name first")
    }),
    it("join keeps the names of each test", fn() {
      full_names([joined()])
      |> should
      |> be_equal([["Cart", "starts empty"], ["Stock", "has 3 items"]])
      |> or_fail_with("expected the names of the suites")
    }),
  ])
}
