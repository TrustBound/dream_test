# Simple Makefile for dream_test

.PHONY: test bootstrap bootstrap-assertions bootstrap-types bootstrap-should bootstrap-runner-core bootstrap-runner-suite bootstrap-unit all

# Run gleeunit tests
test:
	gleam test

# Run all bootstrap checks
bootstrap: bootstrap-assertions bootstrap-types bootstrap-should bootstrap-runner-core bootstrap-runner-suite bootstrap-unit

bootstrap-assertions:
	gleam run -m dream_test/bootstrap/assertions_test

bootstrap-types:
	gleam run -m dream_test/types_test

bootstrap-should:
	gleam run -m dream_test/assertions/should_test

bootstrap-runner-core:
	gleam run -m dream_test/runner_test

bootstrap-runner-suite:
	gleam run -m dream_test/runner_test

bootstrap-unit:
	gleam run -m dream_test/unit_test

# Run everything: unit tests + all bootstraps
all: test bootstrap
