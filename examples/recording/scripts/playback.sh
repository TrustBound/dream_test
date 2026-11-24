#!/bin/sh
# Runs the tests from the recordings: no network and no database. CI runs
# this script, and "make test" too.
set -eu

gleam format --check
gleam test
