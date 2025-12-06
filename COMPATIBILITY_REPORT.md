# Dependency Compatibility Analysis Report

**Project**: `../dream_test`
**Generated**: 2025-12-04
**Duration**: 22s

## Summary

| Metric              | Value                         |
|---------------------|-------------------------------|
| Packages analyzed   | 5                             |
| Full range found    | 5                             |
| Partial range found | 0                             |
| No range found      | 0                             |
| Skipped             | 0                             |
| Versions tested     | 196                           |
| Versions skipped    | 0 (below theoretical minimum) |

## Test Configuration

**Test commands**:
  - `gleam test`

**Include dev dependencies**: No
**Excluded packages**: None
**Resolve only**: No

## Combination Test Result: PASSED

All discovered minimum versions work together!

**Resolved versions at minimums**:

| Package      | Version |
|--------------|---------|
| gleam_erlang | 1.0.0   |
| gleam_json   | 3.0.1   |
| gleam_otp    | 1.1.0   |
| gleam_regexp | 1.0.0   |
| gleam_stdlib | 0.60.0  |

## Quick Wins

These packages can have their minimum version lowered based on testing:

| Package   | Current Min | Discovered Min | Versions Gained |
|-----------|-------------|----------------|-----------------|
| gleam_otp | 1.2.0       | **1.1.0**      | +1              |

## Recommended gleam.toml

Copy-paste these updated constraints:

```toml
[dependencies]
gleam_erlang = ">= 1.0.0 and < 2.0.0"
gleam_json = ">= 3.0.1 and < 4.0.0"
gleam_otp = ">= 1.1.0 and < 2.0.0"
gleam_regexp = ">= 1.0.0 and < 2.0.0"
gleam_stdlib = ">= 0.60.0 and < 1.0.0"
```

## Bottleneck Analysis

These dependencies have version constraints forced by other packages:

- **gleam_erlang**: Minimum >= 1.0.0 (forced by: gleam_otp)
- **gleam_stdlib**: Minimum >= 0.60.0 (forced by: gleam_otp)

## Full Compatibility Table

| Package      | Current Constraint    | Lowest | Highest | Available | Tested | Status |
|--------------|-----------------------|--------|---------|-----------|--------|--------|
| gleam_erlang | >= 0.25.0 and < 2.0.0 | 1.0.0  | 1.3.0   | 46        | 46     | ✅      |
| gleam_json   | >= 2.0.0 and < 4.0.0  | 3.0.1  | 3.1.0   | 18        | 18     | ✅      |
| gleam_otp    | >= 1.2.0 and < 2.0.0  | 1.1.0  | 1.2.0   | 38        | 38     | ✅      |
| gleam_regexp | >= 1.0.0 and < 2.0.0  | 1.0.0  | 1.1.1   | 3         | 3      | ✅      |
| gleam_stdlib | >= 0.44.0 and < 2.0.0 | 0.60.0 | 0.67.1  | 91        | 91     | ✅      |

## Resolved Dependencies at Boundaries

What other dependencies resolved to when each package was pinned at its boundaries:

### gleam_erlang

**At lowest**:
  - gleam_erlang: 1.0.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

**At highest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

### gleam_json

**At lowest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.0.1
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

**At highest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

### gleam_otp

**At lowest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.1.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

**At highest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

### gleam_regexp

**At lowest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.0.0
  - gleam_stdlib: 0.67.1

**At highest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

### gleam_stdlib

**At lowest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.60.0

**At highest**:
  - gleam_erlang: 1.3.0
  - gleam_json: 3.1.0
  - gleam_otp: 1.2.0
  - gleam_regexp: 1.1.1
  - gleam_stdlib: 0.67.1

## Methodology

1. Parse `gleam.toml` to extract dependencies
2. Fetch available versions for each package from Hex.pm
3. Build constraint matrix to identify theoretical minimum versions
4. For each package, use binary search to find:
   - **Lowest compatible**: Start from theoretical minimum, search upward
   - **Highest compatible**: Start from newest version, search downward
5. For each version tested:
   - Pin the package to that exact version (`== X.Y.Z`)
   - Open all other packages to `>= 0.0.0`
   - Run `gleam deps download` to verify resolution
   - Run configured test commands
6. Test all discovered minimums together (combination test)
7. Generate reports