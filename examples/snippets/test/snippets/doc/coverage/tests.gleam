import dream_test/coverage
import dream_test/coverage/report.{type LineCoverage, LineCoverage}
import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import snippets/doc/coverage/below_minimum_hit
import snippets/doc/coverage/below_minimum_lines_needed
import snippets/doc/coverage/below_minimum_source_path
import snippets/doc/coverage/below_minimum_total
import snippets/doc/coverage/check_minimum
import snippets/doc/coverage/check_minimum_per_file
import snippets/doc/coverage/cobertura_path
import snippets/doc/coverage/color
import snippets/doc/coverage/exclude
import snippets/doc/coverage/exclude_with_reason
import snippets/doc/coverage/file_below_minimum
import snippets/doc/coverage/finish
import snippets/doc/coverage/hide_complete
import snippets/doc/coverage/hides_complete
import snippets/doc/coverage/html_file
import snippets/doc/coverage/html_path
import snippets/doc/coverage/json_path
import snippets/doc/coverage/lcov_file
import snippets/doc/coverage/lcov_path
import snippets/doc/coverage/markdown_path
import snippets/doc/coverage/merge_lcov
import snippets/doc/coverage/minimum
import snippets/doc/coverage/minimum_per_file
import snippets/doc/coverage/minimum_percent
import snippets/doc/coverage/minimum_percent_per_file
import snippets/doc/coverage/module_ignore_markers
import snippets/doc/coverage/module_import
import snippets/doc/coverage/module_other_formats
import snippets/doc/coverage/module_server
import snippets/doc/coverage/new
import snippets/doc/coverage/no_lcov
import snippets/doc/coverage/require_exclusion_reasons
import snippets/doc/coverage/show_excluded
import snippets/doc/coverage/show_missing
import snippets/doc/coverage/shows_excluded
import snippets/doc/coverage/shows_missing
import snippets/doc/coverage/sort_by_coverage
import snippets/doc/coverage/sorts_by_coverage
import snippets/doc/coverage/source_directory
import snippets/doc/coverage/start
import snippets/doc/coverage/uses_color
import snippets_child_vm.{
  ChildRun, it_runs_in_child_vm, it_runs_in_child_vm_with_coverage_lock,
}

