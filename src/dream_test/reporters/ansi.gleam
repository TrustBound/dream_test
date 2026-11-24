//// ANSI colour codes for reporters that print in colour.
////
//// The BDD reporter and the coverage table reporter use this module, so both
//// print the same codes. A custom reporter can use it to colour its output
//// the same way. Each function wraps the text in one style code and the
//// reset code `\u{1b}[0m`. Styles nest: `ansi.bold(ansi.red(text))`.
////
//// ### Color a line range red <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/reporters/ansi
////
//// pub fn red_line_numbers() -> String {
////   ansi.red("12-13")
////   // -> "\u{1b}[31m12-13\u{1b}[0m"
//// }
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
/// ### Color text red <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/red.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn red_failed() -> String {
///   ansi.red("Failed")
///   // -> "\u{1b}[31mFailed\u{1b}[0m"
/// }
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
/// ### Color text green <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/green.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn green_percent() -> String {
///   ansi.green("100.0%")
///   // -> "\u{1b}[32m100.0%\u{1b}[0m"
/// }
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
/// ### Color text yellow <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/yellow.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn yellow_percent() -> String {
///   ansi.yellow("90.0%")
///   // -> "\u{1b}[33m90.0%\u{1b}[0m"
/// }
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
/// ### Color text magenta <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/magenta.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn magenta_skipped() -> String {
///   ansi.magenta("Skipped")
///   // -> "\u{1b}[35mSkipped\u{1b}[0m"
/// }
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
/// ### Color text cyan <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/cyan.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn cyan_feature() -> String {
///   ansi.cyan("Feature")
///   // -> "\u{1b}[36mFeature\u{1b}[0m"
/// }
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
/// ### Dim text <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/dim.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn dim_duration() -> String {
///   ansi.dim("12ms")
///   // -> "\u{1b}[2m12ms\u{1b}[0m"
/// }
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
/// ### Make text bold <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/bold.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn bold_failures() -> String {
///   ansi.bold("Failures:")
///   // -> "\u{1b}[1mFailures:\u{1b}[0m"
/// }
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
/// ### Color text only when color is on <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/reporters/ansi/apply_if.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/reporters/ansi
///
/// pub fn red_when_enabled() -> String {
///   ansi.apply_if(enabled: True, style: ansi.red, text: "Failed")
///   // -> "\u{1b}[31mFailed\u{1b}[0m"
/// }
///
/// pub fn plain_when_disabled() -> String {
///   ansi.apply_if(enabled: False, style: ansi.red, text: "Failed")
///   // -> "Failed"
/// }
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
