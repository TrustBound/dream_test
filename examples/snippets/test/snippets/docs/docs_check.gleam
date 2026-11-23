//// Runs the docs check of `dream_snippets` on the whole repository.
////
//// The check reads the README, the guides, the changelog, the release
//// notes, `STANDARDS.md`, `CONTRIBUTING.md` and the doc comments of
//// `src/`, with the settings in the `[tools.dream_snippets]` table of the
//// root `gleam.toml`. The 2.x code of the upgrade guide is compared with
//// the files at its release tag, so the clone needs its tags.
////
//// `make check-snippets` runs `main` of this module, and `snippets_test`
//// runs `tests`, so `make test` fails when a block is not proven.

import dream_snippets
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/io
import gleam/list
import gleam/string

/// The root of the repository, from the snippets project.
const root = "../.."

pub fn tests() {
  describe("Docs check", [
    it("dream_snippets finds no problem in the docs", fn() {
      // Act
      let output = dream_snippets.output(dream_snippets.check_project(root))

      // Assert
      output.exit_status
      |> should
      |> be_equal(0)
      |> or_fail_with(
        list.append(output.standard_output, output.standard_error)
        |> string.join("\n"),
      )
    }),
  ])
}

/// Prints each problem and the summary line of the check of the
/// repository root, and stops with exit status 1 when there is a problem.
pub fn main() -> Nil {
  let output = dream_snippets.output(dream_snippets.check_project(root))
  list.each(output.standard_output, io.println)
  list.each(output.standard_error, io.println_error)
  halt(output.exit_status)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil
