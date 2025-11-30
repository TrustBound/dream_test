<div align="center">
  <img src="https://raw.githubusercontent.com/TrustBound/dream/main/ricky_and_lucy.png" alt="Dream Logo" width="200">
  <h1>dream_test</h1>
  <p><strong>Clean, composable testing for Gleam. No magic.</strong></p>

  <a href="https://github.com/TrustBound/dream_test/releases">
    <img src="https://img.shields.io/github/v/release/TrustBound/dream_test?label=version" alt="Latest Release">
  </a>
  <a href="https://hex.pm/packages/dream_test">
    <img src="https://img.shields.io/hexpm/v/dream_test?label=hex" alt="Hex.pm">
  </a>
  <a href="https://hexdocs.pm/dream_test/">
    <img src="https://img.shields.io/badge/docs-hexdocs-8e4bff.svg" alt="Documentation">
  </a>
</div>

## Overview

**dream_test** is a testing framework for Gleam that prioritizes clarity, composability, and type safety. Inspired by Jest and RSpec, it provides a familiar `describe`/`it` syntax with Gleam's pipe-friendly assertion style.

```gleam
import dream_test/unit.{describe, it}
import dream_test/assertions/should.{or_fail_with}

pub fn tests() {
  describe("Calculator", [
    it("adds two numbers", fn() {
      add(2, 3)
      |> should.equal(5)
      |> or_fail_with("2 + 3 should equal 5")
    }),

    it("handles division by zero", fn() {
      divide(10, 0)
      |> should.equal(Error("Cannot divide by zero"))
      |> or_fail_with("Should return error for division by zero")
    }),
  ])
}
```

## Why dream_test?

### Designed for Gleam's strengths

- **Pipe-first assertions** that work naturally with Gleam's `|>` operator
- **Type-safe** test definitions with no runtime reflection or magic
- **Explicit** test discovery and execution—you control the flow
- **Self-hosting**—dream_test tests itself using its own framework

### Clear, maintainable tests

- Familiar **BDD-style** syntax (`describe`/`it`) from Jest and RSpec
- **Readable output** with nested test groups and clear pass/fail indicators
- **Composable** test trees that can be built programmatically
- **No global state**—all context is explicit and passed through functions

### Built for BEAM

- Runs on **Erlang** and **JavaScript** targets
- Designed for eventual **process isolation** and **timeout handling**
- Part of the **Dream ecosystem** for full-stack Gleam development
- Lightweight with **minimal dependencies**

## Installation

### From Hex (when published)

Add to your `gleam.toml`:

```toml
[dev-dependencies]
dream_test = "~> 0.1"
```

### Development version (local path)

For early access or contributions:

```toml
[dev-dependencies]
dream_test = { path = "../dream_test" }
```

## Quick Start

### 1. Create a test file

Create `test/my_app_test.gleam`:

```gleam
import my_app
import dream_test/unit.{describe, it, to_test_cases}
import dream_test/assertions/should.{or_fail_with}
import dream_test/runner.{run_all}
import dream_test/reporter/bdd.{report}
import gleam/io

pub fn tests() {
  describe("MyApp", [
    it("does something useful", fn() {
      my_app.do_something()
      |> should.equal("expected result")
      |> or_fail_with("Should return expected result")
    }),
  ])
}

pub fn main() {
  let test_tree = tests()
  let test_cases = to_test_cases("my_app_test", test_tree)
  let results = run_all(test_cases)
  report(results, io.print)
}
```

### 2. Run your tests

```sh
gleam test
```

### 3. See beautiful output

```text
MyApp
  ✓ does something useful

Summary: 1 run, 0 failed, 1 passed
```

## Core Concepts

### Test Organization

Use `describe` to group related tests and `it` to define individual test cases:

```gleam
describe("String operations", [
  describe("uppercase", [
    it("converts lowercase to uppercase", fn() { ... }),
    it("preserves already uppercase strings", fn() { ... }),
  ]),

  describe("trim", [
    it("removes leading whitespace", fn() { ... }),
    it("removes trailing whitespace", fn() { ... }),
  ]),
])
```

### Assertions

dream_test uses a **pipe-first** assertion style:

```gleam
// Basic equality
result
|> should.equal(expected)
|> or_fail_with("Custom failure message")

// Result types
parse_int("123")
|> should.equal(Ok(123))
|> or_fail_with("Should parse valid integer")

// Chain multiple assertions
value
|> should.equal(5)
|> or_fail_with("Step 1: value should be 5")
|> fn(_) { other_value }
|> should.equal(10)
|> or_fail_with("Step 2: other_value should be 10")
```

