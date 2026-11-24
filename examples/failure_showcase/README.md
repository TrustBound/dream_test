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

### Run the tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/scripts/examples.sh#L9-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/failure_showcase
gleam test
```

## Notes

- `make all` in the repo root runs this project, but its failures do not fail `make all`.
- The runner does **not** use `exit_on_failure()` so you can see every failure.
- The runner sets a low default timeout to guarantee the timeout example triggers.


