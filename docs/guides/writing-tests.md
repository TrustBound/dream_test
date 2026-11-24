# Organize tests with groups, skips and tags

Your first test module had two tests. Six months later it has sixty, plus a few that wait for a feature, one that's broken on CI for reasons you'll fix next week, and a slow group that talks to a real payment sandbox. If the report is a flat list of sixty names, nobody reads it. This guide shows how to shape a suite so its report reads like a spec, how to park tests without deleting them, and how to run just the slice you need.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which tool for which job](#which-tool-for-which-job)
- [Step 1: Group tests by behavior](#step-1-group-tests-by-behavior)
- [Step 2: Write the skeleton with pending tests](#step-2-write-the-skeleton-with-pending-tests)
- [Step 3: Skip a test without losing it](#step-3-skip-a-test-without-losing-it)
- [Step 4: Tag tests and groups](#step-4-tag-tests-and-groups)
- [Step 5: Run only some tests](#step-5-run-only-some-tests)
- [When a filter keeps nothing](#when-a-filter-keeps-nothing)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Build one suite for a shopping cart, with a group for each behavior.
- Write the tests you haven't implemented yet as `pending`, and see them in the report.
- Skip a test and keep its body.
- Tag a test and a whole group.
- Run only the smoke tests, and run everything but the integration tests.
- Test your filters, so a typo in a tag can't empty your CI run.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

The examples test a small cart module with one function, `cart.total(prices)`, which adds up a list of prices in cents. The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## Which tool for which job

| Your situation | Use | Why |
|:---|:---|:---|
| Name the thing you test | `describe(name, children)` | The top of the suite. Its name is the first line of the report. |
| Several tests about one behavior of that thing | `group(name, children)` | A nested level in the report, and a scope for hooks. |
| A test you know you need, but haven't written | `pending(name)` | It shows in the report with `~`, and the run still passes. |
| A test with a body that must not run for now | `skip(name, body)` | The body stays in the code and keeps compiling. It shows with `-`. |
| A slice of tests you want to run, or leave out, together | `with_tags([...])` and `runner.filter_tests` | Tags are data, so a filter doesn't parse test names. |

## Step 1: Group tests by behavior

Here's the whole suite you'll build in this guide. Start with the `total` group: two tests about what the total is.

### The cart suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/writing_tests_cart.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import app/cart
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/unit.{describe, group, it, pending, skip, with_tags}

pub fn tests() {
  describe("Cart", [
    group("total", [
      it("is 0 for an empty cart", fn() {
        cart.total([])
        |> should
        |> be_equal(0)
        |> or_fail_with("an empty cart should cost nothing")
      })
        |> with_tags(["smoke"]),
      it("adds the prices", fn() {
        cart.total([250, 1000, 99])
        |> should
        |> be_equal(1349)
        |> or_fail_with("the total should be the sum of the prices")
      }),
    ]),
    group("discounts", [
      pending("takes 10% off above 100.00"),
      pending("never goes below 0"),
    ]),
    group("checkout", [
      skip("charges the card", fn() {
        cart.total([1000])
        |> should
        |> be_equal(1000)
        |> or_fail_with("the card should be charged the total")
      }),
    ])
      |> with_tags(["integration"]),
  ])
}
```

The suite runs to this report:

### The report of the cart suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_writing_tests_cart.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Cart
  total
    ✓ is 0 for an empty cart
    ✓ adds the prices
  discounts
    ~ takes 10% off above 100.00
    ~ never goes below 0
  checkout
    - charges the card

Summary: 5 run, 0 failed, 2 passed, 1 skipped, 2 pending in 0ms
```

Each `describe` and `group` is one level of indentation, so the report reads top-down like a spec: "Cart, total, is 0 for an empty cart". A few habits keep it that way:

- Name the `describe` after the thing (a module, a type, a feature), and each `group` after one behavior of it.
- Name each `it` after the outcome, "returns an error for a zero divisor", not after the code, "calls divide with 0".
- Keep each body to arrange, act, assert. When the setup gets long, move it to a named helper first. Reach for hooks when the setup is infrastructure, such as a server or a temp folder.

A group also limits hooks: a `before_each` in a group runs only for the tests in that group. [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md) shows how.

## Step 2: Write the skeleton with pending tests

The `discounts` group has no code yet, but you already know what it must do. `pending(name)` writes that down. A pending test has a name and no body:

- Its status is `Pending`. The report shows it with `~`, and the summary counts it.
- The run still passes, as with a skipped test.

Write the skeleton of a new feature first, one `pending` line for each behavior. Then replace each one with an `it` as you write the test. The report doubles as a to-do list. `unit_context.pending` does the same in a suite with a shared context.

## Step 3: Skip a test without losing it

The `checkout` test needs a payment sandbox that's down this week. Deleting the test loses its intent and its code. Commenting it out lets it rot. `skip(name, body)` keeps the body in place: the compiler still checks it, so a renamed function breaks the build, not your memory. The runner doesn't run the body, and the report shows the test with `-`.

Skip is for a short time. A skipped test that stays skipped for months is a test you've deleted, with extra steps.

## Step 4: Tag tests and groups

Tags are labels you attach to tests: `smoke`, `slow`, `integration`, `flaky`. They're a list of strings on each test, so tools and filters can read them without parsing names.

- `it(...) |> with_tags(["smoke"])` tags one test. `skip(...)` and `pending(...)` take tags the same way.
- `group(...) |> with_tags(["integration"])` tags every test in the group, also in nested groups.
- A test's tags are its own tags plus the tags of every group around it.

In the cart suite, `is 0 for an empty cart` has the tag `smoke`, and `charges the card` gets `integration` from its group. Gherkin features use tags too: on a Feature, a Rule, a Scenario or an `Examples` section. [Write Gherkin features](https://github.com/TrustBound/dream_test/blob/main/docs/guides/gherkin-bdd.md) covers them.

## Step 5: Run only some tests

`runner.filter_tests(predicate)` runs only the tests for which `predicate` returns `True`. The predicate gets a `TestInfo` for each test: its `name`, the names of its `groups` from the outermost one, its `tags` (inherited ones included), its `kind` and its `source`. Here are two filters for the cart suite, and a runner that uses the first:

### Filters for the cart suite <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/writing_tests_filter.gleam#L1-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/types.{type TestInfo}
import gleam/list
import snippets/guides/writing_tests_cart

pub fn only_smoke(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoke")
}

pub fn without_integration(info: TestInfo) -> Bool {
  !list.contains(info.tags, "integration")
}

pub fn main() {
  runner.new([writing_tests_cart.tests()])
  |> runner.filter_tests(only_smoke)
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

The run prints only the test that has the tag, and the exit status is 0:

### The smoke run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_writing_tests_smoke.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Cart
  total
    ✓ is 0 for an empty cart

Summary: 1 run, 0 failed, 1 passed in 0ms
```

A test that the filter leaves out isn't in the report at all, not even as skipped. A group with no selected test in it doesn't run, and neither do its hooks, so a filtered run doesn't start a server that no selected test needs.

One `main` usually serves every run, so pick the filter from somewhere outside the code, such as an environment variable that your CI job sets. Keep the predicates themselves as named, public functions, so you can test them, as the next sections show.

## When a filter keeps nothing

A filter is a plain function, and a typo in it is a plain bug. This runner looks for the tag `smoek`:

### A filter with a typo <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/writing_tests_filter.gleam#L23-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// A filter with a typo in its tag: it keeps no test.
pub fn only_smoek(info: TestInfo) -> Bool {
  list.contains(info.tags, "smoek")
}

pub fn main_with_typo() {
  runner.new([writing_tests_cart.tests()])
  |> runner.filter_tests(only_smoek)
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}
```

It runs no test at all. A run that tests nothing proves nothing, so the run fails, and the exit status is 1:

### The run with the typo <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_writing_tests_typo.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text

Summary: 0 run, 0 failed, 0 passed in 0ms
No tests ran. The filter or the suites selected no test. To allow an empty run, use runner.allow_no_tests().
```

A skipped or a pending test counts as a test that ran, so a run where every test is skipped still passes. Only a run with no test at all fails.

Sometimes a filter selects nothing on purpose, for example a CI job that runs only the migration tests of a project that has none yet. Add `runner.allow_no_tests()` to that runner:

### Allow a run with no test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/writing_tests_filter.gleam#L36-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// A filter for the migration tests. The cart suite has none, and this
/// runner allows a run with no test.
pub fn only_migrations(info: TestInfo) -> Bool {
  list.contains(info.tags, "migration")
}

pub fn main_allowing_no_tests() {
  runner.new([writing_tests_cart.tests()])
  |> runner.filter_tests(only_migrations)
  |> runner.results_reporters([bdd.new()])
  |> runner.allow_no_tests()
  |> runner.exit_on_failure()
  |> runner.run()
}
```

The run passes with exit status 0, and the report has no `No tests ran` line:

### The run that allows no test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_writing_tests_no_tests_allowed.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text

Summary: 0 run, 0 failed, 0 passed in 0ms
```

`runner.allow_no_tests()` also lets a typo through, so keep it off the runners that guard your main branch, and test your filters.

## Test your code

A filter decides which tests guard your main branch, so give it tests of its own. Run the suite with the filter and `runner.silent()`, then check the names of the tests that ran:

### Check which tests a filter keeps <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/writing_tests_filter_selection.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type RunReport, type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/guides/writing_tests_cart
import snippets/guides/writing_tests_filter.{only_smoke, without_integration}

pub fn tests() {
  describe("The cart filters", [
    it("keep only the smoke test", fn() {
      // Act
      let report =
        runner.new([writing_tests_cart.tests()])
        |> runner.filter_tests(only_smoke)
        |> runner.silent()
        |> runner.run()

      // Assert
      test_names(report)
      |> should
      |> be_equal(["is 0 for an empty cart"])
      |> or_fail_with("only the smoke test should run")
    }),
    it("leave out the integration group", fn() {
      // Act
      let report =
        runner.new([writing_tests_cart.tests()])
        |> runner.filter_tests(without_integration)
        |> runner.silent()
        |> runner.run()

      // Assert
      test_names(report)
      |> should
      |> be_equal([
        "is 0 for an empty cart", "adds the prices",
        "takes 10% off above 100.00", "never goes below 0",
      ])
      |> or_fail_with("every test but the checkout test should run")
    }),
  ])
}

fn test_names(report: RunReport) -> List(String) {
  types.report_tests(report)
  |> list.map(test_name)
}

fn test_name(result: TestResult) -> String {
  result.name
}
```

The report of a filtered run holds only the tests that ran, so the list of names is exactly the selection. Both checks pass:

### The report of the filter checks <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_writing_tests_check.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The cart filters
  ✓ keep only the smoke test
  ✓ leave out the integration group

Summary: 2 run, 0 failed, 2 passed in 0ms
```

If someone renames the `smoke` tag, the first check fails and says which tests ran.

## Common pitfalls

**A skip that never ends.** *Symptom:* the summary shows the same `1 skipped` for months. *Fix:* skip for a known reason and a short time. Put the reason in the test name or a comment next to it, and turn it back into `it` when the reason is gone.

**A tag on the wrong level.** *Symptom:* a filter on `integration` keeps one test of a group, not all of them. *Fix:* put the tag on the `group`, and every test inside gets it, also in nested groups.

**A filter that keeps nothing behind `allow_no_tests`.** *Symptom:* `Summary: 0 run, 0 failed, 0 passed` and a green CI job. *Fix:* use `runner.allow_no_tests()` only on a runner that can be empty on purpose, and test each filter as in [Test your code](#test-your-code).

**Long setup in every test body.** *Symptom:* each `it` starts with ten lines of setup, and the assertion gets lost. *Fix:* move the setup to a named helper, or to a `before_each` hook in the group.

## Where to go next

- [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md): the assertions inside each test.
- [Set up and tear down around tests](https://github.com/TrustBound/dream_test/blob/main/docs/guides/lifecycle-hooks.md): hooks, scoped by `describe` and `group`.
- [Run a large suite fast and predictably](https://github.com/TrustBound/dream_test/blob/main/docs/guides/runner-and-execution.md): filters, parallelism and timeouts for big runs.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/unit.html): `describe`, `group`, `it`, `skip`, `pending` and `with_tags`.