pub fn tests() {
  describe("Doc examples: coverage", [
    it_runs_in_child_vm_with_coverage_lock(
      "module_with_runner main fails the run below the minimum",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/coverage/module_with_runner",
            "main",
            [],
          )
          |> result.map(snippets_child_vm.without_progress_and_durations_in)

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 1,
            output: "\nSummary: 0 run, 0 failed, 0 passed in <duration>\n\n"
              <> missing_lines_table
              <> "LCOV: build/coverage/lcov.info\n",
            error_output: "\nCoverage failed\n"
              <> "  Coverage 0.0% is below the minimum 80.0% (needs 8 more lines).\n"
              <> "  Reason: 0 of 9 executable lines ran, and the minimum needs 8.\n"
              <> "  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).\n"
              <> "\nTests: 0 passed. Exit status 1, because coverage is below the minimum.\n",
          )),
        )
        |> or_fail_with("expected module_with_runner to fail below 80%")
      },
    ),
    it_runs_in_child_vm_with_coverage_lock(
      "measure_and_print_coverage prints the table of the measured run",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/coverage/module_without_runner",
            "measure_and_print_coverage",
            [],
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Tests passed: True\n\n"
              <> cart_covered_table
              <> "LCOV: build/coverage/lcov.info\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the coverage table of the cart test")
      },
    ),
    it_runs_in_child_vm("log and dump print their values", fn() {
      // Act
      let result =
        snippets_child_vm.run(
          "snippets/doc/coverage/tests",
          "log_and_dump_in_child_vm",
        )
        |> result.map(snippets_child_vm.without_colors_in_error_output)

      // Assert
      result
      |> should
      |> be_equal(
        Ok(ChildRun(
          status: 0,
          output: "coverage markers\n",
          error_output: "test/snippets/doc/coverage/module_ignore_markers.gleam:11\n42\n",
        )),
      )
      |> or_fail_with("expected log to print its message and dump its value")
    }),
    it("log returns Nil", fn() {
      // Act
      let result = module_ignore_markers.log("coverage markers")

      // Assert
      result
      |> should
      |> be_equal(Nil)
      |> or_fail_with("expected log to return Nil")
    }),
    it("convert_legacy replaces semicolons with commas", fn() {
      // Act
      let result = convert_legacy_without_warning("a;b;c")

      // Assert
      result
      |> should
      |> be_equal("a,b,c")
      |> or_fail_with("expected convert_legacy to give a,b,c")
    }),
    it("dump returns its value", fn() {
      // Act
      let result = module_ignore_markers.dump(42)

      // Assert
      result
      |> should
      |> be_equal(42)
      |> or_fail_with("expected dump to return 42")
    }),
    it("write_every_format returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.json_path("build/coverage/coverage.json")
        |> coverage.cobertura_path("build/coverage/cobertura.xml")
        |> coverage.markdown_path("build/coverage/coverage.md")
        |> coverage.html_path("build/coverage/html")
        |> coverage.html_file("build/coverage/all.html")

      // Act
      let result = module_other_formats.write_every_format()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected write_every_format to return the settings it describes",
      )
    }),
    it_runs_in_child_vm_with_coverage_lock(
      "module_server main serves the requests and writes its LCOV file",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/coverage/tests",
            "run_server_and_print_its_lcov_file",
            [],
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Cart total: 30\nCart total: 5\n" <> server_lcov_file,
            error_output: "",
          )),
        )
        |> or_fail_with("expected the cart totals and the server LCOV file")
      },
    ),
    it_runs_in_child_vm_with_coverage_lock(
      "module_test_run main passes and reports that no server file matched",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/coverage/module_test_run",
            "main",
            [],
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "",
            error_output: "\nCoverage failed\n"
              <> "  No LCOV files match \"build/coverage/servers/*.info\".\n"
              <> "  Reason: coverage.merge_lcov(...) adds coverage written by other runs, and nothing has written a file that matches this pattern.\n"
              <> "  Fix: check that the other runs write their LCOV files to a path that matches before this run finishes, or remove coverage.merge_lcov(...).\n"
              <> "\nTests: 1 passed. The exit status is not changed, because exit_on_failure is off.\n",
          )),
        )
        |> or_fail_with(
          "expected the test to pass and the merge to find no server file",
        )
      },
    ),
    it("default_settings returns the default settings", fn() {
      // Act
      let result = module_import.default_settings()

      // Assert
      result
      |> should
      |> be_equal(coverage.new())
      |> or_fail_with("expected the default settings")
    }),
    it_runs_in_child_vm_with_coverage_lock(
      "run_tests_with_default_coverage prints the table and writes the LCOV file",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/coverage/tests",
            "run_tests_with_default_coverage_and_print_lcov_sources",
            [],
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "\n"
              <> uncovered_table
              <> "LCOV: build/coverage/lcov.info\n"
              <> lcov_source_lines,
            error_output: "",
          )),
        )
        |> or_fail_with("expected the default coverage table and LCOV file")
      },
    ),
    it("measure_the_app_folder returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.source_directory("src/app")

      // Act
      let result = source_directory.measure_the_app_folder()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected measure_the_app_folder to return the settings it describes",
      )
    }),
    it("write_lcov_to_unit_file sets the LCOV file", fn() {
      // Act
      let result =
        lcov_path.write_lcov_to_unit_file()
        |> coverage.lcov_file()

      // Assert
      result
      |> should
      |> be_equal(Some("build/coverage/unit.lcov"))
      |> or_fail_with("expected build/coverage/unit.lcov")
    }),
    it("write_json_summary returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.json_path("build/coverage/coverage.json")

      // Act
      let result = json_path.write_json_summary()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected write_json_summary to return the settings it describes",
      )
    }),
    it("write_cobertura_xml returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.cobertura_path("build/coverage/cobertura.xml")

      // Act
      let result = cobertura_path.write_cobertura_xml()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected write_cobertura_xml to return the settings it describes",
      )
    }),
    it("write_markdown_table returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.markdown_path("build/coverage/coverage.md")

      // Act
      let result = markdown_path.write_markdown_table()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected write_markdown_table to return the settings it describes",
      )
    }),
    it("write_html_pages returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.html_path("build/coverage/html")

      // Act
      let result = html_path.write_html_pages()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected write_html_pages to return the settings it describes",
      )
    }),
    it("write_one_html_page returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.html_file("build/coverage/all.html")

      // Act
      let result = html_file.write_one_html_page()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected write_one_html_page to return the settings it describes",
      )
    }),
    it("skip_the_lcov_file removes the LCOV file", fn() {
      // Act
      let result =
        no_lcov.skip_the_lcov_file()
        |> coverage.lcov_file()

      // Assert
      result
      |> should
      |> be_equal(None)
      |> or_fail_with("expected no LCOV file")
    }),
    it("list_missing_lines turns on the Missing column", fn() {
      // Act
      let result =
        show_missing.list_missing_lines()
        |> coverage.shows_missing()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected show_missing to be on")
    }),
    it("require_eighty_percent sets the minimum", fn() {
      // Act
      let result =
        minimum_percent.require_eighty_percent()
        |> coverage.minimum()

      // Assert
      result
      |> should
      |> be_equal(Some(80.0))
      |> or_fail_with("expected a minimum of 80.0")
    }),
    it("require_seventy_percent_in_each_file sets both minimums", fn() {
      // Act
      let config =
        minimum_percent_per_file.require_seventy_percent_in_each_file()
      let result = #(
        coverage.minimum(config),
        coverage.minimum_per_file(config),
      )

      // Assert
      result
      |> should
      |> be_equal(#(Some(90.0), Some(70.0)))
      |> or_fail_with("expected minimums of 90.0 and 70.0")
    }),
    it("merge_server_coverage returns the settings it describes", fn() {
      // Arrange
      let expected =
        coverage.new()
        |> coverage.merge_lcov("build/coverage/servers/*.info")

      // Act
      let result = merge_lcov.merge_server_coverage()

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with(
        "expected merge_server_coverage to return the settings it describes",
      )
    }),
    it(
      "exclude_generated_and_ffi_files returns the settings it describes",
      fn() {
        // Arrange
        let expected =
          coverage.new()
          |> coverage.exclude("src/app/generated/**")
          |> coverage.exclude("src/**/*_ffi.erl")

        // Act
        let result = exclude.exclude_generated_and_ffi_files()

        // Assert
        result
        |> should
        |> be_equal(expected)
        |> or_fail_with(
          "expected exclude_generated_and_ffi_files to return the settings it describes",
        )
      },
    ),
    it(
      "exclude_generated_code_with_reason returns the settings it describes",
      fn() {
        // Arrange
        let expected =
          coverage.new()
          |> coverage.exclude_with_reason(
            pattern: "src/app/generated/**",
            reason: "generated from the database schema",
          )

        // Act
        let result = exclude_with_reason.exclude_generated_code_with_reason()

        // Assert
        result
        |> should
        |> be_equal(expected)
        |> or_fail_with(
          "expected exclude_generated_code_with_reason to return the settings it describes",
        )
      },
    ),
    it("list_excluded_files_and_lines turns on the Excluded column", fn() {
      // Act
      let result =
        show_excluded.list_excluded_files_and_lines()
        |> coverage.shows_excluded()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected show_excluded to be on")
    }),
    it(
      "require_a_reason_for_each_exclusion returns the settings it describes",
      fn() {
        // Arrange
        let expected =
          coverage.new()
          |> coverage.exclude_with_reason(
            pattern: "src/app/generated/**",
            reason: "generated code",
          )
          |> coverage.require_exclusion_reasons()

        // Act
        let result =
          require_exclusion_reasons.require_a_reason_for_each_exclusion()

        // Assert
        result
        |> should
        |> be_equal(expected)
        |> or_fail_with(
          "expected require_a_reason_for_each_exclusion to return the settings it describes",
        )
      },
    ),
    it(
      "print_missing_lines_in_colour turns on colour and the Missing column",
      fn() {
        // Act
        let config = color.print_missing_lines_in_colour()
        let result = #(
          coverage.uses_color(config),
          coverage.shows_missing(config),
        )

        // Assert
        result
        |> should
        |> be_equal(#(True, True))
        |> or_fail_with("expected colour and show_missing to be on")
      },
    ),
    it("list_lowest_coverage_first turns on the sort", fn() {
      // Act
      let result =
        sort_by_coverage.list_lowest_coverage_first()
        |> coverage.sorts_by_coverage()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected sort_by_coverage to be on")
    }),
    it("hide_fully_covered_files turns on hide_complete", fn() {
      // Act
      let result =
        hide_complete.hide_fully_covered_files()
        |> coverage.hides_complete()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected hide_complete to be on")
    }),
    it("show_missing_is_on returns True", fn() {
      // Act
      let result = shows_missing.show_missing_is_on()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected show_missing_is_on to return True")
    }),
    it("show_excluded_is_on returns True", fn() {
      // Act
      let result = shows_excluded.show_excluded_is_on()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected show_excluded_is_on to return True")
    }),
    it("color_is_on returns True", fn() {
      // Act
      let result = uses_color.color_is_on()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected color_is_on to return True")
    }),
    it("sort_by_coverage_is_on returns True", fn() {
      // Act
      let result = sorts_by_coverage.sort_by_coverage_is_on()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected sort_by_coverage_is_on to return True")
    }),
    it("hide_complete_is_on returns True", fn() {
      // Act
      let result = hides_complete.hide_complete_is_on()

      // Assert
      result
      |> should
      |> be_equal(True)
      |> or_fail_with("expected hide_complete_is_on to return True")
    }),
    it("minimum_is_eighty returns Some(80.0)", fn() {
      // Act
      let result = minimum.minimum_is_eighty()

      // Assert
      result
      |> should
      |> be_equal(Some(80.0))
      |> or_fail_with("expected minimum_is_eighty to return Some(80.0)")
    }),
    it("minimum_per_file_is_seventy returns Some(70.0)", fn() {
      // Act
      let result = minimum_per_file.minimum_per_file_is_seventy()

      // Assert
      result
      |> should
      |> be_equal(Some(70.0))
      |> or_fail_with(
        "expected minimum_per_file_is_seventy to return Some(70.0)",
      )
    }),
    it("default_lcov_file returns Some(build/coverage/lcov.info)", fn() {
      // Act
      let result = lcov_file.default_lcov_file()

      // Assert
      result
      |> should
      |> be_equal(Some("build/coverage/lcov.info"))
      |> or_fail_with(
        "expected default_lcov_file to return Some(build/coverage/lcov.info)",
      )
    }),
    it("start_in_missing_directory returns SourceDirectoryNotFound", fn() {
      // Act
      let result = start.start_in_missing_directory()

      // Assert
      result
      |> should
      |> be_equal(Error(coverage.SourceDirectoryNotFound("src/does_not_exist")))
      |> or_fail_with("expected SourceDirectoryNotFound")
    }),
    it_runs_in_child_vm_with_coverage_lock(
      "measure_my_tests gives the test result and the measured lines",
      fn() {
        // Act
        let result =
          snippets_child_vm.run_with_coverage_lock(
            "snippets/doc/coverage/tests",
            "measure_my_tests_and_print_the_result",
            [],
          )

        // Assert
        result
        |> should
        |> be_equal(
          Ok(ChildRun(
            status: 0,
            output: "Tests passed: True\n"
              <> "src/app/cart.gleam: 3/3\n"
              <> "src/app/generated/db.gleam: 0/1\n"
              <> "src/app/internal/debug.gleam: 0/1\n"
              <> "src/snippets.gleam: 0/4\n",
            error_output: "",
          )),
        )
        |> or_fail_with("expected the cart lines to be measured as run")
      },
    ),
    it("check_total_against_eighty_percent reports the lines needed", fn() {
      // Arrange
      let coverage_report =
        report.new([
          report.file("src/app.gleam", lines_with_hits(hit: 1567, total: 2230)),
        ])

      // Act
      let result =
        check_minimum.check_total_against_eighty_percent(coverage_report)

      // Assert
      result
      |> should
      |> be_equal(
        Error(coverage.BelowMinimumPercent(
          hit: 1567,
          total: 2230,
          minimum_percent: 80.0,
          lines_needed: 1784,
        )),
      )
      |> or_fail_with("expected 1784 of 2230 lines needed")
    }),
    it("check_each_file_against_fifty_percent lists the cart file", fn() {
      // Arrange
      let coverage_report =
        report.new([
          report.file("src/app/cart.gleam", lines_with_hits(hit: 3, total: 10)),
        ])

      // Act
      let result =
        check_minimum_per_file.check_each_file_against_fifty_percent(
          coverage_report,
        )

      // Assert
      result
      |> should
      |> be_equal(
        Error(
          coverage.FilesBelowMinimumPercent(minimum_percent: 50.0, files: [
            coverage.file_below_minimum(
              source_path: "src/app/cart.gleam",
              hit: 3,
              total: 10,
              lines_needed: 5,
            ),
          ]),
        ),
      )
      |> or_fail_with("expected the cart file below 50.0")
    }),
    it("cart_below_minimum holds the given counts", fn() {
      // Arrange
      let file = file_below_minimum.cart_below_minimum()
      let expected = #("src/app/cart.gleam", 3, 10, 5)

      // Act
      let result = #(
        coverage.below_minimum_source_path(file),
        coverage.below_minimum_hit(file),
        coverage.below_minimum_total(file),
        coverage.below_minimum_lines_needed(file),
      )

      // Assert
      result
      |> should
      |> be_equal(expected)
      |> or_fail_with("expected the cart file with 3 of 10 lines and 5 needed")
    }),
    it("cart_source_path returns src/app/cart.gleam", fn() {
      // Act
      let result = below_minimum_source_path.cart_source_path()

      // Assert
      result
      |> should
      |> be_equal("src/app/cart.gleam")
      |> or_fail_with("expected cart_source_path to return src/app/cart.gleam")
    }),
    it("cart_hit_lines returns 3", fn() {
      // Act
      let result = below_minimum_hit.cart_hit_lines()

      // Assert
      result
      |> should
      |> be_equal(3)
      |> or_fail_with("expected cart_hit_lines to return 3")
    }),
    it("cart_total_lines returns 10", fn() {
      // Act
      let result = below_minimum_total.cart_total_lines()

      // Assert
      result
      |> should
      |> be_equal(10)
      |> or_fail_with("expected cart_total_lines to return 10")
    }),
    it("cart_lines_needed returns 5", fn() {
      // Act
      let result = below_minimum_lines_needed.cart_lines_needed()

      // Assert
      result
      |> should
      |> be_equal(5)
      |> or_fail_with("expected cart_lines_needed to return 5")
    }),
  ])
}

