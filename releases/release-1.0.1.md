# Dream Test 1.0.1 Release Notes

**Release Date:** December 1, 2025

Dream Test 1.0.1 is a documentation-focused patch release. All README code examples are now backed by tested source files, ensuring documentation accuracy.

## What's Changed

### Documentation Improvements

- All README code examples are now backed by tested source files
- Each snippet has its own file in `examples/snippets/test/` for stable linking
- Added Quick Start example with string utilities
- README code blocks now include 🧪 links to verified source

### New Snippet Files

| Snippet | File |
|---------|------|
| Quick Start | `quick_start.gleam` |
| Hero Example | `hero.gleam` |
| Chaining Matchers | `chaining.gleam` |
| Lifecycle Hooks | `lifecycle_hooks.gleam` |
| Explicit Failures | `explicit_failures.gleam` |
| Hook Inheritance | `hook_inheritance.gleam` |
| Hook Failure | `hook_failure.gleam` |
| Runner Config | `runner_config.gleam` |
| Execution Modes | `execution_modes.gleam` |

### Removed

- Removed redundant `examples/math_app/` directory
- Removed redundant `examples/string_app/` directory
- Consolidated all README examples into `examples/snippets/`

## Upgrading

Update your dependencies to 1.0.1:

```toml
[dev-dependencies]
dream_test = "~> 1.0"
```

Then run:
```bash
gleam deps download
```

**Note:** This is a documentation-only release. No code changes were made to the library itself. Upgrading is optional but recommended for consistency with published documentation.

## No Breaking Changes

This release contains no breaking changes or code modifications. All functionality remains identical to 1.0.0.

## Documentation

- [HexDocs](https://hexdocs.pm/dream_test)
- [GitHub](https://github.com/TrustBound/dream_test)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)









