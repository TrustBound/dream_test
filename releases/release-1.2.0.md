# Dream Test 1.2.0 Release Notes

**Release Date:** December 4, 2025

Dream Test 1.2.0 introduces snapshot testing—compare output against stored "golden" files with automatic creation on first run and simple regeneration by deleting the snapshot file.

## What's New

### 📸 Snapshot Testing

Compare any value against a stored snapshot file. On first run, the snapshot is created automatically. On subsequent runs, differences cause test failures with clear diffs.

**Basic usage:**

```gleam
import dream_test/assertions/should.{should, match_snapshot, or_fail_with}

it("renders user profile", fn() {
  render_profile(user)
  |> should()
  |> match_snapshot("./test/snapshots/user_profile.snap")
  |> or_fail_with("Profile should match snapshot")
})
```

**Output:**

```
User Profile
  ✓ renders user profile

Summary: 1 run, 0 failed, 1 passed in 2ms
```

### 🔍 Snapshot Inspect for Complex Data

Test any value using `string.inspect` serialization—perfect for records, lists, tuples, and custom types:

```gleam
build_config()
|> should()
|> match_snapshot_inspect("./test/snapshots/config.snap")
|> or_fail_with("Config should match snapshot")
```

### 🔄 Simple Snapshot Updates

No magic environment variables or flags. To update a snapshot:

```sh
rm ./test/snapshots/user_profile.snap
gleam test
```

The new snapshot is created automatically on the next run.

### 🧹 Programmatic Snapshot Clearing

Clear snapshots in code for test setup or maintenance:

```gleam
import dream_test/matchers/snapshot

// Clear one snapshot
let _ = snapshot.clear_snapshot("./test/snapshots/old.snap")

// Clear all .snap files in a directory
let _ = snapshot.clear_snapshots_in_directory("./test/snapshots")
```

### 📁 File Module

A new internal `dream_test/file` module provides structured file I/O with detailed error handling:

```gleam
import dream_test/file

case file.read("./config.json") {
  Ok(content) -> parse(content)
  Error(file.NotFound(path)) -> use_default()
  Error(file.PermissionDenied(path)) -> fail_with("Cannot read: " <> path)
  Error(e) -> fail_with(file.error_to_string(e))
}
```

Error types: `NotFound`, `PermissionDenied`, `IsDirectory`, `NoSpace`, `FileSystemError`

### 📚 README Improvements

- **Table of contents** under the hero for quick navigation
- **Teaching-optimized section order**: basics first, architecture later
- Sections now flow: Quick Start → Assertions → Lifecycle → Snapshot → Gherkin → BEAM → CI

## Upgrading

Update your dependencies to 1.2.0:

```toml
[dev-dependencies]
dream_test = "~> 1.2"
```

Then run:

```bash
gleam deps download
```

## No Breaking Changes

This release is fully backward compatible. All existing tests continue to work without modification. Snapshot testing is entirely additive.

## Examples

See the new [examples/snippets/test/snapshot_testing.gleam](https://github.com/TrustBound/dream_test/blob/main/examples/snippets/test/snapshot_testing.gleam) for a complete example.

## Documentation

- [HexDocs](https://hexdocs.pm/dream_test)
- [GitHub](https://github.com/TrustBound/dream_test)
- [Snapshot Testing README Section](https://github.com/TrustBound/dream_test#snapshot-testing)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream_test/blob/main/CHANGELOG.md)




