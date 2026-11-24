# Makefile for dream_test

.PHONY: test build format snippets recording check-snippets examples check all

# Run the dream_test tests, with line coverage (fails below 100%)
test:
	gleam test

# Compile only
build:
	gleam build

# Format the code
format:
	gleam format src test

# Run the tests of the snippets project, which also check every code block
# of the docs
snippets:
	cd examples/snippets && gleam test

# Run the tests of the recording guides from their committed recordings,
# with no network and no database (CI runs the same script)
recording:
	cd examples/recording && sh scripts/playback.sh

# Run the recording tests, which compare the outputs that the recording
# guides show, then check every code block of the docs, and print each
# problem and the summary line
check-snippets: recording
	cd examples/snippets && gleam run -m snippets/docs/docs_check

# Run the tests of the other example projects
examples:
	sh scripts/examples.sh

# Format check, build, tests, docs build and snippet tests (what CI runs)
check:
	sh scripts/check.sh

# Run everything: what CI runs, then the other example projects
all: check examples
