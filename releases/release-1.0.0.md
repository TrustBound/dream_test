# Dream Test 1.0.0 Release Notes

**Release Date:** November 30, 2025

Dream Test 1.0.0 is the initial stable release of the testing framework for Gleam. It provides a complete BDD-style testing solution with parallel execution, process isolation, and a fluent assertion API.

## What's New

### Core Testing Framework

- `describe` and `it` blocks for BDD-style test organization
- Nested describe blocks with proper scoping
- Test tagging and filtering support

### Assertions Module

- Fluent assertion API with `should()` builder
- `or_fail_with` for custom failure messages
- Chainable assertion pattern

### Matchers

| Category   | Matchers                                                        |
| ---------- | --------------------------------------------------------------- |
| Equality   | `equal`, `not_equal`, `be_same_as`                              |
| Boolean    | `be_true`, `be_false`                                           |
| Comparison | `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`  |
| String     | `contain`, `start_with`, `end_with`, `match_pattern`            |
| Collection | `be_empty`, `have_length`, `contain_element`, `contain_exactly` |
| Option     | `be_some`, `be_none`, `unwrap_some`                             |
| Result     | `be_ok`, `be_error`, `unwrap_ok`, `unwrap_error`                |

### Test Runner

- Parallel test execution with configurable concurrency
- Sequential test support for tests requiring isolation
- Test timeout handling
- Comprehensive test result reporting

### BDD Reporter

- Colorized terminal output
- Hierarchical test result display
- Summary statistics (passed, failed, skipped)
- Failure details with context

### Lifecycle Support

- `before_each` and `after_each` hooks
- `before_all` and `after_all` hooks (suite mode)
- Setup and teardown at describe block level

### Process Isolation

- Each test runs in its own BEAM process
- Crashes in one test don't affect others
- Automatic resource cleanup

## Installation

```toml
[dev-dependencies]
dream_test = "~> 1.0"
```

## Documentation

- [HexDocs](https://hexdocs.pm/dream_test)
- [GitHub](https://github.com/TrustBound/dream_test)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)


