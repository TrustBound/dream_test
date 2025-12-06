# Constraint Matrix Analysis

## What Each Package Requires

This table shows the version constraints each package places on shared dependencies.

| Package (version)     | gleam_erlang | gleam_json | gleam_otp | gleam_regexp | gleam_stdlib |
|-----------------------|--------------|------------|-----------|--------------|--------------|
| gleam_erlang (1.3.0)  | -            | -          | -         | -            | >= 0.53.0    |
| gleam_json (3.1.0)    | -            | -          | -         | -            | >= 0.51.0    |
| gleam_otp (1.2.0)     | >= 1.0.0     | -          | -         | -            | >= 0.60.0    |
| gleam_regexp (1.1.1)  | -            | -          | -         | -            | >= 0.34.0    |
| gleam_stdlib (0.67.0) | -            | -          | -         | -            | -            |

## Bottleneck Analysis

These packages are forcing the highest minimum versions:

- **gleam_erlang**: Minimum >= 1.0.0 (forced by: gleam_otp)
- **gleam_stdlib**: Minimum >= 0.60.0 (forced by: gleam_otp)

## Interpretation

- If you want to support older versions of a dependency, you need to also
  support older versions of the packages that force it higher.
- Packages marked with `-` don't have a direct dependency on that column's package.
- Packages marked with `[dev]` are dev-dependencies.