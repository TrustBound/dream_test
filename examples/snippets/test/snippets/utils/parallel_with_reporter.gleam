import dream_test/matchers.{succeed}
import dream_test/parallel
import dream_test/reporters/progress
import dream_test/reporters/types as reporter_types
import dream_test/types.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{type Option, None, Some}

pub fn suite() -> TestSuite(Nil) {
  describe("suite", [
    it("passes", fn() { Ok(succeed()) }),
  ])
}

fn write_if_some(text: Option(String), write: fn(String) -> Nil) {
  case text {
    Some(s) -> write(s)
    None -> Nil
  }
}

pub fn main() {
  let total = 1
  let completed = 0

  let reporter = progress.new()
  let write = fn(_s: String) { Nil }

  progress.handle_event(reporter, reporter_types.RunStarted(total: total))
  |> write_if_some(write)

  let parallel_result =
    parallel.run_root_parallel_with_reporter(
      parallel.RunRootParallelWithReporterConfig(
        config: parallel.default_config(),
        suite: suite(),
        progress_reporter: Some(reporter),
        write: write,
        total: total,
        completed: completed,
      ),
    )
  let parallel.RunRootParallelWithReporterResult(
    results: results,
    completed: completed_after_suite,
    progress_reporter: _progress_reporter,
  ) = parallel_result

  progress.handle_event(
    reporter,
    reporter_types.RunFinished(
      completed: completed_after_suite,
      total: total,
      results: results,
    ),
  )
  |> write_if_some(write)

  results
}
