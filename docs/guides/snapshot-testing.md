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

#### String and inspect snapshots <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/matchers/snapshot_testing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{
  be_equal, match_snapshot, match_snapshot_inspect, or_fail_with, should,
}
import dream_test/matchers/snapshot
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
        let path = "./test/snapshots/temp.snap"
        use _ <- result.try(
          "temp content"
          |> should
          |> match_snapshot(path)
          |> or_fail_with("Should create temp snapshot"),
        )

        // Clear it
        let result = snapshot.clear_snapshot(path)

        result
        |> should
        |> be_equal(Ok(Nil))
        |> or_fail_with("Should successfully clear snapshot")
      }),
    ]),
  ])
}
```

### Practical workflow

- **First run**: the snapshot file doesn’t exist → Dream Test creates it.
- **Review**: treat the snapshot like code. Make sure it matches what you intend to guarantee.
- **Future changes**: when it fails, decide whether the change is a regression (fix code) or an intentional update (update snapshot).
- **Commit the `.snap` files**: a missing snapshot is not a failure. The test passes and writes a new file. If CI starts without the file, every snapshot test passes and checks nothing.

### Update a snapshot

1. Delete the `.snap` file, or remove it with `snapshot.clear_snapshot(path)`. `snapshot.clear_snapshots_in_directory(directory)` removes every `.snap` file in a directory, but not in its subdirectories.
2. Run the tests again. The test writes the new value to the file and passes.
3. If you added a `clear_snapshot` or `clear_snapshots_in_directory` call for the update, remove it. If it stays, each run deletes the snapshot and writes it again, so the test checks nothing.
4. Read the new file, then commit it.

### What's Next?

- Go back to [Reporters](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md)
- Go back to [Documentation README](https://github.com/TrustBound/dream_test/blob/main/docs/guides/index.md)
- Continue to [Gherkin / BDD testing](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md)
