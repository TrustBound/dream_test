import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type TestInfo}
import dream_test/unit.{describe, it}
import gleam/io
import gleam/option.{None}
import gleam/string

pub fn tests() {
  describe("Test labels", [
    it("joins the group names and the test name", fn() {
      types.TestInfo(
        name: "adds",
        groups: ["Cart", "add"],
        tags: [],
        kind: types.Unit,
        source: None,
      )
      |> test_label
      |> should
      |> be_equal("Cart > add > adds")
      |> or_fail_with("expected the full test name")
    }),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.before_each_test(before_each_test_hook)
  |> runner.run()
}

fn before_each_test_hook(info: TestInfo) -> Result(Nil, String) {
  io.println("test: " <> test_label(info))
  Ok(Nil)
}

fn test_label(info: TestInfo) -> String {
  types.full_name(info.groups, info.name)
  |> string.join(" > ")
}
