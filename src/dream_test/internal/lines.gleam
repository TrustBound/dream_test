//// Text of more than one line in the text reporters.
////
//// A reporter writes a value after a label, such as `Message: `. When the
//// value has more than one line, each line after the first starts at the
//// column of the value, so that the lines stay together under the label.

import gleam/string

/// `text` with `margin` before each line after the first. A `\r\n` line
/// ending becomes `\n`. An empty line gets no margin, so that no line ends
/// with spaces. A text of one line is the same text.
pub fn continue_under(text: String, margin: String) -> String {
  case string.split_once(string.replace(text, "\r\n", "\n"), "\n") {
    Ok(#(first, rest)) ->
      first <> continue_lines(string.split(rest, "\n"), margin)
    Error(Nil) -> text
  }
}

/// Each line on a new line after `margin`, or on a new line alone when it
/// is empty.
fn continue_lines(lines: List(String), margin: String) -> String {
  case lines {
    [] -> ""
    ["", ..rest] -> "\n" <> continue_lines(rest, margin)
    [line, ..rest] -> "\n" <> margin <> line <> continue_lines(rest, margin)
  }
}

/// The spaces that put a line at the column after `label`.
pub fn margin_after(label: String) -> String {
  string.repeat(" ", string.length(label))
}
