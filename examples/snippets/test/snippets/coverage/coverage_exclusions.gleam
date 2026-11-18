import dream_test/coverage
import dream_test/coverage/report.{type CoverageReport}
import dream_test/matchers.{be_equal, be_true, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/list
import gleam/result
import snippets/utils/coverage_lock

pub fn tests() {
  describe("Coverage exclusions", [
    it("lists what is excluded", fn() {
      coverage_config()
      |> coverage.shows_excluded()
      |> should
      |> be_true()
      |> or_fail_with("show_excluded should be on")
    }),
    it("starts and finishes with this config", fn() {
      coverage_lock.with_coverage_lock(measure_app)
      |> result.map(measured_paths)
      |> should
      |> be_equal(Ok(["src/app/cart.gleam"]))
      |> or_fail_with("coverage should accept the config")
    }),
  ])
}

fn coverage_config() {
  coverage.new()
  |> coverage.exclude_with_reason("src/app/internal/**", "debug helpers")
  |> coverage.exclude_with_reason("src/app/generated/**", "generated code")
  |> coverage.require_exclusion_reasons()
  |> coverage.show_excluded()
}

/// Measure `src/app` with the config of the snippet.
fn measure_app() -> Result(CoverageReport, coverage.CoverageError) {
  coverage_config()
  |> coverage.source_directory("src/app")
  |> coverage.no_lcov()
  |> coverage.start()
  |> result.try(coverage.finish)
}

fn measured_paths(coverage_report: CoverageReport) -> List(String) {
  list.map(report.files(coverage_report), report.source_path)
}
