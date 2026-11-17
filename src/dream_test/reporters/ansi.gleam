//// ANSI colour codes for reporters that print in colour.
////
//// The BDD reporter and the coverage table reporter use this module, so both
//// print the same codes. A custom reporter can use it to colour its output
//// the same way. Each function wraps the text in one style code and the
//// reset code `\u{1b}[0m`. Styles nest: `ansi.bold(ansi.red(text))`.
////
//// ```gleam
//// import dream_test/reporters/ansi
////
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
//// | **Switch**  | `apply_if`                                   |

import gleam/string

/// Wrap text in the red code `31`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.red("Failed")
/// // -> "\u{1b}[31mFailed\u{1b}[0m"
/// ```
pub fn red(text text: String) -> String {
  wrap("31", text)
}

/// Wrap text in the green code `32`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.green("100.0%")
/// // -> "\u{1b}[32m100.0%\u{1b}[0m"
/// ```
pub fn green(text text: String) -> String {
  wrap("32", text)
}

/// Wrap text in the yellow code `33`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.yellow("90.0%")
/// // -> "\u{1b}[33m90.0%\u{1b}[0m"
/// ```
pub fn yellow(text text: String) -> String {
  wrap("33", text)
}

/// Wrap text in the magenta code `35`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.magenta("Skipped")
/// // -> "\u{1b}[35mSkipped\u{1b}[0m"
/// ```
pub fn magenta(text text: String) -> String {
  wrap("35", text)
}

/// Wrap text in the cyan code `36`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.cyan("Feature")
/// // -> "\u{1b}[36mFeature\u{1b}[0m"
/// ```
pub fn cyan(text text: String) -> String {
  wrap("36", text)
}

/// Wrap text in the dim code `2`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.dim("12ms")
/// // -> "\u{1b}[2m12ms\u{1b}[0m"
/// ```
pub fn dim(text text: String) -> String {
  wrap("2", text)
}

/// Wrap text in the bold code `1`.
///
/// ## Parameters
///
/// - `text`: the text to style
///
/// ## Returns
///
/// The text between the style code and the reset code.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.bold("Failures:")
/// // -> "\u{1b}[1mFailures:\u{1b}[0m"
/// ```
pub fn bold(text text: String) -> String {
  wrap("1", text)
}

/// Apply a style only when colour is on.
///
/// A reporter with a colour option can call this for each piece of text, in
/// place of a `case` on the option at each call.
///
/// ## Parameters
///
/// - `enabled`: `True` to apply the style, `False` to give the text as it is
/// - `style`: the style to apply, for example `ansi.red`
/// - `text`: the text to style
///
/// ## Returns
///
/// The styled text when `enabled` is `True`, otherwise the same text.
///
/// ## Example
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// ansi.apply_if(enabled: True, style: ansi.red, text: "Failed")
/// // -> "\u{1b}[31mFailed\u{1b}[0m"
///
/// ansi.apply_if(enabled: False, style: ansi.red, text: "Failed")
/// // -> "Failed"
/// ```
pub fn apply_if(
  enabled enabled: Bool,
  style style: fn(String) -> String,
  text text: String,
) -> String {
  case enabled {
    True -> style(text)
    False -> text
  }
}

fn wrap(code: String, text: String) -> String {
  string.concat(["\u{1b}[", code, "m", text, "\u{1b}[0m"])
}
