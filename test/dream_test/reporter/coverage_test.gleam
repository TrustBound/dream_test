//// Black-box tests of `dream_test/reporters/coverage`.

import dream_test/coverage.{
  type CoverageError, AlreadyInstrumented, BadBeamFile, BelowMinimumPercent,
  CoberturaWriteFailed, CompilerNotLoaded, DebugInfoUnreadable, EmbeddedMode,
  EncryptedDebugInfo, EverySourceFileExcluded, ExcludeMatchedNothing,
  ExcludeWithoutReason, HtmlDeleteFailed, HtmlFileSourceReadFailed,
  HtmlFileWriteFailed, HtmlSourceReadFailed, HtmlWriteFailed,
  IgnoreEndWithoutStart, IgnoreFunctionWithoutFunction,
  IgnoreMarkerWithoutReason, IgnoreStartWithoutEnd, InstrumentedLoadFailed,
  InvalidEnvironmentValue, InvalidMinimumPercent, JsonWriteFailed,
  LcovReadFailed, LcovSourceNotFound, LcovWriteFailed, MalformedLcov,
  MarkdownWriteFailed, ModuleAlreadyMeasured, ModuleNotAnalysed, ModuleNotBuilt,
  ModuleNotInstrumented, ModuleNotLoaded, NativeCoverageUnsupported,
  NestedIgnoreStart, NoDebugInfo, NoLcovFilesMatched, NoSourceFiles,
  NotInstrumented, OldCodeInUse, OnLoadFailed, RecompileFailed,
  SessionAlreadyFinished, SourceDirectoryNotFound,
  SourceDirectoryOutsideSourceRoot, SourceReadFailed,
}
import dream_test/coverage/report.{type LineCoverage, LineCoverage}
import dream_test/file.{
  FileSystemError, IsDirectory, NoSpace, NotFound, PermissionDenied,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/coverage.{RunOutcome} as coverage_reporter
import dream_test/unit.{describe, group, it}
import gleam/list
import gleam/option.{None, Some}

fn cart_and_types_report() {
  report.new([
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 2),
      LineCoverage(line: 4, calls: 0),
      LineCoverage(line: 5, calls: 0),
      LineCoverage(line: 9, calls: 1),
      LineCoverage(line: 12, calls: 0),
    ]),
    report.file("src/app/types.gleam", []),
  ])
}

/// The cart and types report, with ignored lines 40-44 and 71 in the cart
/// file, and one excluded file.
fn excluded_report() {
  report.new([
    report.file("src/app/cart.gleam", [
      LineCoverage(line: 3, calls: 2),
      LineCoverage(line: 4, calls: 0),
      LineCoverage(line: 5, calls: 0),
      LineCoverage(line: 9, calls: 1),
      LineCoverage(line: 12, calls: 0),
    ])
      |> report.add_ignored_ranges([
        report.ignored_range(
          first_line: 40,
          last_line: 44,
          reason: Some("debug only"),
        ),
        report.ignored_range(first_line: 71, last_line: 71, reason: None),
      ]),
    report.file("src/app/types.gleam", []),
  ])
  |> report.add_excluded_files([
    report.excluded_file(
      source_path: "src/app/generated/db.gleam",
      pattern: "src/app/generated/**",
      reason: Some("generated code"),
    ),
  ])
}

