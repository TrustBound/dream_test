import dream_test/coverage.{
  type CoverageError, type CoverageSession, AnalysisFailed, CoverStartFailed,
  CoverageReport, FileCoverage, LcovWriteFailed, LineCoverage,
  ModuleCompileFailed, ModuleNotLoaded, SourceDirectoryNotFound, error_to_string,
  executable_line_count, hit_line_count, module_name_from_source_path,
  render_lcov, write_lcov,
}
import dream_test/file.{IsDirectory, read}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/process.{unique_port}
import dream_test/unit.{describe, group, it}
import gleam/int
import gleam/option.{None}

fn sample_file() {
  FileCoverage(source_path: "src/app/cart.gleam", lines: [
    LineCoverage(line: 3, calls: 2),
    LineCoverage(line: 4, calls: 0),
    LineCoverage(line: 9, calls: 1),
  ])
}

fn sample_report() {
  CoverageReport(
    files: [
      sample_file(),
      FileCoverage(source_path: "src/app/types.gleam", lines: []),
    ],
    lcov_path: None,
  )
}

/// The start error, or a message when start unexpectedly succeeded.
fn start_error(
  result: Result(CoverageSession, CoverageError),
) -> Result(CoverageError, String) {
  case result {
    Error(error) -> Ok(error)
    Ok(_) -> Error("expected start to fail")
  }
}

pub fn tests() {
  describe("dream_test/coverage", [
    group("module_name_from_source_path", [
      it("joins Gleam module path segments with @", fn() {
        module_name_from_source_path("dream_test/sandbox.gleam")
        |> should
        |> be_equal("dream_test@sandbox")
        |> or_fail_with("expected dream_test@sandbox")
      }),
      it("keeps a top-level Gleam module name", fn() {
        module_name_from_source_path("dream_test.gleam")
        |> should
        |> be_equal("dream_test")
        |> or_fail_with("expected dream_test")
      }),
      it("uses the file name of an Erlang module", fn() {
        module_name_from_source_path("sandbox_ffi.erl")
        |> should
        |> be_equal("sandbox_ffi")
        |> or_fail_with("expected sandbox_ffi")
      }),
      it("ignores directories of a nested Erlang module", fn() {
        module_name_from_source_path("ffi/nested/thing_ffi.erl")
        |> should
        |> be_equal("thing_ffi")
        |> or_fail_with("expected thing_ffi")
      }),
    ]),

    group("line counts", [
      it("hit_line_count counts lines with calls", fn() {
        hit_line_count(sample_file())
        |> should
        |> be_equal(2)
        |> or_fail_with("expected 2 hit lines")
      }),
      it("executable_line_count counts every reported line", fn() {
        executable_line_count(sample_file())
        |> should
        |> be_equal(3)
        |> or_fail_with("expected 3 executable lines")
      }),
    ]),

    group("render_lcov", [
      it("writes one record per file", fn() {
        render_lcov(sample_report())
        |> should
        |> be_equal(
          "TN:\nSF:src/app/cart.gleam\nDA:3,2\nDA:4,0\nDA:9,1\nLF:3\nLH:2\nend_of_record\n"
          <> "TN:\nSF:src/app/types.gleam\nLF:0\nLH:0\nend_of_record\n",
        )
        |> or_fail_with("expected LCOV records for both files")
      }),
      it("renders an empty report as an empty string", fn() {
        render_lcov(CoverageReport(files: [], lcov_path: None))
        |> should
        |> be_equal("")
        |> or_fail_with("expected empty LCOV")
      }),
    ]),

    group("write_lcov", [
      it("writes the LCOV text to the path", fn() {
        let path =
          "./test/tmp/coverage_api_test/lcov_"
          <> int.to_string(unique_port())
          <> ".info"
        let _ = write_lcov(report: sample_report(), path: path)
        read(path)
        |> should
        |> be_equal(Ok(render_lcov(sample_report())))
        |> or_fail_with("expected the file to hold the rendered LCOV")
      }),
      it("returns LcovWriteFailed when the path is a directory", fn() {
        write_lcov(report: sample_report(), path: "./test")
        |> should
        |> be_equal(
          Error(LcovWriteFailed(path: "./test", error: IsDirectory("./test"))),
        )
        |> or_fail_with("expected LcovWriteFailed with IsDirectory")
      }),
    ]),

    group("start", [
      it("returns SourceDirectoryNotFound for a missing directory", fn() {
        let result =
          coverage.new()
          |> coverage.source_directory("./test/tmp/no_such_source_directory")
          |> coverage.start()
        start_error(result)
        |> should
        |> be_equal(
          Ok(SourceDirectoryNotFound("./test/tmp/no_such_source_directory")),
        )
        |> or_fail_with("expected SourceDirectoryNotFound")
      }),
    ]),

    group("error_to_string", [
      it("describes SourceDirectoryNotFound", fn() {
        error_to_string(SourceDirectoryNotFound("lib"))
        |> should
        |> be_equal("Coverage source directory not found: lib")
        |> or_fail_with("expected source directory message")
      }),
      it("describes CoverStartFailed", fn() {
        error_to_string(CoverStartFailed("already_started"))
        |> should
        |> be_equal("Coverage could not start cover: already_started")
        |> or_fail_with("expected cover start message")
      }),
      it("describes ModuleNotLoaded", fn() {
        error_to_string(ModuleNotLoaded("a@b", "nofile"))
        |> should
        |> be_equal("Coverage could not load module a@b: nofile")
        |> or_fail_with("expected module load message")
      }),
      it("describes ModuleCompileFailed", fn() {
        error_to_string(ModuleCompileFailed("a@b", "no_abstract_code"))
        |> should
        |> be_equal(
          "Coverage could not instrument module a@b: no_abstract_code",
        )
        |> or_fail_with("expected module compile message")
      }),
      it("describes AnalysisFailed", fn() {
        error_to_string(AnalysisFailed("a@b", "not_cover_compiled"))
        |> should
        |> be_equal("Coverage could not analyse module a@b: not_cover_compiled")
        |> or_fail_with("expected analysis message")
      }),
      it("describes LcovWriteFailed", fn() {
        error_to_string(LcovWriteFailed("out", IsDirectory("out")))
        |> should
        |> be_equal(
          "Coverage could not write LCOV file out: Is a directory: out",
        )
        |> or_fail_with("expected LCOV write message")
      }),
    ]),
  ])
}
