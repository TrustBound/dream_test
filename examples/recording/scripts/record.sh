#!/bin/sh
# Records the HTTP calls and the database queries of the tests again.
# "make record" runs this script. It needs Docker, for the database.
# The HTTP recorder replaces the file of each request that it records
# again, so the old files stay where they are.
set -eu

docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
