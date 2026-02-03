# Dream Test 2.1.1 Release Notes

**Release Date:** 2026-02-02

Dream Test 2.1.1 fixes Gherkin step parsing so data tables and doc strings attach
to the correct step. Huge thanks to [Álvaro Vilanova Vidal](https://github.com/alvivi)
for finding and fixing the issue.

## Highlights

### ✅ Correct Gherkin step attachments

Step parsing now keeps data tables and doc strings aligned with their intended
step, improving scenario accuracy when multiple steps include attachments.

## Files of interest

- `src/dream_test/gherkin/parser.gleam`
- `test/dream_test/gherkin/multi_table_test.gleam`
- `test/fixtures/multi_table_test.feature`

