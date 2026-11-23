//// Brief description of what this module does.
////
//// Longer explanation of the module's purpose and how it fits
//// into the overall API.
////
//// ## Basic Pattern
////
//// ```gleam
//// example_usage()
//// |> with_typical_pattern()
//// ```
////
//// ## Available Functions
////
//// | Category    | Functions                    |
//// |-------------|------------------------------|
//// | **Core**    | `foo`, `bar`                 |
//// | **Helpers** | `baz`, `qux`                 |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/your_module.{foo, bar}
//// ```

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, it}

pub fn example_usage() -> String {
  "example"
}

pub fn with_typical_pattern(value: String) -> String {
  value <> " with the typical pattern"
}

pub fn tests() {
  describe("CONTRIBUTING.md: a module with module docs", [
    it("runs the basic pattern of its docs", fn() {
      // Act
      let result =
        example_usage()
        |> with_typical_pattern()

      // Assert
      result
      |> should
      |> be_equal("example with the typical pattern")
      |> or_fail_with("the basic pattern should work")
    }),
  ])
}
