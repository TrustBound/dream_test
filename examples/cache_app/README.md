# Cache App Example

A comprehensive example demonstrating all Dream Test features using AAA (Arrange-Act-Assert) black-box testing.

## Testing Philosophy

Each test follows the AAA pattern:

```gleam
it("retrieves a stored value", fn() {
  // Arrange
  let cache = cache_app.start()
  cache_app.set(cache, "name", "Alice")

  // Act
  let result = cache_app.get(cache, "name")

  // Assert
  cache_app.stop(cache)
  result
  |> should
  |> be_some()
  |> be_equal("Alice")
  |> or_fail_with("get() should return the stored value")
})
```

Tests interact only with the public API — no internal state inspection.

## What This Demonstrates

| Feature                                                    | Where                          |
| ---------------------------------------------------------- | ------------------------------ |
| Nested `describe`/`it` blocks                              | Throughout                     |
| `before_all` / `after_all` hooks                           | "with lifecycle hooks" section |
| `before_each` / `after_each` hooks                         | "with lifecycle hooks" section |
| Option matchers (`be_some`, `be_none`)                     | Basic operations               |
| Result matchers (`be_ok`, `be_error`)                      | Convenience functions          |
| Collection matchers (`contain`, `have_length`, `be_empty`) | Collection operations          |
| Boolean matchers (`be_true`, `be_false`)                   | Convenience functions          |
| Comparison matchers (`be_greater_than`, `be_at_least`)     | Collection operations          |
| Equality matchers (`equal`, `not_equal`)                   | Throughout                     |
| Assertion chaining (`be_ok() \|> be_equal()`)                 | Convenience functions          |
| Runner (suite-first) (`runner.new` → `runner.run`)         | `cache_app_test.gleam`         |

## Running the Tests

```bash
cd examples/cache_app
make test
```

## The Cache App

The cache itself is a simple in-memory key-value store built with gleam_otp actors:

- `start()` / `stop()` — lifecycle
- `get()` / `set()` / `delete()` / `clear()` — basic operations
- `keys()` / `size()` — inspection
- `get_or()` / `has()` / `update()` / `pop()` — convenience functions

It's intentionally simple — the focus is on testing patterns, not cache implementation.

## Using as a Template

Copy this structure for your own projects:

```
your_app/
├── gleam.toml
├── src/
│   └── your_app.gleam
└── test/
    └── your_app_test.gleam
```

Key patterns to follow:

1. **Group related tests** in `describe` blocks
2. **Use lifecycle hooks** for shared setup/teardown
3. **Chain assertions** for readability (`be_ok() |> be_equal()`)
4. **Use root hooks** when you need `before_all`/`after_all`
5. **Clean up resources** in tests (stop caches, close connections)
