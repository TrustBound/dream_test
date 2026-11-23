#!/bin/sh
# Runs the tests of the example projects failure_showcase, shopping_cart and
# cache_app. "make examples" runs this script. The snippets project runs in
# scripts/check.sh.
set -eu

# Every test of failure_showcase fails on purpose, to show the reports. Its
# runner does not use exit_on_failure, so the run ends with status 0.
cd examples/failure_showcase
gleam test
cd ../..

# readme_output checks the report that the README of shopping_cart shows.
cd examples/shopping_cart
gleam test
gleam run -m readme_output
cd ../..

# The second run measures coverage, because cache_app uses
# runner.coverage_from_environment.
cd examples/cache_app
gleam test
DREAM_TEST_COVERAGE=1 gleam test
cd ../..
