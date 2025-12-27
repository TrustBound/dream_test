# Simple Makefile for dream_test

.PHONY: test examples all

# Run dream_test tests
test:
	gleam test

# Run example project tests
examples:
	cd examples/snippets && gleam test
	@echo ""
	@echo "NOTE: failure_showcase is expected to fail (for reporter demo)."
	cd examples/failure_showcase && gleam test || true
	cd examples/shopping_cart && gleam test
	cd examples/cache_app && gleam test

# Run everything: examples first, then dream_test tests last
all: examples test