/// The lines of a file where the first `hit` lines ran once and the rest
/// did not run.
fn lines_with_hits(hit hit: Int, total total: Int) -> List(LineCoverage) {
  int.range(from: total, to: 0, with: [], run: fn(lines, line) {
    [LineCoverage(line: line, calls: calls_of(line, hit)), ..lines]
  })
}

fn calls_of(line: Int, hit: Int) -> Int {
  case line <= hit {
    True -> 1
    False -> 0
  }
}

/// `module_ignore_markers.convert_legacy`, called through its Erlang name.
/// It is deprecated, so a Gleam call gives a compiler warning.
@external(erlang, "snippets@doc@coverage@module_ignore_markers", "convert_legacy")
fn convert_legacy_without_warning(record: String) -> String

/// The coverage table of the snippets project when no line ran, with the
/// missing lines.
const missing_lines_table =
  "Coverage\n"
  <> "File                          Lines  Cover  Missing\n"
  <> "src/app/cart.gleam            0/3    0.0%   6-8\n"
  <> "src/app/generated/db.gleam    0/1    0.0%   6\n"
  <> "src/app/internal/debug.gleam  0/1    0.0%   6\n"
  <> "src/snippets.gleam            0/4    0.0%   3, 8-10\n"
  <> "Total                         0/9    0.0%\n"

