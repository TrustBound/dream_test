import dream_test/discover
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import snippets/doc/discover/list_modules as list_modules_example
import snippets/doc/discover/load as load_example
import snippets/doc/discover/load_result as load_result_example
import snippets/doc/discover/test_discovery as test_discovery_example
import snippets_child_vm.{ChildRun, it_runs_in_child_vm, progress_done_line}

/// The test modules that the pattern "snippets@unit@**.gleam" finds.
fn unit_snippet_modules() -> List(String) {
  [
    "snippets@unit@chaining", "snippets@unit@dsl_import",
    "snippets@unit@explicit_failures", "snippets@unit@grouping",
    "snippets@unit@hero", "snippets@unit@pending_tests",
    "snippets@unit@quick_start", "snippets@unit@skipping_tests",
    "snippets@unit@tagging",
  ]
}

pub fn tests() -> TestSuite {
  describe("Doc examples: discover", [
    it_runs_in_child_vm("new main runs the discovered unit snippets", fn() {
      // Act
      let result =
        snippets_child_vm.run("snippets/doc/discover/new", "main")
        |> result.map(snippets_child_vm.without_progress_and_durations_in)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: progress_done_line(22)
            <> "Chaining matchers\n"
            <> "  ✓ unwraps Option\n"
            <> "  ✓ unwraps Result\n"
            <> "unit DSL\n"
            <> "  ✓ receives no context\n"
            <> "Explicit failures\n"
            <> "  ✓ succeeds explicitly when division works\n"
            <> "  ✓ fails explicitly when expecting an error\n"
            <> "Calculator\n"
            <> "  addition\n"
            <> "    ✓ adds small numbers\n"
            <> "    ✓ adds negative numbers\n"
            <> "  division\n"
            <> "    ✓ integer division rounds toward zero\n"
            <> "  ✓ adds two numbers\n"
            <> "  ✓ handles division\n"
            <> "  ✓ returns error for division by zero\n"
            <> "Cart\n"
            <> "  ✓ starts empty\n"
            <> "  ~ adds an item\n"
            <> "  ~ removes an item\n"
            <> "String utilities\n"
            <> "  ✓ trims whitespace\n"
            <> "  ✓ finds substrings\n"
            <> "Skipping tests\n"
            <> "  ✓ runs normally\n"
            <> "  - not implemented yet\n"
            <> "  ✓ also runs normally\n"
            <> "Tagged tests\n"
            <> "  ✓ smoke\n"
            <> "  integration\n"
            <> "    ✓ slow path\n"
            <> "    ✓ another slow path\n"
            <> "\n"
            <> "Summary: 22 run, 0 failed, 19 passed, 1 skipped, 2 pending in <duration>\n",
          error_output: "",
        )),
      )
      |> or_fail_with("expected the new main to run the unit snippets")
    }),
    it_runs_in_child_vm(
      "tests_pattern main runs the discovered unit snippets",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/discover/tests_pattern", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: progress_done_line(22)
              <> "Chaining matchers\n"
              <> "  ✓ unwraps Option\n"
              <> "  ✓ unwraps Result\n"
              <> "unit DSL\n"
              <> "  ✓ receives no context\n"
              <> "Explicit failures\n"
              <> "  ✓ succeeds explicitly when division works\n"
              <> "  ✓ fails explicitly when expecting an error\n"
              <> "Calculator\n"
              <> "  addition\n"
              <> "    ✓ adds small numbers\n"
              <> "    ✓ adds negative numbers\n"
              <> "  division\n"
              <> "    ✓ integer division rounds toward zero\n"
              <> "  ✓ adds two numbers\n"
              <> "  ✓ handles division\n"
              <> "  ✓ returns error for division by zero\n"
              <> "Cart\n"
              <> "  ✓ starts empty\n"
              <> "  ~ adds an item\n"
              <> "  ~ removes an item\n"
              <> "String utilities\n"
              <> "  ✓ trims whitespace\n"
              <> "  ✓ finds substrings\n"
              <> "Skipping tests\n"
              <> "  ✓ runs normally\n"
              <> "  - not implemented yet\n"
              <> "  ✓ also runs normally\n"
              <> "Tagged tests\n"
              <> "  ✓ smoke\n"
              <> "  integration\n"
              <> "    ✓ slow path\n"
              <> "    ✓ another slow path\n"
              <> "\n"
              <> "Summary: 22 run, 0 failed, 19 passed, 1 skipped, 2 pending in <duration>\n",
            error_output: "",
          )),
        )
        |> or_fail_with(
          "expected the tests_pattern main to run the unit snippets",
        )
      },
    ),
    it_runs_in_child_vm(
      "to_suite main runs the unit snippets in one suite",
      fn() {
        // Act
        let result =
          snippets_child_vm.run("snippets/doc/discover/to_suite", "main")
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: progress_done_line(22)
              <> "discovered tests\n"
              <> "  Chaining matchers\n"
              <> "    ✓ unwraps Option\n"
              <> "    ✓ unwraps Result\n"
              <> "  unit DSL\n"
              <> "    ✓ receives no context\n"
              <> "  Explicit failures\n"
              <> "    ✓ succeeds explicitly when division works\n"
              <> "    ✓ fails explicitly when expecting an error\n"
              <> "  Calculator\n"
              <> "    addition\n"
              <> "      ✓ adds small numbers\n"
              <> "      ✓ adds negative numbers\n"
              <> "    division\n"
              <> "      ✓ integer division rounds toward zero\n"
              <> "    ✓ adds two numbers\n"
              <> "    ✓ handles division\n"
              <> "    ✓ returns error for division by zero\n"
              <> "  Cart\n"
              <> "    ✓ starts empty\n"
              <> "    ~ adds an item\n"
              <> "    ~ removes an item\n"
              <> "  String utilities\n"
              <> "    ✓ trims whitespace\n"
              <> "    ✓ finds substrings\n"
              <> "  Skipping tests\n"
              <> "    ✓ runs normally\n"
              <> "    - not implemented yet\n"
              <> "    ✓ also runs normally\n"
              <> "  Tagged tests\n"
              <> "    ✓ smoke\n"
              <> "    integration\n"
              <> "      ✓ slow path\n"
              <> "      ✓ another slow path\n"
              <> "\n"
              <> "Summary: 22 run, 0 failed, 19 passed, 1 skipped, 2 pending in <duration>\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the to_suite main to run one named suite")
      },
    ),
    it("test_discovery.load_unit_snippets loads 9 suites with no error", fn() {
      // Act
      let discover.LoadResult(suites: suites, errors: errors) =
        test_discovery_example.load_unit_snippets()

      // Assert
      #(list.length(suites), errors)
      |> should
      |> be_equal(#(9, []))
      |> or_fail_with("expected 9 suites and no error")
    }),
    it("load_result.loaded_suites loads at least the unit snippets", fn() {
      // Act
      let result = list.length(load_result_example.loaded_suites()) >= 9

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected the suites of all snippet modules")
    }),
    it("list_modules.main lists the unit snippet modules", fn() {
      // Act
      let result = list_modules_example.main()

      // Assert
      result
      |> should
      |> be_equal(Ok(unit_snippet_modules()))
      |> or_fail_with("expected the 9 unit snippet modules")
    }),
    it("load.main loads 9 suites with no error", fn() {
      // Act
      let discover.LoadResult(suites: suites, errors: errors) =
        load_example.main()

      // Assert
      #(list.length(suites), errors)
      |> should
      |> be_equal(#(9, []))
      |> or_fail_with("expected 9 suites and no error")
    }),
  ])
}
