# Dream Test 1.0.3 Release Notes

**Release Date:** December 1, 2025

Dream Test 1.0.3 improves pipeline composability by having `report` return results.

## What's New

### Cleaner Test Pipelines

The `report` function now returns its input results, enabling seamless pipeline composition:

**Before (1.0.2):**
```gleam
pub fn main() {
  let results =
    to_test_cases("my_test", tests())
    |> run_all()

  report(results, io.print)
  exit_on_failure(results)
}
```

**After (1.0.3):**
```gleam
pub fn main() {
  to_test_cases("my_test", tests())
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()
}
```

This change is backward compatible—existing code that ignores the return value continues to work.

## Documentation Updates

- Added "CI integration" section to README
- Updated Quick Start example to use the cleaner piped syntax
- Added "CI exit codes" to the feature status table

## Upgrading

Update your dependencies to 1.0.3:

```toml
[dev-dependencies]
dream_test = "~> 1.0"
```

Then run:
```bash
gleam deps download
```

You can optionally update your test entry points to use the cleaner piped syntax, but this is not required.

## No Breaking Changes

This release is fully backward compatible. All existing code continues to work without modification.

## Documentation

- [HexDocs](https://hexdocs.pm/dream_test)
- [GitHub](https://github.com/TrustBound/dream_test)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)



