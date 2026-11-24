#!/bin/sh
# What CI runs: the format check, the build, the tests with line coverage,
# the docs build, and the tests of the snippets project, which also check
# every code block of the docs. "make check" runs this script.
set -eu

gleam format --check src test
gleam build
gleam test
gleam docs build
cd examples/snippets
gleam format --check
gleam test
