## Snapshot testing

Snapshot tests are about turning “a big output blob” into a stable contract.

They’re great when the output is too large or too structural to assert on directly, but they can also become noise if you snapshot things that change frequently.

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

The real “why” is readability: a snapshot test often makes the intent clearer than a dozen micro-assertions.

### When to avoid snapshots

- The output includes inherently unstable data (timestamps, random IDs) unless you normalize it.
- The output is so small that a direct `equal(...)` is clearer.

If your snapshot fails every day for “expected reasons,” it’s no longer buying you safety—it’s training you to ignore diffs.

### String snapshots + `inspect` snapshots

```gleam
import dream_test/matchers.{
  be_equal, match_snapshot, match_snapshot_inspect, or_fail_with, should,
}
import dream_test/matchers/snapshot
import dream_test/reporters/bdd
import dream_test/reporters/progress
import dream_test/runner
import dream_test/unit.{describe, group, it}
import gleam/int
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
        |> should
        |> match_snapshot("./test/snapshots/user_profile.snap")
        |> or_fail_with("Profile should match snapshot")
      }),
    ]),
    group("match_snapshot_inspect", [
      it("builds config correctly", fn() {
        build_config()
        |> should
        |> match_snapshot_inspect("./test/snapshots/config.snap")
        |> or_fail_with("Config should match snapshot")
      }),
    ]),
    group("clearing snapshots", [
      it("can clear a single snapshot", fn() {
        // Create a temporary snapshot
        use _ <- result.try(
          "temp content"
          |> should
          |> match_snapshot("./test/snapshots/temp.snap")
          |> or_fail_with("Should create temp snapshot"),
        )

        // Clear it
        let result = snapshot.clear_snapshot("./test/snapshots/temp.snap")

        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should successfully clear snapshot")
      }),
    ]),
  ])
}

pub fn main() {
  runner.new([tests()])
  |> runner.progress_reporter(progress.new())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

<sub>🧪 [Tested source](../examples/snippets/test/snippets/matchers/snapshots.gleam)</sub>

### Practical workflow

- **First run**: the snapshot file doesn’t exist → Dream Test creates it.
- **Review**: treat the snapshot like code. Make sure it matches what you intend to guarantee.
- **Future changes**: when it fails, decide whether the change is a regression (fix code) or an intentional update (update snapshot).

### What's Next?

- Go back to [Reporters](08-reporters.md)
- Go back to [Documentation README](README.md)
- Continue to [Gherkin / BDD testing](10-gherkin-bdd.md)
