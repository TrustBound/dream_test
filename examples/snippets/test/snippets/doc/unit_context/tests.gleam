import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/types.{type Status, type TestResult, Passed, Pending, Skipped}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import snippets/doc/unit_context/before_all as before_all_example
import snippets/doc/unit_context/before_each as before_each_example
import snippets/doc/unit_context/describe as describe_example
import snippets/doc/unit_context/group as group_example
import snippets/doc/unit_context/pending as pending_example
import snippets/doc/unit_context/skip as skip_example
import snippets/doc/unit_context/with_tags as with_tags_example
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
  describe("Doc examples: unit_context", [
    it_runs_in_child_vm(
      "after_each main closes the session after the test",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/unit_context/after_each", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "closing session-1\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected after_each to close the session once")
      },
    ),
    it_runs_in_child_vm("after_all main stops the pool once", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit_context/after_all", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(status: 0, output: "stopping pool-1\n", error_output: "")),
      )
      |> or_fail_with("expected after_all to stop the pool once")
    }),
    it("before_all.suite passes with the loaded prices", fn() {
      // Act
      let result = statuses(before_all_example.suite())

      // Assert
      result
      |> should
      |> be_equal([#(["Price list", "has three prices"], Passed)])
      |> or_fail_with("expected the test to see the prices of before_all")
    }),
    it("before_each.suite passes both tests with a new count", fn() {
      // Act
      let result = statuses(before_each_example.suite())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Counter", "starts at one"], Passed),
        #(["Counter", "starts at one again"], Passed),
      ])
      |> or_fail_with("expected each test to start at one")
    }),
    it_runs_in_child_vm("describe main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit_context/describe", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(1)
            <> "Context-aware suite\n"
            <> "  ✓ receives the updated context\n"
            <> "\n"
            <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
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
        snippets_child_vm.run("snippets/doc/unit_context/group", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "Context-aware grouping\n"
            <> "  ✓ sees only outer hook\n"
            <> "  inner group\n"
            <> "    ✓ sees both outer + inner hooks\n"
            <> "\n"
            <> "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
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
        snippets_child_vm.run("snippets/doc/unit_context/skip", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(2)
            <> "Skipping context-aware tests\n"
            <> "  - this test is skipped\n"
            <> "  ✓ normal tests still run\n"
            <> "\n"
            <> "Summary: 2 run, 0 failed, 1 passed, 1 skipped in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the skip main to print the report of its tests")
    }),
    it_runs_in_child_vm("with_tags main prints the report of its tests", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/unit_context/with_tags", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(3)
            <> "Tagging context-aware tests\n"
            <> "  ✓ can tag an individual test\n"
            <> "  ✓ untagged tests still work\n"
            <> "  group tagged slow\n"
            <> "    ✓ inherits the group tag\n"
            <> "\n"
            <> "Summary: 3 run, 0 failed, 3 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with(
        "expected the with_tags main to print the report of its tests",
      )
    }),
    it("describe.suite passes with the updated context", fn() {
      // Act
      let result = statuses(describe_example.suite())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Context-aware suite", "receives the updated context"], Passed),
      ])
      |> or_fail_with("expected the context test to pass")
    }),
    it("group.suite passes with outer and inner hooks", fn() {
      // Act
      let result = statuses(group_example.suite())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Context-aware grouping", "sees only outer hook"], Passed),
        #(
          [
            "Context-aware grouping",
            "inner group",
            "sees both outer + inner hooks",
          ],
          Passed,
        ),
      ])
      |> or_fail_with("expected both grouping tests to pass")
    }),
    it("skip.suite skips one test and passes the other", fn() {
      // Act
      let result = statuses(skip_example.suite())

      // Assert
      result
      |> should
      |> be_equal([
        #(["Skipping context-aware tests", "this test is skipped"], Skipped),
        #(["Skipping context-aware tests", "normal tests still run"], Passed),
      ])
      |> or_fail_with("expected one skipped test")
    }),
    it("with_tags.suite gives each test its tags", fn() {
      // Act
      let result =
        run_silently(with_tags_example.suite())
        |> list.map(fn(test_result) { #(test_result.name, test_result.tags) })

      // Assert
      result
      |> should
      |> be_equal([
        #("can tag an individual test", ["unit_context", "fast"]),
        #("untagged tests still work", []),
        #("inherits the group tag", ["slow"]),
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