/// The coverage table of the snippets project when no line ran.
pub const uncovered_table =
  "Coverage\n"
  <> "File                          Lines  Cover\n"
  <> "src/app/cart.gleam            0/3    0.0%\n"
  <> "src/app/generated/db.gleam    0/1    0.0%\n"
  <> "src/app/internal/debug.gleam  0/1    0.0%\n"
  <> "src/snippets.gleam            0/4    0.0%\n"
  <> "Total                         0/9    0.0%\n"

/// The coverage table of the snippets project when the cart test ran.
pub const cart_covered_table =
  "Coverage\n"
  <> "File                          Lines  Cover\n"
  <> "src/app/cart.gleam            3/3    100.0%\n"
  <> "src/app/generated/db.gleam    0/1    0.0%\n"
  <> "src/app/internal/debug.gleam  0/1    0.0%\n"
  <> "src/snippets.gleam            0/4    0.0%\n"
  <> "Total                         3/9    33.3%\n"

/// The source file lines (`SF:`) of the default LCOV file of the snippets
/// project.
const lcov_source_lines =
  "SF:src/app/cart.gleam\n"
  <> "SF:src/app/generated/db.gleam\n"
  <> "SF:src/app/internal/debug.gleam\n"
  <> "SF:src/snippets.gleam\n"

