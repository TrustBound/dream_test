import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import gleam/result
import snippets/doc/reporters/bdd/format
import snippets/doc/reporters/bdd/format_incremental
import snippets/doc/reporters/bdd/format_incremental_parts_with_test_indent
import snippets/doc/reporters/bdd/format_incremental_with_test_indent
import snippets/doc/reporters/bdd/format_summary_only
import snippets/doc/reporters/bdd/render
import snippets/doc/reporters/bdd/report
import snippets_child_vm.{ChildRun, it_runs_in_child_vm}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/bdd", [
    it_runs_in_child_vm("new main prints the bdd report", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/bdd/new", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "Cart\n"
            <> "  ✓ starts empty\n"
            <> "\n"
            <> "Summary: 1 run, 0 failed, 1 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the bdd report of the cart suite")
    }),
    it_runs_in_child_vm("color main prints the bdd report in colour", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/bdd/color", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "\u{001b}[1m\u{001b}[36mCart\u{001b}[0m\u{001b}[0m\n"
            <> "  \u{001b}[32m✓\u{001b}[0m starts empty\n"
            <> "\n"
            <> "\u{001b}[1m\u{001b}[36mSummary: \u{001b}[0m\u{001b}[0m\u{001b}[36m1\u{001b}[0m run, \u{001b}[31m0\u{001b}[0m failed, \u{001b}[32m1\u{001b}[0m passed in \u{001b}[36m<duration>\u{001b}[0m\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the coloured bdd report of the cart suite")
    }),
    it_runs_in_child_vm("summary_only main prints only the summary line", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/reporters/bdd/summary_only", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "Summary: 2 run, 0 failed, 2 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected only the summary line")
    }),
    it_runs_in_child_vm("failures_only main prints only the failed test", fn() {
      // Act
      let result =
        snippets_child_vm.run(
          "snippets/doc/reporters/bdd/failures_only",
          "main",
        )
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "Cart\n"
            <> "  ✗ counts two items\n"
            <> "    be_equal\n"
            <> "      Message: expected two items\n"
            <> "      Expected: 2\n"
            <> "      Actual:   1\n"
            <> "\n"
            <> "Summary: 2 run, 1 failed, 1 passed in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected only the failed test and the summary")
    }),
    it("summary_of_one_passed_test gives the summary line", fn() {
      // Act
      let text = render.summary_of_one_passed_test()

      // Assert
      text
      |> should
      |> be_equal("Summary: 1 run, 0 failed, 1 passed in 3ms\n")
      |> or_fail_with("expected the summary line of one passed test")
    }),
    it("report_lists_the_passing_test passes", fn() {
      // Act
      let result = format.report_lists_the_passing_test()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected report_lists_the_passing_test to pass")
    }),
    it("report_writes_the_text passes", fn() {
      // Act
      let result = report.report_writes_the_text()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected report_writes_the_text to pass")
    }),
    it("new_path_is_the_describe_path passes", fn() {
      // Act
      let result = format_incremental.new_path_is_the_describe_path()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected new_path_is_the_describe_path to pass")
    }),
    it("first_result_prints_its_group passes", fn() {
      // Act
      let result =
        format_incremental_with_test_indent.first_result_prints_its_group()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected first_result_prints_its_group to pass")
    }),
    it("parts_hold_the_header_and_the_test_line passes", fn() {
      // Act
      let result =
        format_incremental_parts_with_test_indent.parts_hold_the_header_and_the_test_line()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with(
        "expected parts_hold_the_header_and_the_test_line to pass",
      )
    }),
    it("summary_counts_the_passing_test passes", fn() {
      // Act
      let result = format_summary_only.summary_counts_the_passing_test()

      // Assert
      result
      |> should
      |> be_equal(Ok(AssertionOk))
      |> or_fail_with("expected summary_counts_the_passing_test to pass")
    }),
  ])
}
