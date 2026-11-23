import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, type TestResult, Passed, Pending, Skipped}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import snippets/doc/unit/before_all as before_all_example
import snippets/doc/unit/describe as describe_example
import snippets/doc/unit/group as group_example
import snippets/doc/unit/pending as pending_example
import snippets/doc/unit/skip as skip_example
import snippets/doc/unit/with_tags as with_tags_example
import snippets_child_vm.{ChildRun, it_runs_in_child_vm, progress_done_line}

fn run_silently(suite: TestSuite) -> List(TestResult) {
  runner.new([suite])
  |> runner.silent()
  |> runner.run()
  |> types.report_tests
}

fn statuses(suite: TestSuite) -> List(#(List(String), Status)) {
  run_silently(suite)
  |> list.map(fn(result) {
    #(types.full_name(result.groups, result.name), result.status)
  })
}

pub fn tests() -> TestSuite {
  describe("Doc examples: unit", [
    it_runs_in_child_vm("describe main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit/describe", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "String utilities\n"
            <> "  ✓ trims whitespace\n"
            <> "  ✓ finds substrings\n"
            <> "\n"
            <> "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with(
        "expected the describe main to print the report of its tests",
      )
    }),
    it_runs_in_child_vm("group main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit/group", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(3)
            <> "Calculator\n"
            <> "  addition\n"
            <> "    ✓ adds small numbers\n"
            <> "    ✓ adds negative numbers\n"
            <> "  division\n"
            <> "    ✓ integer division rounds toward zero\n"
            <> "\n"
            <> "Summary: 3 run, 0 failed, 3 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with(
        "expected the group main to print the report of its tests",
      )
    }),
    it_runs_in_child_vm("skip main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit/skip", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(3)
            <> "Skipping tests\n"
            <> "  ✓ runs normally\n"
            <> "  - not implemented yet\n"
            <> "  ✓ also runs normally\n"
            <> "\n"
            <> "Summary: 3 run, 0 failed, 2 passed, 1 skipped in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the skip main to print the report of its tests")
    }),
    it_runs_in_child_vm("before_all main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit/before_all", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "Database tests\n"
            <> "  ✓ creates a record\n"
            <> "  ✓ queries records\n"
            <> "\n"
            <> "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with(
        "expected the before_all main to print the report of its tests",
      )
    }),
    it_runs_in_child_vm("with_tags main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit/with_tags", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "Tagged tests\n"
            <> "  ✓ fast\n"
            <> "  ✓ slow\n"
            <> "\n"
            <> "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with(
        "expected the with_tags main to print the report of its tests",
      )
    }),
    it("describe.tests passes both tests", fn() {
      // Act
      let result = statuses(describe_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(["String utilities", "trims whitespace"], Passed),
        #(["String utilities", "finds substrings"], Passed),
      ])
      |> or_fail_with("expected both string tests to pass")
    }),
    it("group.tests passes the tests of both groups", fn() {
      // Act
      let result = statuses(group_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Calculator", "addition", "adds small numbers"], Passed),
        #(["Calculator", "addition", "adds negative numbers"], Passed),
        #(
          ["Calculator", "division", "integer division rounds toward zero"],
          Passed,
        ),
      ])
      |> or_fail_with("expected the calculator tests to pass")
    }),
    it("skip.tests skips one test and passes the others", fn() {
      // Act
      let result = statuses(skip_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Skipping tests", "runs normally"], Passed),
        #(["Skipping tests", "not implemented yet"], Skipped),
        #(["Skipping tests", "also runs normally"], Passed),
      ])
      |> or_fail_with("expected one skipped test")
    }),
    it("before_all.tests passes both tests with all hooks", fn() {
      // Act
      let result = statuses(before_all_example.tests())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Database tests", "creates a record"], Passed),
        #(["Database tests", "queries records"], Passed),
      ])
      |> or_fail_with("expected both database tests to pass")
    }),
    it("with_tags.tests gives each test its tags", fn() {
      // Act
      let result =
        run_silently(with_tags_example.tests())
        |> list.map(fn(test_result) { #(test_result.name, test_result.tags) })

      // Assert
      result
      |> should
      |> be_equal([
        #("fast", ["unit", "fast"]),
        #("slow", ["integration", "slow"]),
      ])
      |> or_fail_with("expected the tags of each test")
    }),
    it("pending.cart_suite has one passed and two pending tests", fn() {
      // Act
      let result = statuses(pending_example.cart_suite())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Cart", "adds an item"], Passed),
        #(["Cart", "removes an item"], Pending),
        #(["Cart", "empties the cart"], Pending),
      ])
      |> or_fail_with("expected two pending tests")
    }),
  ])
}