/// A file with one line that ran, and `ranges` ignored.
fn file_with_ranges(path: String, ranges: List(#(Int, Int))) {
  report.file(path, [LineCoverage(line: 1, calls: 1)])
  |> report.add_ignored_ranges(list.map(ranges, range_without_reason))
}

fn range_without_reason(range: #(Int, Int)) {
  report.ignored_range(first_line: range.0, last_line: range.1, reason: None)
}

/// Lines from..to where odd lines never ran and even lines ran once.
fn odd_lines_missed(
  from: Int,
  to: Int,
  accumulated: List(LineCoverage),
) -> List(LineCoverage) {
  case from > to {
    True -> list.reverse(accumulated)
    False ->
      odd_lines_missed(from + 1, to, [
        LineCoverage(line: from, calls: { from + 1 } % 2),
        ..accumulated
      ])
  }
}

fn full_file() {
  report.file("src/a_full.gleam", [
    LineCoverage(line: 1, calls: 1),
    LineCoverage(line: 2, calls: 3),
  ])
}

fn half_file() {
  report.file("src/b_half.gleam", [
    LineCoverage(line: 1, calls: 1),
    LineCoverage(line: 2, calls: 0),
  ])
}

fn low_file() {
  report.file("src/c_low.gleam", [
    LineCoverage(line: 1, calls: 1),
    LineCoverage(line: 2, calls: 0),
    LineCoverage(line: 3, calls: 0),
    LineCoverage(line: 4, calls: 0),
  ])
}

fn empty_file() {
  report.file("src/d_empty.gleam", [])
}

/// 50.0%, like `half_file`, so it ties with it.
fn other_half_file() {
  report.file("src/e_half.gleam", [
    LineCoverage(line: 1, calls: 1),
    LineCoverage(line: 2, calls: 0),
    LineCoverage(line: 3, calls: 2),
    LineCoverage(line: 4, calls: 0),
  ])
}

fn other_full_file() {
  report.file("src/f_full.gleam", [
    LineCoverage(line: 1, calls: 1),
    LineCoverage(line: 2, calls: 1),
    LineCoverage(line: 3, calls: 1),
  ])
}

fn red(text: String) -> String {
  "\u{1b}[31m" <> text <> "\u{1b}[0m"
}

fn yellow(text: String) -> String {
  "\u{1b}[33m" <> text <> "\u{1b}[0m"
}

fn green(text: String) -> String {
  "\u{1b}[32m" <> text <> "\u{1b}[0m"
}

fn passing_outcome() {
  RunOutcome(passed: 3, failed: 0, exit_on_failure: True)
}

fn render_failure_for(error: CoverageError) -> String {
  coverage_reporter.render_failure(error: error, outcome: passing_outcome())
}

/// The block `render_failure` prints for three passing tests.
fn failure_block(what: String, reason: String, fix: String) -> String {
  "\nCoverage failed\n  "
  <> what
  <> "\n  Reason: "
  <> reason
  <> "\n  Fix: "
  <> fix
  <> "\n\nTests: 3 passed. Exit status 1, because coverage was requested and did not complete.\n"
}

pub fn tests() {
  describe("dream_test/reporters/coverage", [
    group("render", [
      it("renders a row per file, a total and the LCOV path", fn() {
        coverage_reporter.render(
          report: cart_and_types_report(),
          config: coverage.new(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File                 Lines  Cover\n"
          <> "src/app/cart.gleam   2/5    40.0%\n"
          <> "src/app/types.gleam  0/0    -\n"
          <> "Total                2/5    40.0%\n"
          <> "LCOV: build/coverage/lcov.info\n",
        )
        |> or_fail_with("expected the coverage table")
      }),
      it("warns about files with inexact line numbers after the table", fn() {
        coverage_reporter.render(
          report: report.new([report.file("a.gleam", [LineCoverage(1, 1)])])
            |> report.add_inexact_line_files(["a.gleam", "b/c.gleam"]),
          config: coverage.new(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File     Lines  Cover\n"
          <> "a.gleam  1/1    100.0%\n"
          <> "Total    1/1    100.0%\n"
          <> "LCOV: build/coverage/lcov.info\n"
          <> "\nWarning: coverage line numbers may be off in files that a Gleam version before 1.19 built:\n"
          <> "  a.gleam\n"
          <> "  b/c.gleam\n"
          <> "  Reason: before 1.19, Gleam maps only the first line of each function to its source line, so other lines in a function can show the wrong number in the Missing column, the LCOV file and coverage:ignore markers.\n"
          <> "  Fix: build and test with Gleam 1.19 or later (`gleam --version` shows the version).\n",
        )
        |> or_fail_with("expected the table, then the warning")
      }),
      it("leaves out the LCOV line with no_lcov", fn() {
        coverage_reporter.render(
          report: report.new([report.file("a.gleam", [LineCoverage(1, 1)])]),
          config: coverage.new() |> coverage.no_lcov(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File     Lines  Cover\n"
          <> "a.gleam  1/1    100.0%\n"
          <> "Total    1/1    100.0%\n",
        )
        |> or_fail_with("expected no LCOV line")
      }),
      it("color paints Cover by the minimum and Missing in red", fn() {
        coverage_reporter.render(
          report: report.new([
            full_file(),
            half_file(),
            low_file(),
            empty_file(),
          ]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_missing()
            |> coverage.minimum_percent(50.0)
            |> coverage.color(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File               Lines  Cover   Missing\n"
          <> "src/a_full.gleam   2/2    "
          <> green("100.0%")
          <> "\n"
          <> "src/b_half.gleam   1/2    "
          <> yellow("50.0%")
          <> "   "
          <> red("2")
          <> "\n"
          <> "src/c_low.gleam    1/4    "
          <> red("25.0%")
          <> "   "
          <> red("2-4")
          <> "\n"
          <> "src/d_empty.gleam  0/0    -\n"
          <> "Total              4/8    "
          <> yellow("50.0%")
          <> "\n",
        )
        |> or_fail_with("expected green, yellow and red cells")
      }),
      it("color paints Cover by the fixed rule without a minimum", fn() {
        coverage_reporter.render(
          report: report.new([full_file(), half_file(), low_file()]),
          config: coverage.new() |> coverage.no_lcov() |> coverage.color(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File              Lines  Cover\n"
          <> "src/a_full.gleam  2/2    "
          <> green("100.0%")
          <> "\n"
          <> "src/b_half.gleam  1/2    "
          <> yellow("50.0%")
          <> "\n"
          <> "src/c_low.gleam   1/4    "
          <> red("25.0%")
          <> "\n"
          <> "Total             4/8    "
          <> yellow("50.0%")
          <> "\n",
        )
        |> or_fail_with("expected green, yellow from 50.0% and red below")
      }),
      it("color paints Cover by the fixed rule with an invalid minimum", fn() {
        coverage_reporter.render(
          report: report.new([full_file(), low_file()]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.minimum_percent(150.0)
            |> coverage.color(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File              Lines  Cover\n"
          <> "src/a_full.gleam  2/2    "
          <> green("100.0%")
          <> "\n"
          <> "src/c_low.gleam   1/4    "
          <> red("25.0%")
          <> "\n"
          <> "Total             3/6    "
          <> yellow("50.0%")
          <> "\n",
        )
        |> or_fail_with("expected the fixed rule colours")
      }),
      it("sort_by_coverage lists the lowest coverage first, ties by path", fn() {
        coverage_reporter.render(
          report: report.new([
            empty_file(),
            full_file(),
            other_half_file(),
            low_file(),
            half_file(),
          ])
            |> report.add_excluded_files([
              report.excluded_file(
                source_path: "src/gen.gleam",
                pattern: "src/gen.gleam",
                reason: None,
              ),
            ]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_excluded()
            |> coverage.sort_by_coverage(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File               Lines  Cover   Excluded\n"
          <> "src/c_low.gleam    1/4    25.0%\n"
          <> "src/b_half.gleam   1/2    50.0%\n"
          <> "src/e_half.gleam   2/4    50.0%\n"
          <> "src/a_full.gleam   2/2    100.0%\n"
          <> "src/d_empty.gleam  0/0    -\n"
          <> "src/gen.gleam      excluded: matches src/gen.gleam\n"
          <> "Total              6/12   50.0%\n"
          <> "Excluded: 1 file\n",
        )
        |> or_fail_with("expected the lowest coverage first")
      }),
      it("hide_complete leaves out files at 100.0% and counts them", fn() {
        coverage_reporter.render(
          report: report.new([
            full_file(),
            half_file(),
            other_full_file(),
            empty_file(),
          ]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.hide_complete(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File               Lines  Cover\n"
          <> "src/b_half.gleam   1/2    50.0%\n"
          <> "src/d_empty.gleam  0/0    -\n"
          <> "Total              6/7    85.7%\n"
          <> "Hidden: 2 files at 100.0%\n",
        )
        |> or_fail_with("expected two hidden files")
      }),
      it("hide_complete counts one hidden file before the LCOV line", fn() {
        coverage_reporter.render(
          report: report.new([full_file(), half_file()]),
          config: coverage.new() |> coverage.hide_complete(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File              Lines  Cover\n"
          <> "src/b_half.gleam  1/2    50.0%\n"
          <> "Total             3/4    75.0%\n"
          <> "Hidden: 1 file at 100.0%\n"
          <> "LCOV: build/coverage/lcov.info\n",
        )
        |> or_fail_with("expected one hidden file")
      }),
      it("hide_complete prints no Hidden line when no file is complete", fn() {
        coverage_reporter.render(
          report: report.new([half_file()]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.hide_complete(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File              Lines  Cover\n"
          <> "src/b_half.gleam  1/2    50.0%\n"
          <> "Total             1/2    50.0%\n",
        )
        |> or_fail_with("expected no Hidden line")
      }),
      it("rounds down so a file is 100.0% only when every line ran", fn() {
        coverage_reporter.render(
          report: report.new([
            report.file("a.gleam", [
              LineCoverage(line: 1001, calls: 0),
              ..odd_lines_missed(1, 1000, [])
              |> list.map(fn(line) { LineCoverage(..line, calls: 1) })
            ]),
          ]),
          config: coverage.new() |> coverage.no_lcov(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File     Lines      Cover\n"
          <> "a.gleam  1000/1001  99.9%\n"
          <> "Total    1000/1001  99.9%\n",
        )
        |> or_fail_with("expected 99.9%, not 100.0%")
      }),
      it("show_missing adds a Missing column with ranges that wrap", fn() {
        coverage_reporter.render(
          report: report.new([
            report.file("src/app/cart.gleam", [
              LineCoverage(line: 3, calls: 1),
              LineCoverage(line: 4, calls: 0),
              LineCoverage(line: 5, calls: 0),
              LineCoverage(line: 9, calls: 2),
              LineCoverage(line: 12, calls: 0),
            ]),
            report.file("src/app/long.gleam", odd_lines_missed(1, 42, [])),
            report.file("src/app/full.gleam", [LineCoverage(line: 2, calls: 1)]),
          ]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_missing(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File                Lines  Cover   Missing\n"
          <> "src/app/cart.gleam  2/5    40.0%   4-5, 12\n"
          <> "src/app/long.gleam  21/42  50.0%   1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31,\n"
          <> "                                   33, 35, 37, 39, 41\n"
          <> "src/app/full.gleam  1/1    100.0%\n"
          <> "Total               24/48  50.0%\n",
        )
        |> or_fail_with("expected the table with a Missing column")
      }),
    ]),

    group("render excluded", [
      it("show_excluded adds an Excluded column and excluded file rows", fn() {
        coverage_reporter.render(
          report: excluded_report(),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_excluded(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File                        Lines  Cover  Excluded\n"
          <> "src/app/cart.gleam          2/5    40.0%  40-44 (debug only), 71\n"
          <> "src/app/types.gleam         0/0    -\n"
          <> "src/app/generated/db.gleam  excluded: matches src/app/generated/** (generated code)\n"
          <> "Total                       2/5    40.0%\n"
          <> "Excluded: 1 file, 6 lines in 1 file\n",
        )
        |> or_fail_with("expected the Excluded column and the excluded file")
      }),
      it("prints the Excluded count line without show_excluded", fn() {
        coverage_reporter.render(
          report: excluded_report(),
          config: coverage.new(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File                 Lines  Cover\n"
          <> "src/app/cart.gleam   2/5    40.0%\n"
          <> "src/app/types.gleam  0/0    -\n"
          <> "Total                2/5    40.0%\n"
          <> "Excluded: 1 file, 6 lines in 1 file\n"
          <> "LCOV: build/coverage/lcov.info\n",
        )
        |> or_fail_with("expected the count line before the LCOV line")
      }),
      it("pads the Missing column when the Excluded column follows", fn() {
        coverage_reporter.render(
          report: excluded_report(),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_missing()
            |> coverage.show_excluded(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File                        Lines  Cover  Missing  Excluded\n"
          <> "src/app/cart.gleam          2/5    40.0%  4-5, 12  40-44 (debug only), 71\n"
          <> "src/app/types.gleam         0/0    -\n"
          <> "src/app/generated/db.gleam  excluded: matches src/app/generated/** (generated code)\n"
          <> "Total                       2/5    40.0%\n"
          <> "Excluded: 1 file, 6 lines in 1 file\n",
        )
        |> or_fail_with("expected the Missing and Excluded columns")
      }),
      it("counts excluded files only, and shows a file without a reason", fn() {
        coverage_reporter.render(
          report: report.new([file_with_ranges("src/a.gleam", [])])
            |> report.add_excluded_files([
              report.excluded_file(
                source_path: "src/b_ffi.erl",
                pattern: "src/*_ffi.erl",
                reason: None,
              ),
              report.excluded_file(
                source_path: "src/c_ffi.erl",
                pattern: "src/*_ffi.erl",
                reason: None,
              ),
            ]),
          config: coverage.new()
            |> coverage.no_lcov()
            |> coverage.show_excluded(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File           Lines  Cover   Excluded\n"
          <> "src/a.gleam    1/1    100.0%\n"
          <> "src/b_ffi.erl  excluded: matches src/*_ffi.erl\n"
          <> "src/c_ffi.erl  excluded: matches src/*_ffi.erl\n"
          <> "Total          1/1    100.0%\n"
          <> "Excluded: 2 files\n",
        )
        |> or_fail_with("expected two excluded files")
      }),
      it("counts one ignored line in one file", fn() {
        coverage_reporter.render(
          report: report.new([file_with_ranges("src/a.gleam", [#(5, 5)])]),
          config: coverage.new() |> coverage.no_lcov(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File         Lines  Cover\n"
          <> "src/a.gleam  1/1    100.0%\n"
          <> "Total        1/1    100.0%\n"
          <> "Excluded: 1 line in 1 file\n",
        )
        |> or_fail_with("expected 1 line in 1 file")
      }),
      it("counts ignored lines over several files", fn() {
        coverage_reporter.render(
          report: report.new([
            file_with_ranges("src/a.gleam", [#(5, 7), #(9, 9)]),
            file_with_ranges("src/b.gleam", []),
            file_with_ranges("src/c.gleam", [#(2, 4)]),
          ]),
          config: coverage.new() |> coverage.no_lcov(),
        )
        |> should
        |> be_equal(
          "\nCoverage\n"
          <> "File         Lines  Cover\n"
          <> "src/a.gleam  1/1    100.0%\n"
          <> "src/b.gleam  1/1    100.0%\n"
          <> "src/c.gleam  1/1    100.0%\n"
          <> "Total        3/3    100.0%\n"
          <> "Excluded: 7 lines in 2 files\n",
        )
        |> or_fail_with("expected 7 lines in 2 files")
      }),
    ]),

    group("render_failure", [
      it("describes SourceDirectoryNotFound", fn() {
        render_failure_for(SourceDirectoryNotFound("lib"))
        |> should
        |> be_equal(failure_block(
          "Could not find the source directory \"lib\".",
          "coverage measures the .gleam and .erl files in this directory, and no directory with this name exists where the tests run.",
          "run `gleam test` from the project root, or set the path with coverage.source_directory(...).",
        ))
        |> or_fail_with("expected the SourceDirectoryNotFound message")
      }),
      it("describes SourceDirectoryOutsideSourceRoot", fn() {
        render_failure_for(SourceDirectoryOutsideSourceRoot("lib"))
        |> should
        |> be_equal(failure_block(
          "Could not measure the source directory \"lib\".",
          "module names start at the src, test or dev folder, so coverage can only measure one of those folders or a folder inside one.",
          "set coverage.source_directory(...) to src, test, dev or a folder inside one of them, for example src/app.",
        ))
        |> or_fail_with("expected the SourceDirectoryOutsideSourceRoot message")
      }),
      it("describes NoSourceFiles", fn() {
        render_failure_for(NoSourceFiles("lib"))
        |> should
        |> be_equal(failure_block(
          "Found no .gleam or .erl files in the source directory \"lib\".",
          "the directory exists, but coverage has nothing in it to measure.",
          "set the directory that holds your code with coverage.source_directory(...).",
        ))
        |> or_fail_with("expected the NoSourceFiles message")
      }),
      it("describes NativeCoverageUnsupported", fn() {
        render_failure_for(NativeCoverageUnsupported("26", "emu"))
        |> should
        |> be_equal(failure_block(
          "Could not count lines in this Erlang runtime (Erlang/OTP 26, emu emulator).",
          "coverage uses the native line counters of the BEAM, which need Erlang/OTP 27 or later with the JIT.",
          "run the tests on Erlang/OTP 27 or later, on a platform where the JIT is on (x86-64 or ARM64).",
        ))
        |> or_fail_with("expected the NativeCoverageUnsupported message")
      }),
      it("describes CompilerNotLoaded", fn() {
        render_failure_for(CompilerNotLoaded(EmbeddedMode, "embedded"))
        |> should
        |> be_equal(failure_block(
          "Could not load the Erlang compiler.",
          "coverage compiles each module again with line counters, and the compile module did not load (embedded).",
          "install the Erlang compiler application. In embedded mode, load it when the BEAM starts.",
        ))
        |> or_fail_with("expected the CompilerNotLoaded message")
      }),
      it("describes ModuleAlreadyMeasured", fn() {
        render_failure_for(ModuleAlreadyMeasured(
          "app@cart",
          "src/app/cart.gleam",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not measure module app@cart (src/app/cart.gleam).",
          "another coverage run in this BEAM already measures this module, and two runs cannot share its line counters.",
          "finish the other run with coverage.finish first, or give each run a source directory that the other does not measure.",
        ))
        |> or_fail_with("expected the ModuleAlreadyMeasured message")
      }),
      it("describes ModuleNotLoaded with ModuleNotBuilt", fn() {
        render_failure_for(ModuleNotLoaded(
          "app@cart",
          "src/app/cart.gleam",
          ModuleNotBuilt,
          "nofile",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not load module app@cart (src/app/cart.gleam).",
          "no compiled .beam file for this module is on the code path (nofile).",
          "run the tests with `gleam test`, which builds every module first. If the module has a compile error, fix it.",
        ))
        |> or_fail_with(
          "expected the ModuleNotLoaded with ModuleNotBuilt message",
        )
      }),
      it("describes ModuleNotLoaded with OnLoadFailed", fn() {
        render_failure_for(ModuleNotLoaded(
          "app@cart",
          "src/app/cart.gleam",
          OnLoadFailed,
          "on_load_failure",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not load module app@cart (src/app/cart.gleam).",
          "the module's on_load function failed (on_load_failure).",
          "run the tests without coverage to see the on_load error, then fix it.",
        ))
        |> or_fail_with(
          "expected the ModuleNotLoaded with OnLoadFailed message",
        )
      }),
      it("describes ModuleNotLoaded with BadBeamFile", fn() {
        render_failure_for(ModuleNotLoaded(
          "app@cart",
          "src/app/cart.gleam",
          BadBeamFile,
          "badfile",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not load module app@cart (src/app/cart.gleam).",
          "the .beam file is damaged or was built for another Erlang version (badfile).",
          "delete the build directory and run `gleam test` again.",
        ))
        |> or_fail_with("expected the ModuleNotLoaded with BadBeamFile message")
      }),
      it("describes ModuleNotLoaded with EmbeddedMode", fn() {
        render_failure_for(ModuleNotLoaded(
          "app@cart",
          "src/app/cart.gleam",
          EmbeddedMode,
          "embedded",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not load module app@cart (src/app/cart.gleam).",
          "the BEAM runs in embedded mode, which only loads the modules listed when it starts (embedded).",
          "run the tests in interactive mode (the default), or load the module before coverage starts.",
        ))
        |> or_fail_with(
          "expected the ModuleNotLoaded with EmbeddedMode message",
        )
      }),
      it("describes NoLcovFilesMatched", fn() {
        render_failure_for(NoLcovFilesMatched("build/coverage/parts/*.info"))
        |> should
        |> be_equal(failure_block(
          "No LCOV files match \"build/coverage/parts/*.info\".",
          "coverage.merge_lcov(...) adds coverage written by other runs, and nothing has written a file that matches this pattern.",
          "check that the other runs write their LCOV files to a path that matches before this run finishes, or remove coverage.merge_lcov(...).",
        ))
        |> or_fail_with("expected the NoLcovFilesMatched message")
      }),
      it("describes LcovReadFailed", fn() {
        render_failure_for(LcovReadFailed(
          "parts/a.info",
          IsDirectory("parts/a.info"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read the LCOV file \"parts/a.info\" to merge it.",
          "the file matches coverage.merge_lcov(...), but it cannot be read (Is a directory: parts/a.info).",
          "check that the path is a readable file, or change the pattern so it only matches LCOV files.",
        ))
        |> or_fail_with("expected the LcovReadFailed message")
      }),
      it("describes MalformedLcov", fn() {
        render_failure_for(MalformedLcov(
          "parts/a.info",
          3,
          "DA:x,1",
          "DA must be DA:line,count.",
        ))
        |> should
        |> be_equal(failure_block(
          "The LCOV file \"parts/a.info\" is not valid at line 3 (\"DA:x,1\").",
          "DA must be DA:line,count.",
          "check the tool that wrote this file, or delete the file and run the tests again.",
        ))
        |> or_fail_with("expected the MalformedLcov message")
      }),
      it("describes LcovSourceNotFound", fn() {
        render_failure_for(LcovSourceNotFound("parts/a.info", "src/gone.gleam"))
        |> should
        |> be_equal(failure_block(
          "The LCOV file \"parts/a.info\" covers \"src/gone.gleam\", which does not exist.",
          "merged coverage must be for files in this project, and SF paths are read from the directory the tests run in.",
          "write SF paths relative to the project root, or delete LCOV files left from an older version of the code.",
        ))
        |> or_fail_with("expected the LcovSourceNotFound message")
      }),
      it("describes ExcludeMatchedNothing", fn() {
        render_failure_for(ExcludeMatchedNothing("src/gen/**", "src"))
        |> should
        |> be_equal(failure_block(
          "No source file matches the exclude pattern \"src/gen/**\".",
          "coverage.exclude(...) leaves files out of coverage, and no .gleam or .erl file in the source directory \"src\" matches this pattern.",
          "write the pattern relative to the directory the tests run in, for example \"src/app/generated/**\", or remove coverage.exclude(...).",
        ))
        |> or_fail_with("expected the ExcludeMatchedNothing message")
      }),
      it("describes EverySourceFileExcluded", fn() {
        render_failure_for(EverySourceFileExcluded("src/app"))
        |> should
        |> be_equal(failure_block(
          "Every .gleam and .erl file in the source directory \"src/app\" is excluded.",
          "the coverage.exclude(...) patterns match all of the files, so coverage has nothing to measure.",
          "make the coverage.exclude(...) patterns match fewer files, or set the directory that holds your code with coverage.source_directory(...).",
        ))
        |> or_fail_with("expected the EverySourceFileExcluded message")
      }),
      it("describes SourceReadFailed", fn() {
        render_failure_for(SourceReadFailed(
          "src/app/cart.gleam",
          PermissionDenied("src/app/cart.gleam"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read the source file \"src/app/cart.gleam\" to find its coverage:ignore markers.",
          "coverage reads the markers of each measured file and of each file that a merged LCOV file covers, but this file cannot be read (Permission denied: src/app/cart.gleam).",
          "make the file readable by the user that runs the tests.",
        ))
        |> or_fail_with("expected the SourceReadFailed message")
      }),
      it("describes IgnoreStartWithoutEnd", fn() {
        render_failure_for(IgnoreStartWithoutEnd("src/app/cart.gleam", 12))
        |> should
        |> be_equal(failure_block(
          "The coverage:ignore-start marker at src/app/cart.gleam:12 has no coverage:ignore-end marker after it.",
          "an ignored block runs from a coverage:ignore-start marker to the next coverage:ignore-end marker, so this block has no last line.",
          "add a coverage:ignore-end marker on its own line after the last line to ignore.",
        ))
        |> or_fail_with("expected the IgnoreStartWithoutEnd message")
      }),
      it("describes IgnoreEndWithoutStart", fn() {
        render_failure_for(IgnoreEndWithoutStart("src/app/cart.gleam", 20))
        |> should
        |> be_equal(failure_block(
          "The coverage:ignore-end marker at src/app/cart.gleam:20 has no coverage:ignore-start marker before it.",
          "a coverage:ignore-end marker closes the block that a coverage:ignore-start marker opened, and no block is open at this line.",
          "add a coverage:ignore-start marker on its own line before the first line to ignore, or remove this marker.",
        ))
        |> or_fail_with("expected the IgnoreEndWithoutStart message")
      }),
      it("describes NestedIgnoreStart", fn() {
        render_failure_for(NestedIgnoreStart("src/app/cart.gleam", 15, 9))
        |> should
        |> be_equal(failure_block(
          "The coverage:ignore-start marker at src/app/cart.gleam:15 is inside the ignored block that starts at line 9.",
          "ignored blocks cannot be nested, so each coverage:ignore-start marker needs a coverage:ignore-end marker before the next coverage:ignore-start marker.",
          "add a coverage:ignore-end marker before line 15, or remove one of the two coverage:ignore-start markers.",
        ))
        |> or_fail_with("expected the NestedIgnoreStart message")
      }),
      it("describes IgnoreFunctionWithoutFunction", fn() {
        render_failure_for(IgnoreFunctionWithoutFunction(
          "src/app/cart.gleam",
          30,
        ))
        |> should
        |> be_equal(failure_block(
          "The coverage:ignore-function marker at src/app/cart.gleam:30 is not followed by a complete function.",
          "a coverage:ignore-function marker ignores the whole function after it, but the code after this marker is not a function, or the file ends before the function ends.",
          "put the marker on its own line directly above a function (doc comments and attributes can be between them), or use coverage:ignore-start and coverage:ignore-end for other code.",
        ))
        |> or_fail_with("expected the IgnoreFunctionWithoutFunction message")
      }),
      it("describes ExcludeWithoutReason", fn() {
        render_failure_for(ExcludeWithoutReason("src/app/generated/**"))
        |> should
        |> be_equal(failure_block(
          "The exclude pattern \"src/app/generated/**\" has no reason.",
          "coverage.require_exclusion_reasons() is on, so every exclude pattern must say why its files are left out of coverage.",
          "replace coverage.exclude(...) with coverage.exclude_with_reason(pattern: \"src/app/generated/**\", reason: \"...\").",
        ))
        |> or_fail_with("expected the ExcludeWithoutReason message")
      }),
      it("describes IgnoreMarkerWithoutReason", fn() {
        render_failure_for(IgnoreMarkerWithoutReason(
          "src/app/cart.gleam",
          40,
          "coverage:ignore-start",
        ))
        |> should
        |> be_equal(failure_block(
          "The coverage:ignore-start marker at src/app/cart.gleam:40 has no reason.",
          "coverage.require_exclusion_reasons() is on, so every coverage:ignore marker must say why its lines are left out of coverage.",
          "write the reason after the marker on the same line, for example \"coverage:ignore-start debug only\".",
        ))
        |> or_fail_with("expected the IgnoreMarkerWithoutReason message")
      }),
      it("describes ModuleNotInstrumented with NoDebugInfo", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          NoDebugInfo,
          "{ok,{app@cart,[{abstract_code,no_abstract_code}]}}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "the .beam file has no debug information, so coverage cannot read the module's code ({ok,{app@cart,[{abstract_code,no_abstract_code}]}}).",
          "build with `gleam test` or `gleam build`, which keep debug information, and do not strip the .beam files.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with NoDebugInfo message",
        )
      }),
      it("describes ModuleNotInstrumented with EncryptedDebugInfo", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          EncryptedDebugInfo,
          "{error,beam_lib,{key_missing_or_invalid,\"app@cart.beam\",abstract_code}}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "the debug information in the .beam file is encrypted ({error,beam_lib,{key_missing_or_invalid,\"app@cart.beam\",abstract_code}}).",
          "build this module without encrypted debug information.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with EncryptedDebugInfo message",
        )
      }),
      it("describes ModuleNotInstrumented with DebugInfoUnreadable", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          DebugInfoUnreadable,
          "{error,beam_lib,{file_error,\"app@cart.beam\",enoent}}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "the debug information in the .beam file could not be read ({error,beam_lib,{file_error,\"app@cart.beam\",enoent}}).",
          "run `gleam test` again, and do not delete or change .beam files while the tests run.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with DebugInfoUnreadable message",
        )
      }),
      it("describes ModuleNotInstrumented with AlreadyInstrumented", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          AlreadyInstrumented,
          "{coverage_mode,line_counters}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "another tool, such as cover, already gave this module line counters ({coverage_mode,line_counters}).",
          "do not run another coverage tool, or call cover yourself, in the same test run.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with AlreadyInstrumented message",
        )
      }),
      it("describes ModuleNotInstrumented with RecompileFailed", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          RecompileFailed,
          "{error,[],[]}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "the Erlang compiler could not compile the module again with line counters ({error,[],[]}).",
          "run the tests without coverage to check that the module builds. If it does, report the error with the text in brackets.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with RecompileFailed message",
        )
      }),
      it("describes ModuleNotInstrumented with OldCodeInUse", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          OldCodeInUse,
          "{old_code_in_use,[<0.90.0>]}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "a process still runs an older version of this module, and loading the module with line counters would kill that process ({old_code_in_use,[<0.90.0>]}).",
          "start coverage before code loads a new version of this module, or stop the processes that run the older version.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with OldCodeInUse message",
        )
      }),
      it("describes ModuleNotInstrumented with InstrumentedLoadFailed", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          InstrumentedLoadFailed,
          "on_load_failure",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not add line counters to module app@cart (src/app/cart.gleam).",
          "the module with line counters could not be loaded (on_load_failure).",
          "run the tests without coverage to check that the module loads, then try again.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with InstrumentedLoadFailed message",
        )
      }),
      it("describes ModuleNotAnalysed with NotInstrumented", fn() {
        render_failure_for(ModuleNotAnalysed(
          "app@cart",
          "src/app/cart.gleam",
          NotInstrumented,
          "\"app@cart.beam\"",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read coverage for module app@cart (src/app/cart.gleam).",
          "the module lost its line counters during the run, because it was loaded again or deleted (\"app@cart.beam\").",
          "do not load new versions of measured modules, or call cover, from the tests.",
        ))
        |> or_fail_with(
          "expected the ModuleNotAnalysed with NotInstrumented message",
        )
      }),
      it("describes SessionAlreadyFinished", fn() {
        render_failure_for(SessionAlreadyFinished)
        |> should
        |> be_equal(failure_block(
          "Could not finish the coverage session.",
          "coverage.finish already ran for this session, so the session no longer owns any line counters.",
          "call coverage.finish once for each session that coverage.start returns.",
        ))
        |> or_fail_with("expected the SessionAlreadyFinished message")
      }),
      it("describes JsonWriteFailed", fn() {
        render_failure_for(JsonWriteFailed("out", IsDirectory("out")))
        |> should
        |> be_equal(failure_block(
          "Could not write the JSON summary \"out\".",
          "the path is a directory, not a file (Is a directory: out).",
          "give a file name with coverage.json_path(...), for example build/coverage/coverage.json.",
        ))
        |> or_fail_with("expected the JsonWriteFailed message")
      }),
      it("describes CoberturaWriteFailed", fn() {
        render_failure_for(CoberturaWriteFailed(
          "out.xml",
          PermissionDenied("out.xml"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not write the Cobertura XML file \"out.xml\".",
          "there is no permission to write to this path (Permission denied: out.xml).",
          "choose a writable path with coverage.cobertura_path(...), or fix the folder permissions.",
        ))
        |> or_fail_with("expected the CoberturaWriteFailed message")
      }),
      it("describes MarkdownWriteFailed", fn() {
        render_failure_for(MarkdownWriteFailed("out.md", NotFound("out.md")))
        |> should
        |> be_equal(failure_block(
          "Could not write the Markdown summary \"out.md\".",
          "a folder in the path does not exist and could not be created (File not found: out.md).",
          "check the path given to coverage.markdown_path(...).",
        ))
        |> or_fail_with("expected the MarkdownWriteFailed message")
      }),
      it("describes HtmlWriteFailed", fn() {
        render_failure_for(HtmlWriteFailed(
          "html/index.html",
          NotFound("html/index.html"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not write the HTML coverage page \"html/index.html\".",
          "a folder in the path does not exist and could not be created (File not found: html/index.html).",
          "check the path given to coverage.html_path(...).",
        ))
        |> or_fail_with("expected the HtmlWriteFailed message")
      }),
      it("describes HtmlWriteFailed with IsDirectory", fn() {
        render_failure_for(HtmlWriteFailed(
          "html/index.html",
          IsDirectory("html/index.html"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not write the HTML coverage page \"html/index.html\".",
          "the path is a directory, not a file (Is a directory: html/index.html).",
          "delete the folder at this path, or give another directory to coverage.html_path(...).",
        ))
        |> or_fail_with("expected the HtmlWriteFailed IsDirectory message")
      }),
      it("describes HtmlSourceReadFailed", fn() {
        render_failure_for(HtmlSourceReadFailed(
          "src/a.gleam",
          PermissionDenied("src/a.gleam"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read the source file \"src/a.gleam\" to show it in the HTML coverage report.",
          "the HTML report shows the source of each measured file, but this file cannot be read (Permission denied: src/a.gleam).",
          "make the file readable by the user that runs the tests, or remove coverage.html_path(...).",
        ))
        |> or_fail_with("expected the HtmlSourceReadFailed message")
      }),
      it("describes HtmlFileWriteFailed with IsDirectory", fn() {
        render_failure_for(HtmlFileWriteFailed(
          "build/all.html",
          IsDirectory("build/all.html"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not write the combined HTML coverage page \"build/all.html\".",
          "the path is a directory, not a file (Is a directory: build/all.html).",
          "give a file name with coverage.html_file(...), for example build/coverage/all.html.",
        ))
        |> or_fail_with("expected the HtmlFileWriteFailed message")
      }),
      it("describes HtmlFileSourceReadFailed", fn() {
        render_failure_for(HtmlFileSourceReadFailed(
          "src/a.gleam",
          PermissionDenied("src/a.gleam"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read the source file \"src/a.gleam\" to show it in the combined HTML coverage page.",
          "the combined HTML page shows the source of each measured file, but this file cannot be read (Permission denied: src/a.gleam).",
          "make the file readable by the user that runs the tests, or remove coverage.html_file(...).",
        ))
        |> or_fail_with("expected the HtmlFileSourceReadFailed message")
      }),
      it("describes HtmlDeleteFailed", fn() {
        render_failure_for(HtmlDeleteFailed(
          "html/files",
          FileSystemError("html/files", "eexist"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not delete the old HTML coverage pages in \"html/files\".",
          "coverage.html_path(...) deletes this folder before it writes new pages, so that no page of a removed source file stays, but the folder cannot be deleted (File error (eexist): html/files).",
          "make this folder and everything in it writable by the user that runs the tests, or delete the folder yourself.",
        ))
        |> or_fail_with("expected the HtmlDeleteFailed message")
      }),
      it("describes LcovWriteFailed with PermissionDenied", fn() {
        render_failure_for(LcovWriteFailed(
          "out.info",
          PermissionDenied("out.info"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not write the LCOV file \"out.info\".",
          "there is no permission to write to this path (Permission denied: out.info).",
          "choose a writable path with coverage.lcov_path(...), or fix the folder permissions.",
        ))
        |> or_fail_with(
          "expected the LcovWriteFailed with PermissionDenied message",
        )
      }),
      it("describes LcovWriteFailed with IsDirectory", fn() {
        render_failure_for(LcovWriteFailed("out", IsDirectory("out")))
        |> should
        |> be_equal(failure_block(
          "Could not write the LCOV file \"out\".",
          "the path is a directory, not a file (Is a directory: out).",
          "give a file name with coverage.lcov_path(...), for example build/coverage/lcov.info.",
        ))
        |> or_fail_with("expected the LcovWriteFailed with IsDirectory message")
      }),
      it("describes LcovWriteFailed with NoSpace", fn() {
        render_failure_for(LcovWriteFailed("out.info", NoSpace("out.info")))
        |> should
        |> be_equal(failure_block(
          "Could not write the LCOV file \"out.info\".",
          "the disk is full (No space left on device: out.info).",
          "free disk space and run the tests again.",
        ))
        |> or_fail_with("expected the LcovWriteFailed with NoSpace message")
      }),
      it("describes LcovWriteFailed with NotFound", fn() {
        render_failure_for(LcovWriteFailed("a/out.info", NotFound("a/out.info")))
        |> should
        |> be_equal(failure_block(
          "Could not write the LCOV file \"a/out.info\".",
          "a folder in the path does not exist and could not be created (File not found: a/out.info).",
          "check the path given to coverage.lcov_path(...).",
        ))
        |> or_fail_with("expected the LcovWriteFailed with NotFound message")
      }),
      it("describes LcovWriteFailed with FileSystemError", fn() {
        render_failure_for(LcovWriteFailed(
          "a/out.info",
          FileSystemError("a/out.info", "enotdir"),
        ))
        |> should
        |> be_equal(failure_block(
          "Could not write the LCOV file \"a/out.info\".",
          "the file system returned an error (File error (enotdir): a/out.info).",
          "check the path given to coverage.lcov_path(...). Every part before the file name must be a folder.",
        ))
        |> or_fail_with(
          "expected the LcovWriteFailed with FileSystemError message",
        )
      }),
      it("describes InvalidEnvironmentValue", fn() {
        render_failure_for(InvalidEnvironmentValue(
          name: "DREAM_TEST_COVERAGE",
          value: "yes",
        ))
        |> should
        |> be_equal(failure_block(
          "The environment variable DREAM_TEST_COVERAGE has the value \"yes\", which does not turn coverage on or off.",
          "runner.coverage_from_environment(...) turns coverage on for 1 or true and off for 0 or false, and it does not guess what other values mean.",
          "set DREAM_TEST_COVERAGE to 1 or true to measure coverage, or set it to 0 or false (or remove it) to run without coverage.",
        ))
        |> or_fail_with("expected the InvalidEnvironmentValue message")
      }),
      it("describes InvalidMinimumPercent", fn() {
        render_failure_for(InvalidMinimumPercent(120.0))
        |> should
        |> be_equal(failure_block(
          "The coverage minimum 120.0 is not a percent.",
          "coverage.minimum_percent(...) takes a value from 0.0 to 100.0.",
          "pass a value from 0.0 to 100.0, for example coverage.minimum_percent(80.0).",
        ))
        |> or_fail_with("expected the InvalidMinimumPercent message")
      }),
      it("names failed tests together with a coverage error", fn() {
        coverage_reporter.render_failure(
          error: NoSourceFiles("lib"),
          outcome: RunOutcome(passed: 3, failed: 2, exit_on_failure: True),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Found no .gleam or .erl files in the source directory \"lib\".\n"
          <> "  Reason: the directory exists, but coverage has nothing in it to measure.\n"
          <> "  Fix: set the directory that holds your code with coverage.source_directory(...).\n"
          <> "\nTests: 3 passed, 2 failed. Exit status 1, because tests failed and coverage did not complete.\n",
        )
        |> or_fail_with("expected the block with failed tests")
      }),
      it("says the exit status is unchanged without exit_on_failure", fn() {
        coverage_reporter.render_failure(
          error: NoSourceFiles("lib"),
          outcome: RunOutcome(passed: 3, failed: 0, exit_on_failure: False),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Found no .gleam or .erl files in the source directory \"lib\".\n"
          <> "  Reason: the directory exists, but coverage has nothing in it to measure.\n"
          <> "  Fix: set the directory that holds your code with coverage.source_directory(...).\n"
          <> "\nTests: 3 passed. The exit status is not changed, because exit_on_failure is off.\n",
        )
        |> or_fail_with("expected the block without exit_on_failure")
      }),
      it("explains exit status 1 for a coverage minimum", fn() {
        coverage_reporter.render_failure(
          error: BelowMinimumPercent(
            hit: 2,
            total: 6,
            minimum_percent: 50.0,
            lines_needed: 3,
          ),
          outcome: passing_outcome(),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Coverage 33.3% is below the minimum 50.0% (needs 1 more line).\n"
          <> "  Reason: 2 of 6 executable lines ran, and the minimum needs 3.\n"
          <> "  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).\n"
          <> "\nTests: 3 passed. Exit status 1, because coverage is below the minimum.\n",
        )
        |> or_fail_with("expected the below minimum block")
      }),
      it("counts several missing lines for a coverage minimum", fn() {
        coverage_reporter.render_failure(
          error: BelowMinimumPercent(
            hit: 1567,
            total: 2230,
            minimum_percent: 80.0,
            lines_needed: 1784,
          ),
          outcome: passing_outcome(),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Coverage 70.2% is below the minimum 80.0% (needs 217 more lines).\n"
          <> "  Reason: 1567 of 2230 executable lines ran, and the minimum needs 1784.\n"
          <> "  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).\n"
          <> "\nTests: 3 passed. Exit status 1, because coverage is below the minimum.\n",
        )
        |> or_fail_with("expected 217 more lines")
      }),
      it("names failed tests together with a coverage minimum", fn() {
        coverage_reporter.render_failure(
          error: BelowMinimumPercent(
            hit: 2,
            total: 6,
            minimum_percent: 50.0,
            lines_needed: 3,
          ),
          outcome: RunOutcome(passed: 3, failed: 1, exit_on_failure: True),
        )
        |> should
        |> be_equal(
          "\nCoverage failed\n"
          <> "  Coverage 33.3% is below the minimum 50.0% (needs 1 more line).\n"
          <> "  Reason: 2 of 6 executable lines ran, and the minimum needs 3.\n"
          <> "  Fix: add tests for the lines that did not run (coverage.show_missing() lists them), or lower coverage.minimum_percent(...).\n"
          <> "\nTests: 3 passed, 1 failed. Exit status 1, because tests failed and coverage is below the minimum.\n",
        )
        |> or_fail_with("expected the below minimum block with failed tests")
      }),
    ]),
  ])
}
