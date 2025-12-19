# Contributing to Dream Test

Thank you for your interest in contributing! This guide covers everything you need to get started.

---

## Quick Reference

| Need to know...      | Read...                                   |
| -------------------- | ----------------------------------------- |
| API reference        | [Hexdocs](https://hexdocs.pm/dream_test/) |
| Quick start          | [README.md](README.md)                    |
| Coding conventions   | [STANDARDS.md](STANDARDS.md)              |
| Community guidelines | [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)  |
| Security policy      | [SECURITY.md](SECURITY.md)                |
| Version history      | [CHANGELOG.md](CHANGELOG.md)              |
| Project funding      | [FUNDING.md](FUNDING.md)                  |

---

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold a welcoming, harassment-free environment for everyone.

**TL;DR:** Be respectful. Be inclusive. Focus on what's best for the project.

---

## First-Time Contributors

New to Dream Test or open source? Welcome! Here's how to get started:

1. **Look for `good first issue`** labels on [GitHub Issues](https://github.com/TrustBound/dream_test/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
2. **Start small** — documentation fixes, typo corrections, and test additions are great first PRs
3. **Ask questions** — open an issue if you're unsure about anything; we don't bite

All contributions are valued, no matter how small.

---

## Getting Started

### Prerequisites

- [Gleam](https://gleam.run/) v1.0.0+
- Erlang/OTP 26+
- Git
- Make (optional but recommended)

### Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/dream_test.git
cd dream_test

# Add upstream remote
git remote add upstream https://github.com/TrustBound/dream_test.git

# Build and test
make all
```

If everything passes, you're ready to contribute.

---

## Development Workflow

### 1. Create a branch

```bash
git checkout main
git pull upstream main
git checkout -b feature/your-feature-name
```

Use `feature/` for new features, `fix/` for bug fixes.

### 2. Make changes

- Write clear, focused commits
- Follow [STANDARDS.md](STANDARDS.md) conventions
- Add tests for new functionality
- Update docs if the public API changes

### 3. Test

```bash
make all          # Full build + test + format
make test         # Tests only
make build        # Compile only
make format       # Format code
```

### 4. Commit

We follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

**Format:**

```
<type>[optional scope]: <description>

## Why This Change Was Made
- Explain the reasoning so future engineers understand the context

## What Was Changed
- Technical explanation of the changes

## Note to Future Engineer
- Gotchas, non-obvious details, or anything that might trip someone up
- A bit of humor is welcome here
```

**Types:**

| Type       | When to use                                             |
| ---------- | ------------------------------------------------------- |
| `feat`     | New feature                                             |
| `fix`      | Bug fix                                                 |
| `docs`     | Documentation only                                      |
| `style`    | Formatting, whitespace (no code change)                 |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf`     | Performance improvement                                 |
| `test`     | Adding or updating tests                                |
| `build`    | Build system or dependencies                            |
| `ci`       | CI configuration                                        |
| `chore`    | Other changes that don't modify src or test             |

**Scope:** If your branch has an issue number (e.g., `feature/SVC-123`), use it as the scope:

```
feat(SVC-123): add timeout support to test runner
```

**Example:**

```
feat: add timeout support to test runner

## Why This Change Was Made
- Tests that hang indefinitely block CI pipelines
- Users requested configurable timeouts per-test

## What Was Changed
- Added `timeout_ms` option to `RunnerConfig`
- Tests exceeding timeout are killed and marked as failed
- Default timeout remains 5 seconds

## Note to Future Engineer
- The timeout uses `process.kill` under the hood, not a graceful shutdown
- If you're debugging a hanging test locally, set timeout to a large value
- Yes, we considered using a monad for this. No, we didn't.
```

**Breaking changes:** Add `!` after type:

```
feat!: remove deprecated assertion API
```

### 5. Push and open PR

```bash
git push origin feature/your-feature-name
```

Then open a pull request on GitHub.

---

## Writing Tests

All new functionality must include tests.

### Test location

Add tests in the appropriate `test/dream_test/` subdirectory matching the source structure.

### Test structure

```gleam
import dream_test/unit.{describe, it}
import dream_test/matchers.{should, , fail_with, or_fail_with}
import dream_test/types.{AssertionOk, MatchFailed, MatchOk}

pub fn tests() {
  describe("Feature name", [
    it("does something when condition", fn() {
      let result = some_function()

      case result {
        MatchOk(_) -> AssertionOk
        MatchFailed(_) -> fail_with("Expected success")
      }
    }),
  ])
}
```

### What to test

- Success cases
- Failure cases
- Edge cases
- Error messages (when relevant)

See [hexdocs](https://hexdocs.pm/dream_test/) for the complete assertion API.

---

## Documentation

Dream Test maintains high documentation standards. Contributions must match the quality of existing docs.

### Module-level docs (`////`)

New modules need comprehensive module docs at the top of the file:

````gleam
//// Brief description of what this module does.
////
//// Longer explanation of the module's purpose and how it fits
//// into the overall API.
////
//// ## Basic Pattern
////
//// ```gleam
//// example_usage()
//// |> with_typical_pattern()
//// ```
////
//// ## Available Functions
////
//// | Category    | Functions                    |
//// |-------------|------------------------------|
//// | **Core**    | `foo`, `bar`                 |
//// | **Helpers** | `baz`, `qux`                 |
////
//// ## Import Style
////
//// ```gleam
//// import dream_test/your_module.{foo, bar}
//// ```
````

### Function-level docs (`///`)

Every public function needs:

1. **One-line summary** — what it does
2. **Behavior details** — what it returns, edge cases
3. **Example** — runnable code showing typical usage

````gleam
/// Checks if the value equals the expected value.
///
/// Returns `MatchOk` if equal, `MatchFailed` with a diff otherwise.
/// Works with any type that supports equality comparison.
///
/// ## Example
///
/// ```gleam
/// 42
/// |> should
/// |> be_equal(42)
/// |> or_fail_with("Should be 42")
/// ```
pub fn be_equal(result: MatchResult(a), expected: a) -> MatchResult(a) {
  // ...
}
````

### Reference examples

See these files for documentation quality standards:

- `src/dream_test/matchers.gleam` — module docs with tables, chaining examples
- `src/dream_test/unit.gleam` — DSL usage patterns
- `src/dream_test/runner.gleam` — configuration examples

### Updating docs

| Changed...     | Update...                      |
| -------------- | ------------------------------ |
| Public API     | Hexdocs (update code comments) |
| Major features | [README.md](README.md)         |
| Coding rules   | [STANDARDS.md](STANDARDS.md)   |

---

## Pull Request Process

### Before submitting

- [ ] Tests pass (`make all`)
- [ ] Code follows [STANDARDS.md](STANDARDS.md)
- [ ] New code has tests
- [ ] Docs updated if needed
- [ ] Commits are clear and atomic

### PR template

```markdown
## Summary

What does this PR do?

## Motivation

Why is this change needed?

## Changes

- Change 1
- Change 2

## Testing

How was this tested?

## Related

Closes #123
```

### Review process

1. Maintainer reviews your PR
2. Address feedback
3. PR gets approved and merged
4. 🎉

---

## What We're Looking For

### High priority

- **Bug fixes** with test cases demonstrating the issue
- **Documentation** improvements
- **New matchers** for common assertion patterns
- **Reporters** (JSON, JUnit, TAP)
- **Test coverage** for untested paths

### Welcome additions

- Performance optimizations (with benchmarks)
- Better error messages
- Real-world examples
- Integration guides

### Discuss first

Open an issue before starting work on:

- Architecture changes
- Breaking API changes
- New dependencies
- Large features

---

## Versioning

We follow [Semantic Versioning](https://semver.org/) strictly.

| Change type                       | Version bump | Example         |
| --------------------------------- | ------------ | --------------- |
| Breaking API change               | **Major**    | `1.0.0 → 2.0.0` |
| New feature (backward-compatible) | **Minor**    | `1.0.0 → 1.1.0` |
| Bug fix (backward-compatible)     | **Patch**    | `1.0.0 → 1.0.1` |

**What counts as breaking:**

- Removing or renaming public functions
- Changing function signatures (parameters, return types)
- Changing behavior that existing code depends on
- Removing or renaming public types

**What doesn't count as breaking:**

- Adding new functions
- Adding new optional parameters
- Improving error messages
- Performance improvements
- Internal refactors

When in doubt, ask in your PR — we'd rather discuss than accidentally ship a breaking change.

---

## Questions & Support

| Type                     | Where                                                                                   |
| ------------------------ | --------------------------------------------------------------------------------------- |
| General questions        | [GitHub Issues](https://github.com/TrustBound/dream_test/issues)                        |
| Bug reports              | [GitHub Issues](https://github.com/TrustBound/dream_test/issues) (use bug template)     |
| Feature requests         | [GitHub Issues](https://github.com/TrustBound/dream_test/issues) (use feature template) |
| Security vulnerabilities | [SECURITY.md](SECURITY.md) — **do not use public issues**                               |

---

## License

By contributing to Dream Test, you agree that your contributions will be licensed under the [MIT License](LICENSE.md).

---

<div align="center">
  <sub>Thank you for contributing! 💚</sub>
</div>
