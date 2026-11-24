#!/bin/sh
# Runs the tests live: the HTTP calls go to the mock server, and the
# queries go to PostgreSQL. The recorders write nothing. "make live" runs
# this script. It needs Docker, for the database.
set -eu

docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=passthrough gleam test
