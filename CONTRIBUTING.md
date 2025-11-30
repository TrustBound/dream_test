# Contributing to dream_test

Thank you for your interest in contributing to dream_test! We welcome contributions from the community and appreciate your help in making this framework better.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [What We're Looking For](#what-were-looking-for)

## Code of Conduct

This project is part of the Dream ecosystem and adheres to professional, respectful collaboration standards. By participating, you agree to:

- Be respectful and inclusive
- Accept constructive criticism gracefully
- Focus on what's best for the community
- Show empathy towards other community members

## Getting Started

Before you begin:

1. **Read the documentation**: Familiarize yourself with [INTERFACE.md](INTERFACE.md), [DESIGN.md](DESIGN.md), and [ARCHITECTURE.md](ARCHITECTURE.md)
2. **Understand the standards**: Review [STANDARDS.md](STANDARDS.md) for code conventions
3. **Check existing issues**: See if someone else is already working on your idea
4. **Start small**: Consider tackling a "good first issue" if you're new to the project

## How to Contribute

### Reporting Bugs

If you find a bug:

1. **Search existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Steps to reproduce the bug
   - Expected vs actual behavior
   - Your environment (Gleam version, OS, target platform)
   - Minimal code example demonstrating the issue
   - Any relevant error messages or stack traces

### Suggesting Features

We love new ideas! For feature requests:

1. **Check the roadmap** in README.md to see if it's planned
2. **Open an issue** describing:
   - The problem you're trying to solve
   - Your proposed solution
   - Alternative solutions you've considered
   - Examples of how it would be used
   - Impact on existing functionality

### Improving Documentation

Documentation improvements are always welcome:

- Fix typos or unclear wording
- Add missing examples
- Improve existing examples
- Add clarifications based on your experience
- Update outdated information

## Development Setup

### Prerequisites

- [Gleam](https://gleam.run/) v1.0.0 or later
- Erlang/OTP 26+
- Git
- Make (optional, for convenience commands)

### Initial Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/dream_test.git
cd dream_test

# Add upstream remote
git remote add upstream https://github.com/TrustBound/dream_test.git

# Install dependencies and build
gleam deps download
gleam build

# Run tests to verify setup
gleam test
# or
make all
```

## Development Workflow

### 1. Create a Branch

```bash
# Update your fork
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
# or for bug fixes
git checkout -b fix/bug-description
```

### 2. Make Your Changes

- Write clear, focused commits
- Follow the code standards (see below)
- Add tests for new functionality
- Update documentation as needed
- Keep commits atomic and well-described

### 3. Test Your Changes

```bash
# Run all tests
make all

# Or individual steps
make build    # Compile
make test     # Run tests
make format   # Format code
```

### 4. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a clear message
git commit -m "Add feature: brief description

More detailed explanation if needed. Reference any related issues
using #issue-number."
```

#### Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- First line should be 50 characters or less
- Add a blank line before detailed explanation
- Reference issues and pull requests when relevant

Examples:
```
Add timeout support to test runner

Implements configurable timeouts for individual tests. Tests that
exceed their timeout are marked as failed with a clear timeout
message.

Closes #123
```

### 5. Push and Create Pull Request

```bash
# Push to your fork
git push origin feature/your-feature-name
```

Then open a pull request on GitHub.

## Code Standards

### Gleam Conventions

This project follows strict Gleam conventions outlined in [STANDARDS.md](STANDARDS.md). Key points:

#### No Magic

- No closures capturing outer scope in library code
- No anonymous functions in library modules
- Every function should be named and top-level
- Explicit is better than implicit

#### Imports

```gleam
// ✅ Good: Unqualified imports for commonly used functions
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{or_fail_with}

// ❌ Bad: Redundant alias
import dream_test/assertions/should as should

// ✅ Good: Type imports
import dream_test/types.{type TestResult, type Status}

// ❌ Bad: Missing type keyword
import dream_test/types.{TestResult}  // This imports a constructor, not a type
```

#### Function Design

```gleam
// ✅ Good: Config records for multi-parameter functions
pub type TestConfig {
  TestConfig(
    name: String,
    timeout: Int,
    tags: List(String),
  )
}

pub fn run_test(config: TestConfig) { ... }

// ❌ Bad: Long positional argument lists
pub fn run_test(name: String, timeout: Int, tags: List(String)) { ... }
```

#### Pipe-Friendly APIs

```gleam
// ✅ Good: Data-first parameter order for pipes
pub fn equal(actual: a, expected: a) -> AssertionResult(a) { ... }

value
|> should.equal(expected)
|> or_fail_with("message")

// ❌ Bad: Expected-first (not pipe-friendly)
pub fn equal(expected: a, actual: a) -> AssertionResult(a) { ... }
```

### Avoid Common Mistakes

See [AGENTS.md](AGENTS.md) for a detailed list of common mistakes and how to avoid them, including:

- Reserved words (`assert` is reserved—use `assertions` instead)
- Pattern matching in `case` expressions (use `{ ... }` for multi-line branches)
- List operations (use `list.append`, not `concat`)
- Import semantics (understand labeled arguments vs config records)

## Testing

### Writing Tests

All new functionality must include tests:

- Add tests in the appropriate `test/dream_test/` subdirectory
- Follow existing test patterns and structure
- Use descriptive test names that explain what is being tested
- Test both success and failure cases
- Include edge cases

Example:

```gleam
pub fn tests() {
  describe("should.equal", [
    it("passes when values are equal", fn() {
      should.equal(5, 5)
      |> bootstrap_assertions.assert_passed
    }),
    
    it("fails when values differ", fn() {
      should.equal(5, 10)
      |> bootstrap_assertions.assert_failed
    }),
    
    it("works with complex types", fn() {
      should.equal(Ok(42), Ok(42))
      |> bootstrap_assertions.assert_passed
    }),
  ])
}
```

### Bootstrap Testing

dream_test is self-hosting. When modifying core functionality:

1. Ensure bootstrap tests in `test/dream_test/bootstrap/` still pass
2. Add bootstrap tests if you're changing foundational code
3. Run `make all` to verify both regular and bootstrap tests

### Running Tests

```bash
# Run all tests
gleam test

# Or with make
make test

# Run example tests
cd examples/math_app
gleam test
```

## Documentation

### Code Documentation

- Add doc comments to all public functions and types
- Use `///` for documentation comments
- Include examples in documentation where helpful
- Document parameters, return values, and any important behavior

```gleam
/// Asserts that the actual value equals the expected value.
///
/// Returns a TestContext with the assertion result. Use with `or_fail_with`
/// to provide a custom failure message.
///
/// ## Example
///
/// ```gleam
/// actual_value
/// |> should.equal(expected_value)
/// |> or_fail_with("Values should be equal")
/// ```
pub fn equal(actual: a, expected: a) -> TestContext(a) { ... }
```

### Updating Documentation Files

When making significant changes, update relevant documentation:

- **INTERFACE.md** - For API changes visible to test authors
- **DESIGN.md** - For design decisions and rationale
- **ARCHITECTURE.md** - For internal architecture changes
- **README.md** - For major features or changes affecting getting started
- **STANDARDS.md** - For new code conventions or patterns

## Pull Request Process

### Before Submitting

- [ ] All tests pass (`make all`)
- [ ] Code follows standards in [STANDARDS.md](STANDARDS.md)
- [ ] New code has tests
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] Branch is up to date with `main`

### PR Description

Include in your pull request:

1. **Summary**: What does this PR do?
2. **Motivation**: Why is this change needed?
3. **Changes**: List of key changes made
4. **Testing**: How was this tested?
5. **Related Issues**: Reference any related issues

### Review Process

1. A maintainer will review your PR
2. Address any feedback or requested changes
3. Once approved, a maintainer will merge your PR
4. Your contribution will be included in the next release!

### After Your PR is Merged

- Delete your feature branch
- Update your local `main` branch
- Celebrate! 🎉

## What We're Looking For

### High Priority

- **Bug fixes** - Especially with test cases demonstrating the issue
- **Documentation improvements** - Clarity, examples, and accuracy
- **Additional assertions** - Common assertion patterns
- **Reporter implementations** - JSON, JUnit, TAP, etc.
- **Test coverage** - For untested code paths

### Welcome Additions

- **Performance optimizations** - With benchmarks showing improvement
- **Developer experience** - Better error messages, clearer APIs
- **Examples** - Real-world usage examples
- **Integration guides** - Using dream_test with other tools

### Please Discuss First

For major changes, please open an issue to discuss before starting work:

- **Architecture changes** - Significant refactoring or redesign
- **Breaking changes** - Changes to public APIs
- **New dependencies** - Adding external dependencies
- **Large features** - Anything requiring substantial effort

## Questions?

- **General questions**: Open a GitHub Discussion
- **Bug reports**: Open an issue
- **Feature requests**: Open an issue with the "enhancement" label
- **Security issues**: Email the maintainers directly (don't open a public issue)

## Thank You!

Your contributions make dream_test better for everyone. We appreciate your time and effort! 💚

---

<div align="center">
  <sub>Happy testing! 🧪</sub>
</div>

