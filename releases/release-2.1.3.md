# Dream Test 2.1.3 Release Notes

**Release Date:** 2026-07-06

Dream Test 2.1.3 is the release that actually ships the 2.1.2 changes. Version
2.1.2 was tagged in the repository but never reached Hex: the publish workflow
failed with a `400 Bad Request` from Hex.pm. Gleam 1.14's Hex client sends
duplicate `content-type` headers on publish requests, and a Hex.pm server-side
Plug upgrade on 2026-06-27 began rejecting such requests. The publish tooling
now uses Gleam 1.17.0, whose Hex client sends a single `content-type` header.

If you were waiting on 2.1.2, this is it — plus the tooling fixes that let it
leave the building.

## Highlights

### ✅ gleam_stdlib 1.x support (from the unpublished 2.1.2)

The `gleam_stdlib` constraint is now `>= 0.60.0 and < 2.0.0` (previously
`< 1.0.0`), so Dream Test can be installed alongside packages that require
`gleam_stdlib` 1.x. The full test suite and all examples pass against
`gleam_stdlib` 1.0.3. Thanks to
[@aschrijver](https://github.com/aschrijver) for reporting the issue and
verifying the wider range works.

### ✅ Publishing works again

The publish and docs-publish workflows run Gleam 1.17.0, fixing the duplicate
`content-type` header rejected by Hex.pm since 2026-06-27.

### ✅ Toolchain moved to Gleam 1.17.0

CI runs Gleam 1.17.0 and sources are formatted with the 1.17 formatter
(whitespace-only changes). Contributors now need Gleam 1.17.0+ and
Erlang/OTP 28+; older formatters produce output that fails CI's format check.

### ✅ Machine-independent reporter snapshots

The JSON reporter snippet snapshot now normalizes both `gleam_version` and
`otp_version`, so dependency and OTP upgrades no longer invalidate it.

## Files of interest

- `gleam.toml`
- `.github/workflows/publish.yml`
- `.github/workflows/publish-docs.yml`
- `.github/workflows/ci.yml`
- `CONTRIBUTING.md`
- `COMPATIBILITY.md`
- `examples/snippets/test/snippets/reporters/json_formatting.gleam`