/// The LCOV file that the server example writes.
const server_lcov_file =
  "TN:\n"
  <> "SF:src/app/cart.gleam\n"
  <> "DA:6,5\n"
  <> "DA:7,2\n"
  <> "DA:8,3\n"
  <> "LF:3\n"
  <> "LH:3\n"
  <> "end_of_record\n"
  <> "TN:\n"
  <> "SF:src/app/generated/db.gleam\n"
  <> "DA:6,0\n"
  <> "LF:1\n"
  <> "LH:0\n"
  <> "end_of_record\n"
  <> "TN:\n"
  <> "SF:src/app/internal/debug.gleam\n"
  <> "DA:6,0\n"
  <> "LF:1\n"
  <> "LH:0\n"
  <> "end_of_record\n"
  <> "TN:\n"
  <> "SF:src/snippets.gleam\n"
  <> "DA:3,0\n"
  <> "DA:8,0\n"
  <> "DA:9,0\n"
  <> "DA:10,0\n"
  <> "LF:4\n"
  <> "LH:0\n"
  <> "end_of_record\n"

/// For the child VM: call `log` and `dump` of the ignore markers example.
pub fn log_and_dump_in_child_vm() -> Nil {
  module_ignore_markers.log("coverage markers")
  let _value = module_ignore_markers.dump(42)
  Nil
}

