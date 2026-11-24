import dream_test/reporters/diff

pub fn receipt_diff() -> String {
  diff.format(
    expected: "coffee 3.50\ncroissant 2.75\nTOTAL 6.25",
    actual: "coffee 3.50\ncroissant 2.95\nTOTAL 6.45",
    indent: "",
    color: False,
  )
  // -> "Diff (- expected, + actual):\n    coffee 3.50\n  - croissant 2.75\n  - TOTAL 6.25\n  + croissant 2.95\n  + TOTAL 6.45\n"
}
