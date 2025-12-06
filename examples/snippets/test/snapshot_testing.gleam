// Snapshot testing example for dream_test
//
// Run: gleam test
//
// Demonstrates:
// - match_snapshot for string comparisons
// - match_snapshot_inspect for complex data
// - Clearing snapshots programmatically

import dream_test/assertions/should.{
  equal, match_snapshot, match_snapshot_inspect, or_fail_with, should,
}
import dream_test/matchers/snapshot
import dream_test/reporter/bdd.{report}
import dream_test/runner.{exit_on_failure, run_all}
import dream_test/unit.{describe, it, to_test_cases}
import gleam/int
import gleam/io
import gleam/string

// Example: A function that renders a user profile as HTML
fn render_profile(name: String, age: Int) -> String {
  string.concat([
    "<div class=\"profile\">\n",
    "  <h1>",
    name,
    "</h1>\n",
    "  <p>Age: ",
    int.to_string(age),
    "</p>\n",
    "</div>",
  ])
}

// Example: A function that builds a configuration record
pub type Config {
  Config(host: String, port: Int, debug: Bool)
}

fn build_config() -> Config {
  Config(host: "localhost", port: 8080, debug: True)
}

pub fn tests() {
  describe("Snapshot Testing", [
    describe("match_snapshot", [
      it("renders user profile", fn() {
        render_profile("Alice", 30)
        |> should()
        |> match_snapshot("./test/snapshots/user_profile.snap")
        |> or_fail_with("Profile should match snapshot")
      }),
    ]),
    describe("match_snapshot_inspect", [
      it("builds config correctly", fn() {
        build_config()
        |> should()
        |> match_snapshot_inspect("./test/snapshots/config.snap")
        |> or_fail_with("Config should match snapshot")
      }),
    ]),
    describe("clearing snapshots", [
      it("can clear a single snapshot", fn() {
        // Create a temporary snapshot
        "temp content"
        |> should()
        |> match_snapshot("./test/snapshots/temp.snap")
        |> or_fail_with("Should create temp snapshot")

        // Clear it
        let result = snapshot.clear_snapshot("./test/snapshots/temp.snap")

        result
        |> should()
        |> equal(Ok(Nil))
        |> or_fail_with("Should successfully clear snapshot")
      }),
    ]),
  ])
}

pub fn main() {
  to_test_cases("snapshot_testing", tests())
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()
}
