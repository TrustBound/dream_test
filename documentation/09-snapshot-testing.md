## Snapshot testing

### Mental model

A snapshot test compares current output against a stored “golden file”:

- If the snapshot file is missing, Dream Test creates it.
- If it exists, Dream Test compares content and fails on a diff.

Snapshot testing is for “this output should stay stable” assertions:

- HTML rendering
- JSON output
- formatted reports
- pretty-printed data structures

### When snapshot tests are a good fit

- You want confidence that output didn’t change unexpectedly.
- The output is large/structured enough that writing a manual assertion would be noisy.

### When to avoid snapshots

- The output includes inherently unstable data (timestamps, random IDs) unless you normalize it.
- The output is so small that a direct `equal(...)` is clearer.

### String snapshots + `inspect` snapshots

```gleam
import dream_test/assertions/should.{
  equal, match_snapshot, match_snapshot_inspect, or_fail_with, should,
}
import dream_test/matchers/snapshot
import dream_test/reporters
import dream_test/runner
import dream_test/unit.{describe, group, it}
import gleam/int
import gleam/io
import gleam/result
import gleam/string

// Example: A function that renders a user profile as HTML
fn render_profile(name, age) {
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

fn build_config() {
  Config(host: "localhost", port: 8080, debug: True)
}

pub fn tests() {
  describe("Snapshot Testing", [
    group("match_snapshot", [
      it("renders user profile", fn() {
        render_profile("Alice", 30)
        |> should()
        |> match_snapshot("./test/snapshots/user_profile.snap")
        |> or_fail_with("Profile should match snapshot")
      }),
    ]),
    group("match_snapshot_inspect", [
      it("builds config correctly", fn() {
        build_config()
        |> should()
        |> match_snapshot_inspect("./test/snapshots/config.snap")
        |> or_fail_with("Config should match snapshot")
      }),
    ]),
    group("clearing snapshots", [
      it("can clear a single snapshot", fn() {
        // Create a temporary snapshot
        use _ <- result.try(
          "temp content"
          |> should()
          |> match_snapshot("./test/snapshots/temp.snap")
          |> or_fail_with("Should create temp snapshot"),
        )

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
  runner.new([tests()])
  |> runner.reporter(reporters.bdd(io.print, True))
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/matchers/snapshot_testing.gleam)</sub>


