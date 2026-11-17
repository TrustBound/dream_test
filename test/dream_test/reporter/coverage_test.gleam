//// Black-box tests of `dream_test/reporters/coverage`.

import dream_test/coverage.{
  type CoverageError, AlreadyInstrumented, BadBeamFile, BelowMinimumPercent,
  CoverAlreadyRunning, CoverDidNotStart, CoverStartFailed, EmbeddedMode,
  EncryptedDebugInfo, InstrumentedLoadFailed, InvalidMinimumPercent,
  LcovReadFailed, LcovSourceNotFound, LcovWriteFailed, MalformedLcov,
  ModuleNotAnalysed, ModuleNotBuilt, ModuleNotInstrumented, ModuleNotLoaded,
  NoDebugInfo, NoLcovFilesMatched, NoSourceFiles, NotInstrumented, OnLoadFailed,
  SourceDirectoryNotFound, SourceDirectoryOutsideSourceRoot,
  UnknownAnalysisError, UnknownInstrumentError,
}
import dream_test/coverage/report.{type LineCoverage, LineCoverage}
import dream_test/file.{
  FileSystemError, IsDirectory, NoSpace, NotFound, PermissionDenied,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/coverage.{RunOutcome} as coverage_reporter
import dream_test/unit.{describe, group, it}
import gleam/list

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
      it("describes CoverStartFailed with CoverAlreadyRunning", fn() {
        render_failure_for(CoverStartFailed(
          CoverAlreadyRunning,
          "{already_started,<0.90.0>}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not start the BEAM cover tool.",
          "cover is already running, so another coverage run owns it ({already_started,<0.90.0>}).",
          "turn coverage on once with runner.coverage, and do not start cover from a test or another tool in the same run.",
        ))
        |> or_fail_with(
          "expected the CoverStartFailed with CoverAlreadyRunning message",
        )
      }),
      it("describes CoverStartFailed with CoverDidNotStart", fn() {
        render_failure_for(CoverStartFailed(CoverDidNotStart, "timeout"))
        |> should
        |> be_equal(failure_block(
          "Could not start the BEAM cover tool.",
          "cover returned an error (timeout).",
          "check that the Erlang tools application is installed; some minimal Erlang packages leave it out.",
        ))
        |> or_fail_with(
          "expected the CoverStartFailed with CoverDidNotStart message",
        )
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
      it("describes ModuleNotInstrumented with NoDebugInfo", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          NoDebugInfo,
          "{no_abstract_code,\"app@cart.beam\"}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not instrument module app@cart (src/app/cart.gleam) for coverage.",
          "the .beam file has no debug information, so cover cannot read the module's code ({no_abstract_code,\"app@cart.beam\"}).",
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
          "{encrypted_abstract_code,\"app@cart.beam\"}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not instrument module app@cart (src/app/cart.gleam) for coverage.",
          "the debug information in the .beam file is encrypted ({encrypted_abstract_code,\"app@cart.beam\"}).",
          "build this module without encrypted debug information.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with EncryptedDebugInfo message",
        )
      }),
      it("describes ModuleNotInstrumented with AlreadyInstrumented", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          AlreadyInstrumented,
          "{already_cover_compiled,no_beam_found,'app@cart'}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not instrument module app@cart (src/app/cart.gleam) for coverage.",
          "another tool already instrumented this module from source ({already_cover_compiled,no_beam_found,'app@cart'}).",
          "do not run another coverage tool, or call cover yourself, in the same test run.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with AlreadyInstrumented message",
        )
      }),
      it("describes ModuleNotInstrumented with InstrumentedLoadFailed", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          InstrumentedLoadFailed,
          "\"app@cart.beam\"",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not instrument module app@cart (src/app/cart.gleam) for coverage.",
          "cover instrumented the module but could not load the result (\"app@cart.beam\").",
          "run the tests without coverage to check that the module loads, then try again.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with InstrumentedLoadFailed message",
        )
      }),
      it("describes ModuleNotInstrumented with UnknownInstrumentError", fn() {
        render_failure_for(ModuleNotInstrumented(
          "app@cart",
          "src/app/cart.gleam",
          UnknownInstrumentError,
          "non_existing",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not instrument module app@cart (src/app/cart.gleam) for coverage.",
          "cover returned an error (non_existing).",
          "run the tests without coverage to check that the module builds and loads.",
        ))
        |> or_fail_with(
          "expected the ModuleNotInstrumented with UnknownInstrumentError message",
        )
      }),
      it("describes ModuleNotAnalysed with NotInstrumented", fn() {
        render_failure_for(ModuleNotAnalysed(
          "app@cart",
          "src/app/cart.gleam",
          NotInstrumented,
          "{not_cover_compiled,'app@cart'}",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read coverage for module app@cart (src/app/cart.gleam).",
          "the module was no longer instrumented at the end of the run, so something stopped or reset cover during the tests ({not_cover_compiled,'app@cart'}).",
          "do not call cover:stop, cover:reset or cover:compile from tests.",
        ))
        |> or_fail_with(
          "expected the ModuleNotAnalysed with NotInstrumented message",
        )
      }),
      it("describes ModuleNotAnalysed with UnknownAnalysisError", fn() {
        render_failure_for(ModuleNotAnalysed(
          "app@cart",
          "src/app/cart.gleam",
          UnknownAnalysisError,
          "timeout",
        ))
        |> should
        |> be_equal(failure_block(
          "Could not read coverage for module app@cart (src/app/cart.gleam).",
          "cover returned an error (timeout).",
          "run the tests again. If the error repeats, report it with the text in brackets.",
        ))
        |> or_fail_with(
          "expected the ModuleNotAnalysed with UnknownAnalysisError message",
        )
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
