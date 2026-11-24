# The tests of the guides about recorded HTTP calls and recorded queries

.PHONY: test record live db-up db-down

# Run the tests from the recordings, with no network and no database (CI
# runs the same script)
test:
	sh scripts/playback.sh

# Record the HTTP calls and the database queries again, with a mock server
# and a PostgreSQL server in Docker, which stops at the end
record:
	sh scripts/record.sh

# Run the tests live, with a mock server and a PostgreSQL server in Docker,
# which stops at the end. The recorders write nothing
live:
	sh scripts/live.sh

# Start the PostgreSQL server of docker-compose.yml, and wait until it
# accepts connections
db-up:
	docker compose up -d --wait postgres

# Stop the PostgreSQL server and remove its container and volumes
db-down:
	docker compose down -v
