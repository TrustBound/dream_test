# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2025-12-01

### Changed

- **Documentation Improvements**
  - All README code examples are now backed by tested source files
  - Each snippet has its own file in `examples/snippets/test/` for stable linking
  - Added Quick Start example with string utilities
  - README code blocks now include 🧪 links to verified source

### Removed

- Removed redundant `examples/math_app/` and `examples/string_app/` directories
- Consolidated all README examples into `examples/snippets/`

## [1.0.0] - 2025-11-30

### Added

- **Core Testing Framework**

  - `describe` and `it` blocks for BDD-style test organization
  - Nested describe blocks with proper scoping
  - Test tagging and filtering support

- **Assertions Module** (`dream_test/assertions/should`)

  - Fluent assertion API with `should()` builder
  - `or_fail_with` for custom failure messages
  - Chainable assertion pattern

- **Matchers**

  - `equality` - `equal`, `not_equal`, `be_same_as`
  - `boolean` - `be_true`, `be_false`
  - `comparison` - `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`
  - `string` - `contain`, `start_with`, `end_with`, `match_pattern`
  - `collection` - `be_empty`, `have_length`, `contain_element`, `contain_exactly`
  - `option` - `be_some`, `be_none`, `unwrap_some`
  - `result` - `be_ok`, `be_error`, `unwrap_ok`, `unwrap_error`

- **Test Runner**

  - Parallel test execution with configurable concurrency
  - Sequential test support for tests requiring isolation
  - Test timeout handling
  - Comprehensive test result reporting

- **BDD Reporter** (`dream_test/reporter/bdd`)

  - Colorized terminal output
  - Hierarchical test result display
  - Summary statistics (passed, failed, skipped)
  - Failure details with context

- **Lifecycle Support**

  - `before_each` and `after_each` hooks
  - Setup and teardown at describe block level
  - Context passing between lifecycle hooks and tests

- **Sandbox Module** (`dream_test/sandbox`)

  - Isolated test execution environment
  - Process isolation for test safety

- **Process Testing** (`dream_test/process`)
  - Utilities for testing OTP processes
  - Process lifecycle testing support

### Documentation

- Comprehensive README with usage examples
- CONTRIBUTING guide for contributors
- STANDARDS document for code conventions
- API documentation for all public modules

[Unreleased]: https://github.com/TrustBound/dream_test/compare/1.0.1...HEAD
[1.0.1]: https://github.com/TrustBound/dream_test/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/TrustBound/dream_test/releases/tag/1.0.0
