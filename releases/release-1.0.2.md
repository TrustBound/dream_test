# Dream Test 1.0.2 Release Notes

**Release Date:** December 1, 2025

Dream Test 1.0.2 adds test skipping support and proper exit code handling for CI integration.

## What's New

### Test Skipping with `skip`

Use `skip` instead of `it` to temporarily disable a test:

```gleam
import dream_test/unit.{describe, it, skip}

describe("Feature", [
  it("works correctly", fn() { ... }),
  skip("not implemented yet", fn() { ... }),  // Skipped
  it("handles edge cases", fn() { ... }),
])
```

Output:
```
Feature
  ✓ works correctly
  - not implemented yet
  ✓ handles edge cases

Summary: 3 run, 0 failed, 2 passed, 1 skipped
```

The test body is preserved but not executed—just change `skip` back to `it` when ready.

### Exit Code Handling

New functions for CI integration:

```gleam
import dream_test/runner.{run_all, exit_on_failure, has_failures}

pub fn main() {
  to_test_cases("my_test", tests())
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()  // Exits with code 1 if any tests failed
}
```

- `exit_on_failure(results)` — exits with code 1 if any tests failed, timed out, or had setup failures
- `has_failures(results)` — returns `True` if any test result indicates a failure

## New Snippet

| Snippet | File |
|---------|------|
| Skipping Tests | `skipping_tests.gleam` |

## Upgrading

Update your dependencies to 1.0.2:

```toml
[dev-dependencies]
dream_test = "~> 1.0"
```

Then run:
```bash
gleam deps download
```

### Recommended: Add Exit Code Handling

Update your test entry point to use `exit_on_failure`:

```gleam
pub fn main() {
  to_test_cases("my_test", tests())
  |> run_all()
  |> report(io.print)
  |> exit_on_failure()  // Add this line
}
```

This ensures your CI pipeline correctly detects test failures.

## No Breaking Changes

This release is fully backward compatible. All existing code continues to work without modification.

## Documentation

- [HexDocs](https://hexdocs.pm/dream_test)
- [GitHub](https://github.com/TrustBound/dream_test)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)

