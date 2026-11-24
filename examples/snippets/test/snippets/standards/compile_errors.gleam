//// Compiles the "Don't" examples of STANDARDS.md that must not compile,
//// and compares the compiler output with the output file that the doc
//// shows.
////
//// Each example is a file under `compile_errors/` of the snippets
//// project, where the build of this project does not compile it. The test
//// copies it into a new package under `build/compile_errors/`, and compiles
//// that package with `gleam compile-package` against the compiled packages
//// of this project, with no network.

import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}
import gleam/result
import snippets_outputs

/// The folder of the new packages, from the snippets project.
const packages_folder = "build/compile_errors/"

/// The compiled packages of this project, which hold `dream_test`.
const libraries_folder = "build/dev/erlang"

pub fn tests() {
  describe("STANDARDS.md examples that must not compile", [
    it("the fluent matcher is an unknown module", fn() {
      // Act
      let output = compile_example("fluent_builder")

      // Assert
      output
      |> should
      |> be_equal(
        snippets_outputs.read("compile_error_fluent_builder")
        |> result.map(with_exit_status_one)
        |> result.map_error(file.error_to_string),
      )
      |> or_fail_with(
        "expected the compiler output in test/outputs/compile_error_fluent_builder.txt",
      )
    }),
  ])
}

/// The exit status and the output of `gleam compile-package` for the
/// example `compile_errors/<name>.gleam`.
pub fn compile_example(name: String) -> Result(#(Int, String), String) {
  let package = packages_folder <> name
  use source <- result.try(
    file.read("compile_errors/" <> name <> ".gleam")
    |> result.map_error(file.error_to_string),
  )
  use _ <- result.try(
    file.write(package <> "/gleam.toml", package_toml(name))
    |> result.map_error(file.error_to_string),
  )
  use _ <- result.try(
    file.write(package <> "/src/" <> name <> ".gleam", source)
    |> result.map_error(file.error_to_string),
  )
  compile_package(package, package <> "_out", libraries_folder)
  |> result.replace_error("gleam is not on the PATH")
}

/// A package that depends on `dream_test`, so the compiler gives no
/// warning about a transitive dependency.
fn package_toml(name: String) -> String {
  "name = \""
  <> name
  <> "\"\nversion = \"1.0.0\"\n\n[dependencies]\ndream_test = \">= 3.0.0 and < 4.0.0\"\n"
}

fn with_exit_status_one(output: String) -> #(Int, String) {
  #(1, output)
}

@external(erlang, "snippets_compile_error_ffi", "compile_package")
fn compile_package(
  package: String,
  out: String,
  libraries: String,
) -> Result(#(Int, String), Nil)