/// For the child VM: run the server example, then print the LCOV file that
/// it wrote.
pub fn run_server_and_print_its_lcov_file() -> Nil {
  module_server.main()
  print_file("build/coverage/servers/app.info")
}

/// For the child VM: run the tests with default coverage, then print the
/// source file lines of the LCOV file that the run wrote.
pub fn run_tests_with_default_coverage_and_print_lcov_sources() -> Nil {
  let _report = new.run_tests_with_default_coverage()
  let assert Ok(text) = file.read("build/coverage/lcov.info")
  string.split(text, "\n")
  |> list.filter(string.starts_with(_, "SF:"))
  |> list.each(io.println)
}

/// For the child VM: measure the tests of the `finish` example, then print
/// whether they passed and the lines that ran in each file.
pub fn measure_my_tests_and_print_the_result() -> Nil {
  let #(tests_passed, coverage_report) = finish.measure_my_tests()
  io.println("Tests passed: " <> bool.to_string(tests_passed))
  list.each(report.files(coverage_report), print_file_lines)
}

fn print_file_lines(file_coverage: report.FileCoverage) -> Nil {
  io.println(
    report.source_path(file_coverage)
    <> ": "
    <> int.to_string(report.hit_line_count(file_coverage))
    <> "/"
    <> int.to_string(report.executable_line_count(file_coverage)),
  )
}

fn print_file(path: String) -> Nil {
  let assert Ok(text) = file.read(path)
  io.print(text)
}
