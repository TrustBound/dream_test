# Simple Makefile for dream_test

.PHONY: test bootstrap bootstrap-core bootstrap-core-types bootstrap-should bootstrap-runner-core bootstrap-runner-suite bootstrap-unit-dsl all

# Run gleeunit tests
test:
	gleam test

# Run all bootstrap checks
bootstrap: bootstrap-core bootstrap-core-types bootstrap-should bootstrap-runner-core bootstrap-runner-suite bootstrap-unit-dsl

bootstrap-core:
	gleam run -m dream_test/bootstrap/bootstrap_core_assert

bootstrap-core-types:
	gleam run -m dream_test/bootstrap/bootstrap_core_types

bootstrap-should:
	gleam run -m dream_test/bootstrap/bootstrap_should

bootstrap-runner-core:
	gleam run -m dream_test/bootstrap/bootstrap_runner_core

bootstrap-runner-suite:
	gleam run -m dream_test/bootstrap/bootstrap_runner_suite

bootstrap-unit-dsl:
	gleam run -m dream_test/bootstrap/bootstrap_unit_dsl

# Run everything: unit tests + all bootstraps
all: test bootstrap
