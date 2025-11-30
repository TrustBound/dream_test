# Simple Makefile for dream_test

.PHONY: test bootstrap all

# Run gleeunit tests
test:
	gleam test

# Run dream_test's own tests using dream_test itself
bootstrap:
	gleam run -m dream_test_test

# Run everything: gleeunit tests + dream_test's self tests
all: test bootstrap
