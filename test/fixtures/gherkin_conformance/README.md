# Gherkin conformance fixtures

These files come from the official Gherkin parser repository:

- Repository: https://github.com/cucumber/gherkin
- Commit: `f2712e77c775133a5174272314733572605f36d0`
- Folders: `testdata/good` and `testdata/bad`
- License: MIT. The license text is in [LICENSE](LICENSE).

The `.feature` files are copies. They are not changed.

## How the tests use them

`test/dream_test/gherkin/conformance_test.gleam` runs the tests.

- `good/<name>.feature`: the test parses the file, renders the Feature as
  text, and compares the text with `good/<name>.expected`.
- `good/<name>.expected`: made from the official
  `testdata/good/<name>.feature.ast.ndjson` file with `ast_to_expected.py`.
  It holds what dream_test exposes: names, keywords, descriptions, tags,
  step texts, DocStrings with their media type, table cells, and the
  Background, Rule and Examples structure. Locations and ids are not in it.
- `bad/<name>.feature`: the test parses the file and compares the error
  with the line of the first official error and the matching
  `ParseProblem`. The official files list all errors. dream_test stops at
  the first error.

To make an expected file again:

```sh
python3 ast_to_expected.py <gherkin>/testdata/good/<name>.feature.ast.ndjson > good/<name>.expected
```

## Problem kinds of the bad files

| File | Line | ParseProblem |
|---|---|---|
| backslash_at_end_of_line_in_datatable | 5 | `InconsistentCellCount` |
| file_ends_with_open_docstring | 5 | `UnclosedDocString` |
| inconsistent_cell_count | 6 | `InconsistentCellCount` |
| invalid_language | 1 | `UnsupportedLanguage` |
| multiple_parser_errors | 2 | `UnexpectedLine` |
| not_gherkin | 1 | `UnexpectedLine` |
| repeated_step_docstring | 8 | `RepeatedDocString` (the official parser reports an unexpected `"""` line) |
| single_parser_error | 2 | `UnexpectedLine` |
| unexpected_end_of_file | 3 | `UnexpectedEndOfFile` |
| unexpected_eof | 7 | `UnexpectedEndOfFile` |
| unfinished_datatable | 5 | `InconsistentCellCount` |
| whitespace_in_tags | 3 | `TagContainsWhitespace` |

## Files that are not here, or that give an error

dream_test supports only English:

- `i18n_emoji.feature`, `i18n_fr.feature`, `i18n_no.feature`: other languages.
- `prefixed-keywords.feature`: Haitian Creole (`# language: ht`).
- `spaces_in_language.feature`: the `en-lol` language.

dream_test differs from the official grammar on purpose. These good files
are in `differs/`, and the tests check the error that dream_test gives:

- `conjunctions.feature`, `star-keywords.feature`,
  `incomplete_background_1.feature`, `incomplete_background_2.feature`,
  `incomplete_scenario.feature`, `incomplete_scenario_outline.feature`: a
  scenario or Background starts with `*` or `And` and no step runs before
  it. dream_test gives a `MissingPreviousStep` error, because an `And`,
  `But` or `*` step takes the phase of the step before it.
- `empty.feature`, `incomplete_feature_3.feature`: the file has no Feature.
  dream_test gives a `MissingFeature` error, so that a wrong file is not a
  silent pass.

The Markdown files (`*.md`) of `testdata/good` are Markdown with Gherkin,
which dream_test does not parse.
