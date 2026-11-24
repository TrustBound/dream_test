#!/bin/sh
# Records the HTTP calls and the database queries of the tests again.
# "make record" runs this script. It needs Docker, for the database.
set -eu

# The HTTP recorder keeps old files. A response that changed, such as its
# date header, goes to a new file, and two different files for one request
# make playback fail. So remove the old files first.
rm -rf test/recordings/http
mkdir -p test/recordings/http

docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
