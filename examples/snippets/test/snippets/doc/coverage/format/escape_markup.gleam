import dream_test/coverage/format

pub fn escaped_comparison() -> String {
  format.escape_markup("a < b && c")
  // -> "a &lt; b &amp;&amp; c"
}
