import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
import dream_test/parallel
import dream_test/runner
import dream_test/types.{
  type Status, type TestResult, Failed, Pending, SetupFailed, Skipped, TimedOut,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/io
import gleam/list
import gleam/string

pub fn render_my_report(results: List(TestResult)) -> String {
  let total = list.length(results)
  let failed = count(results, Failed)
  let timed_out = count(results, TimedOut)
  let setup_failed = count(results, SetupFailed)
  let skipped = count(results, Skipped)
  let pending = count(results, Pending)
  let passed = total - failed - timed_out - setup_failed - skipped - pending

  string.concat([
    "MyReport: ",
    int.to_string(total),
    " total; ",
    int.to_string(passed),
    " passed; ",
    int.to_string(failed + timed_out + setup_failed),
    " failed\n",
  ])
}

fn count(results: List(TestResult), wanted: Status) -> Int {
  count_loop(results, wanted, 0)
}

fn count_loop(results: List(TestResult), wanted: Status, n: Int) -> Int {
  case results {
    [] -> n
    [r, ..rest] ->
      case r.status == wanted {
        True -> count_loop(rest, wanted, n + 1)
        False -> count_loop(rest, wanted, n)
      }
  }
}

pub fn main() {
  let results = runner.new([tests()]) |> runner.run()
  io.print(render_my_report(results))
}

fn example_suite() {
  describe("Example Suite", [
    it("passes", fn() { Ok(succeed()) }),
    it("also passes", fn() { Ok(succeed()) }),
  ])
}

pub fn tests() {
  describe("Custom post-run reporter", [
    it("renders the counts of a run", fn() {
      parallel.run_root_parallel(parallel.default_config(), example_suite())
      |> render_my_report
      |> should
      |> be_equal("MyReport: 2 total; 2 passed; 0 failed\n")
      |> or_fail_with("expected the report line for two passing tests")
    }),
  ])
}
