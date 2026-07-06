# Dream Test 2.1.2 Release Notes

**Release Date:** 2026-07-06

Dream Test 2.1.2 widens the `gleam_stdlib` version constraint so Dream Test can
be installed alongside packages that require `gleam_stdlib` 1.x. Thanks to
[@aschrijver](https://github.com/aschrijver) for reporting the issue and
verifying the wider range works.

## Highlights

### ✅ gleam_stdlib 1.x support

The `gleam_stdlib` constraint is now `>= 0.60.0 and < 2.0.0` (previously
`< 1.0.0`). The full test suite and all examples pass against
`gleam_stdlib` 1.0.3.

## Files of interest

- `gleam.toml`
- `COMPATIBILITY.md`
- `examples/snippets/test/snippets/reporters/json_formatting.gleam`
