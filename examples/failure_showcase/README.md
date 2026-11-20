# Failure Showcase — Dream Test Reporting Demo

In this example project, every test intentionally fails or reports a hook failure.

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

- `make all` in the repo root runs this project, but its failures do not fail `make all`.
- The runner does **not** use `exit_on_failure()` so you can see every failure.
- The runner sets a low default timeout to guarantee the timeout example triggers.


