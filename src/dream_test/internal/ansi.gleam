//// ANSI colour codes for the reporters that print in colour.
////
//// This module is internal to dream_test. The BDD reporter and the coverage
//// table reporter use it, so both print the same codes. Each function wraps
//// the text in one style code and the reset code `\u{1b}[0m`.
////
//// ```gleam
//// ansi.red("12-13")
//// // -> "\u{1b}[31m12-13\u{1b}[0m"
//// ```
////
//// ## Available Functions
////
//// | Category    | Functions                                    |
//// |-------------|----------------------------------------------|
//// | **Colours** | `red`, `green`, `yellow`, `magenta`, `cyan`  |
//// | **Styles**  | `dim`, `bold`                                |

import gleam/string

/// Wrap text in the red code `31`.
///
/// ## Example
///
/// ```gleam
/// ansi.red("Failed")
/// // -> "\u{1b}[31mFailed\u{1b}[0m"
/// ```
pub fn red(text text: String) -> String {
  wrap("31", text)
}

/// Wrap text in the green code `32`.
///
/// ## Example
///
/// ```gleam
/// ansi.green("100.0%")
/// // -> "\u{1b}[32m100.0%\u{1b}[0m"
/// ```
pub fn green(text text: String) -> String {
  wrap("32", text)
}

/// Wrap text in the yellow code `33`.
///
/// ## Example
///
/// ```gleam
/// ansi.yellow("90.0%")
/// // -> "\u{1b}[33m90.0%\u{1b}[0m"
/// ```
pub fn yellow(text text: String) -> String {
  wrap("33", text)
}

/// Wrap text in the magenta code `35`.
///
/// ## Example
///
/// ```gleam
/// ansi.magenta("Skipped")
/// // -> "\u{1b}[35mSkipped\u{1b}[0m"
/// ```
pub fn magenta(text text: String) -> String {
  wrap("35", text)
}

/// Wrap text in the cyan code `36`.
///
/// ## Example
///
/// ```gleam
/// ansi.cyan("Feature")
/// // -> "\u{1b}[36mFeature\u{1b}[0m"
/// ```
pub fn cyan(text text: String) -> String {
  wrap("36", text)
}

/// Wrap text in the dim code `2`.
///
/// ## Example
///
/// ```gleam
/// ansi.dim("12ms")
/// // -> "\u{1b}[2m12ms\u{1b}[0m"
/// ```
pub fn dim(text text: String) -> String {
  wrap("2", text)
}

/// Wrap text in the bold code `1`.
///
/// ## Example
///
/// ```gleam
/// ansi.bold("Failures:")
/// // -> "\u{1b}[1mFailures:\u{1b}[0m"
/// ```
pub fn bold(text text: String) -> String {
  wrap("1", text)
}

fn wrap(code: String, text: String) -> String {
  string.concat(["\u{1b}[", code, "m", text, "\u{1b}[0m"])
}
