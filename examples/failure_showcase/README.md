# Failure Showcase — Dream Test Reporting Demo

This example project is intentionally **all failures**.

Use it to quickly inspect how Dream Test renders:

- assertion failures (with structured payloads)
- `Error("...")` aborts from test bodies
- hook failures (`before_all`, `before_each`, `after_each`)
- sandbox crashes (`panic`)
- timeouts
- Gherkin failures (undefined steps + failing assertions)

## Run it

```bash
cd examples/failure_showcase
gleam test
```

## Notes

- This project is **not** part of `make all` in the repo root.
- The runner does **not** use `exit_on_failure()` so you can see every failure.
- The runner sets a low default timeout to guarantee the timeout example triggers.


