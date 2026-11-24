#!/bin/sh
# Runs the tests from the recordings: no network and no database. CI runs
# this script, and "make test" too.
set -eu

gleam format --check
gleam test
# Runs one test alone, with the command that a failed test prints
gleam test -- --only "Forecast/gives the forecast for Oslo"
