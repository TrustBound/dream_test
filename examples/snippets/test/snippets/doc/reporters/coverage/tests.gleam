import app/cart
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import snippets/doc/coverage/tests as coverage_tests
import snippets/doc/reporters/coverage/module
import snippets/doc/reporters/coverage/render
import snippets/doc/reporters/coverage/render_failure
import snippets_child_vm.{ChildRun, it_runs_in_child_vm_with_coverage_lock}

pub fn tests() -> TestSuite {
  describe("Doc examples: reporters/coverage", [
    it_runs_in_child_vm_with_coverage_lock(
      "print_coverage_table prints the table of the measured run",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/reporters/coverage/tests",
            "print_coverage_table_of_the_cart_test",
            [],
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "\n"
              <> coverage_tests.cart_covered_table
              <> "LCOV: build/coverage/lcov.info\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the coverage table of the cart test")
      },
    ),
    it("table_of_one_file gives the table of one file", fn() {
      // Act
      let text = render.table_of_one_file()

      // Assert
      text
      |> should
      |> be_equal(
        "\nCoverage\nFile         Lines  Cover\nsrc/a.gleam  1/2    50.0%\nTotal        1/2    50.0%\n",
      )
      |> or_fail_with("expected the table of one file")
    }),
    it("no_source_files_block says what failed and why", fn() {
      // Act
      let text = render_failure.no_source_files_block()

      // Assert
      text
      |> should
      |> be_equal(
        "\nCoverage failed\n"
        <> "  Found no .gleam or .erl files in the source directory \"lib\".\n"
        <> "  Reason: the directory exists, but coverage has nothing in it to measure.\n"
        <> "  Fix: set the directory that holds your code with coverage.source_directory(...).\n"
        <> "\nTests: 3 passed. Exit status 1, because coverage was requested and did not complete.\n",
      )
      |> or_fail_with("expected the block of a coverage failure")
    }),
  ])
}

/// For the child VM: measure a test of the cart code with the module
/// example, which prints the coverage table.
pub fn print_coverage_table_of_the_cart_test() -> Nil {
  let assert Ok(Nil) =
    module.print_coverage_table(fn() {
      let _total = cart.total([10, 20])
      Nil
    })
  Nil
}