### Test Execution

The framework gives you explicit control over test execution:

1. **Define** tests with `describe`/`it`
2. **Convert** to test cases with `to_test_cases`
3. **Run** with `run_all`
4. **Report** with your choice of reporter

This explicitness means no hidden global state or test discovery magic.

## Project Structure

```
src/dream_test/
├── types.gleam              # Core types (Status, TestResult, etc.)
├── unit.gleam               # describe/it DSL
├── runner.gleam             # Test execution engine
├── assertions/
│   ├── context.gleam        # TestContext for tracking failures
│   └── should.gleam         # Pipe-first assertions
└── reporter/
    └── bdd.gleam           # BDD-style console reporter

test/dream_test/            # Framework's own tests
examples/math_app/          # Example project using dream_test
```

## Documentation

- **[INTERFACE.md](INTERFACE.md)** - Complete API documentation for test authors
- **[DESIGN.md](DESIGN.md)** - Design philosophy and decisions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Internal architecture and bootstrapping
- **[STANDARDS.md](STANDARDS.md)** - Code standards and conventions
- **[AGENTS.md](AGENTS.md)** - Notes for AI assistants and maintainers

## Examples

Check out the [`examples/math_app`](examples/math_app) directory for a complete working example, including:

- Test organization with nested `describe` blocks
- Multiple test cases with different assertion patterns
- Integration with a simple Gleam application
- Custom test runner setup

Run the example:

```sh
cd examples/math_app
gleam test
```

## Development

dream_test is **self-hosting**—it tests itself using its own framework.

### Prerequisites

- [Gleam](https://gleam.run/) (v1.0.0 or later)
- Erlang/OTP 26+
- Make (optional, for convenience commands)

### Running the test suite

```sh
# Run all tests
make all

# Or manually
gleam test
```

### Project commands

```sh
make build      # Compile the project
make test       # Run tests
make format     # Format code
make clean      # Clean build artifacts
make all        # Build + test + validate
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- How to report bugs and suggest features
- Development setup and workflow
- Code standards and conventions
- Testing requirements
- Pull request process

**Quick start for contributors:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Read [STANDARDS.md](STANDARDS.md) for code conventions
4. Make your changes with tests
5. Run `make all` to verify everything works
6. Open a pull request with a clear description

We're particularly interested in: bug fixes, documentation improvements, new assertion helpers, and additional reporters.

## Roadmap

### Near-term (v0.1 - v0.3)

- [x] Core `describe`/`it` DSL
- [x] Basic `should` assertions
- [x] BDD reporter
- [x] Self-hosting test suite
- [ ] Publish to Hex
- [ ] Process isolation for tests
- [ ] Timeout support
- [ ] Setup/teardown hooks

### Medium-term (v0.4 - v0.9)

- [ ] Test discovery (`dream test` CLI)
- [ ] Additional reporters (JSON, JUnit)
- [ ] Async test support
- [ ] Property-based testing integration
- [ ] Coverage reporting
- [ ] Parallel test execution

### Long-term (v1.0+)

- [ ] Gherkin/BDD feature file support
- [ ] Visual regression testing
- [ ] Snapshot testing
- [ ] Mutation testing
- [ ] IDE integrations
- [ ] Watch mode

## Philosophy

dream_test is built on these principles:

1. **Explicitness over magic** - No hidden globals, no reflection, no surprises
2. **Composition over configuration** - Build test suites programmatically
3. **Pipes over nesting** - Assertions flow naturally with Gleam's `|>` operator
4. **Types over runtime checks** - Catch errors at compile time
5. **Simplicity over features** - Do one thing well before adding more

## Status

dream_test is in **active development** and approaching its first stable release. The core API is solidifying, but breaking changes may still occur before v1.0.

**Current status**: Pre-release (v0.0.1)

- Core functionality: ✅ Stable
- API surface: ⚠️ May change
- Documentation: 📝 In progress
- Production ready: 🚧 Not yet

## License

This project is licensed under the Apache License 2.0. See the LICENSE file in the parent Dream repository for details.

## Acknowledgments

Inspired by:

- **Jest** (JavaScript) - `describe`/`it` syntax and reporter design
- **RSpec** (Ruby) - BDD philosophy and nested test organization
- **ExUnit** (Elixir) - BEAM-native testing patterns
- **Gleam** - Type safety and functional programming elegance

Built with ❤️ for the Gleam and BEAM communities.

---

<div align="center">
  <sub>Part of the <a href="https://github.com/TrustBound/dream">Dream</a> ecosystem</sub>
</div>
