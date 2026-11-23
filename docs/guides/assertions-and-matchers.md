# Check values with matchers

A test is only as good as its assertion, and an assertion is only as good as the failure it prints. When a test breaks at 2 a.m. on CI, you want one look at the log to tell you what was wrong: which check, which value, and what you expected. This guide shows how to write assertions in Dream Test, how to pick the matcher that fits your value, and what each kind of failure looks like in the report.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How an assertion reads](#how-an-assertion-reads)
- [Which matcher to use](#which-matcher-to-use)
- [Step 1: Compare a value](#step-1-compare-a-value)
- [Step 2: Unwrap a Result or an Option, then check what's inside](#step-2-unwrap-a-result-or-an-option-then-check-whats-inside)
- [Step 3: Check lists, strings and numbers](#step-3-check-lists-strings-and-numbers)
- [Step 4: Decide in your own code](#step-4-decide-in-your-own-code)
- [Step 5: Read the failures](#step-5-read-the-failures)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Write assertions for plain values, `Result`s, `Option`s, lists, strings and numbers.
- Unwrap an `Ok` or a `Some` and check the value inside, in one pipeline.
- Pass or fail a test from your own `case` when no matcher fits.
- Read a real report with one failure of each kind.
- Check that each failing test fails for the reason you meant.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

The examples test the `add` and `divide` functions from that guide, plus a few functions of the Gleam standard library. Every matcher on this page comes from `dream_test/matchers`, which holds all the built-in ones. The outputs are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## How an assertion reads

Every assertion is one pipeline, as in the tests of [Step 1](#step-1-compare-a-value). Read it top to bottom:

- Start from the value you check.
- `should` starts the chain.
- Each matcher checks something (`be_equal`), or unwraps something and passes the inside on (`be_ok`, `be_some`).
- `or_fail_with` ends the chain. It turns the result into what a test returns, and gives the message you'll see if a matcher failed.

There are no macros and no hidden state. A matcher is a plain function from one `MatchResult` to the next, so you can write your own the same way ([Write your own matcher](https://github.com/TrustBound/dream_test/blob/main/docs/guides/custom-matchers.md)). When a matcher fails, it records a structured failure, and the reporters print each kind in its own layout.

## Which matcher to use

| Your value | Use | Why |
|:---|:---|:---|
| Any value you can write out in full | `be_equal(expected)`, `not_equal(other)` | Structural equality. The failure prints both values. |
| A `Bool` | `be_true()`, `be_false()` | Reads better than `be_equal(True)`. |
| A `Result` | `be_ok()`, `be_error()` | Checks the variant, then hands the inside to the next matcher. |
| An `Option` | `be_some()`, `be_none()` | The same, for `Some` and `None`. |
| A `List` | `contain(item)`, `not_contain(item)`, `have_length(n)`, `be_empty()` | The failure prints the whole list. |
| A `String` | `start_with`, `end_with`, `contain_string`, `match_regex` | Checks a part, so unrelated text can change. |
| An `Int` or a `Float` | `be_greater_than`, `be_less_than`, `be_at_least`, `be_at_most`, `be_between`, `be_in_range`, and the `_float` versions | For values you can't pin to one number. |
| A big text or structure | `match_snapshot`, `match_snapshot_inspect` | Compares with a file. See [Lock down large output with snapshots](https://github.com/TrustBound/dream_test/blob/main/docs/guides/snapshot-testing.md). |
| Anything else | `succeed()` and `fail_with(message)` in a `case` | Your own logic, with the same result type. |

The [reference page](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#matchers) lists every matcher with exactly what it checks.

## Step 1: Compare a value

`be_equal` is the matcher you'll use most. It compares with `==`, so it works on any value: numbers, strings, lists, records, tuples. Compare the whole value when you can. A test that checks one field of a record lets the other fields break in silence.

### Compare values and Bools <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/assertions_values.gleam#L15-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    group("equality and booleans", [
      it("compares whole values", fn() {
        string.split("a,b,c", ",")
        |> should
        |> be_equal(["a", "b", "c"])
        |> or_fail_with("the string should split at each comma")
      }),
      it("checks a Bool", fn() {
        list.is_empty([1])
        |> should
        |> be_false()
        |> or_fail_with("a list with one item is not empty")
      }),
    ]),
```

These tests are part of one suite, `tests()` in the snippet file, which imports every matcher of this page from `dream_test/matchers`.

## Step 2: Unwrap a Result or an Option, then check what's inside

Most functions worth testing return a `Result` or an `Option`. Without help, every test would start with a `case` to get the value out. The unwrapping matchers do that for you: `be_ok()` checks that the value is `Ok`, and the next matcher gets the value inside. `be_error()`, `be_some()` and `be_none()` work the same way.

### Unwrap, then check <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/assertions_values.gleam#L29-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    group("Result and Option", [
      it("unwraps an Ok, then checks the value", fn() {
        divide(10, 2)
        |> should
        |> be_ok()
        |> be_equal(5)
        |> or_fail_with("10 / 2 should be Ok(5)")
      }),
      it("unwraps an Error, then checks the error", fn() {
        divide(1, 0)
        |> should
        |> be_error()
        |> contain_string("zero")
        |> or_fail_with("the error should name the zero")
      }),
      it("unwraps a Some", fn() {
        dict.from_list([#("alice", 30)])
        |> dict.get("alice")
        |> option.from_result
        |> should
        |> be_some()
        |> be_equal(30)
        |> or_fail_with("alice should be 30")
      }),
      it("checks a None", fn() {
        option.from_result(dict.get(dict.new(), "bob"))
        |> should
        |> be_none()
        |> or_fail_with("an empty dict has no bob")
      }),
    ]),
```

The chain reads as the sentence you mean: "this should be Ok, and the value should be 5". When the first matcher fails, the ones after it don't run, and the failure names the first one. So you never get a confusing "expected 5, got Error(...)".

## Step 3: Check lists, strings and numbers

Sometimes you don't know the whole value, or you don't care about all of it. A list from a database query comes back in any order. A message includes a timestamp. A duration is "under a second", not an exact number. Check the part that matters:

### Check a part of a value <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/assertions_values.gleam#L60-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    group("lists, strings and numbers", [
      it("finds an item and counts the items", fn() {
        [1, 2, 3]
        |> should
        |> contain(2)
        |> have_length(3)
        |> or_fail_with("the list should hold 2, and three items")
      }),
      it("checks an empty list", fn() {
        list.filter([1, 3, 5], int_is_even)
        |> should
        |> be_empty()
        |> or_fail_with("no odd number is even")
      }),
      it("checks the start of a string", fn() {
        string.uppercase("hello world")
        |> should
        |> start_with("HELLO")
        |> or_fail_with("the text should start with HELLO")
      }),
      it("checks a range", fn() {
        string.length("hello")
        |> should
        |> be_between(1, 10)
        |> or_fail_with("the length should be between 1 and 10")
      }),
    ]),
```

Matchers that don't unwrap pass the same value on, so `contain(2) |> have_length(3)` checks two things about one list. Keep such chains short: each extra check is one more thing the failure must explain.

Two range matchers look alike, so check which one you mean. `be_between(1, 10)` is strict: `1 < value < 10`. `be_in_range(1, 10)` includes both ends: `1 <= value <= 10`.

## Step 4: Decide in your own code

Some checks don't fit a matcher: a value with several right answers, or a check that depends on an earlier branch. Write a `case`, and return `Ok(succeed())` or `Ok(fail_with(message))` from each branch. Both give the same type as an `or_fail_with` chain, so the test body stays a normal test body:

### Pass or fail from a case <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/assertions_values.gleam#L87-L96"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    group("your own logic", [
      it("passes or fails with a case", fn() {
        case divide(9, 3) {
          Ok(3) -> Ok(succeed())
          Ok(other) ->
            Ok(fail_with("expected 3, got " <> string.inspect(other)))
          Error(message) -> Ok(fail_with(message))
        }
      }),
    ]),
```

A test body returns `Result(AssertionResult, String)`. The `Error` side is for code that can't even get to the assertion, such as a setup step that fails. That makes `use value <- result.try(...)` work in a test body: an `Error` ends the test as a failure with that text.

## Step 5: Read the failures

Here's a suite with seven tests, each failing in a different way. It lives in a function named `failing_tests()`, so it doesn't run as one of the project's tests. The last test returns an `Error` from its body:

### A test body that returns an Error <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/assertions_failures.gleam#L59-L65"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    it("an Error from the test body", fn() {
      use quotient <- result.try(divide(1, 0))
      quotient
      |> should
      |> be_equal(0)
      |> or_fail_with("1 / 0 should be 0")
    }),
```

The run prints this report. It's the report of `bdd.failures_only()`, which leaves out the passing tests and doesn't repeat the failures, so each failure shows once:

### One failure of each kind <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_assertions_failures.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Failures
  ✗ a different value
    be_equal
      Message: the string should split at each separator
      Expected: ["a", "b", "c"]
      Actual:   ["a", "b;c"]
  ✗ an Error where an Ok was expected
    be_ok
      Message: 1 / 0 should be Ok(0)
      Expected: Ok(_)
      Actual:   Error("Cannot divide by zero")
  ✗ a None where a Some was expected
    be_some
      Message: alice should be 30
      Expected: Some(_)
      Actual:   None
  ✗ a missing item
    contain
      Message: the list should hold 4
      Operation: contain
      Expected: 4
      Actual:   [1, 2, 3]
  ✗ a string with another start
    start_with
      Message: the text should start with HELLO
      Operation: start_with
      Pattern:   HELLO
      Actual:    hello world
  ✗ a failure from your own logic
    fail_with
      Message: 9 / 2 should not round down
  ✗ an Error from the test body
    error
      Message: Cannot divide by zero

Summary: 7 run, 7 failed, 0 passed in 0ms
```

What to read in each:

- The line under the test name is the matcher that failed, the *operator*. In the second test it's `be_ok`, not `be_equal`: the chain stopped at the first matcher that failed.
- `Message` is your `or_fail_with` text, or the text you gave `fail_with`.
- `Expected` and `Actual` show the values. For a list or a string, the failure also shows the operation and, for strings, the pattern.
- `fail_with` has only your message. Put the values in it, as the `case` in Step 4 does with `string.inspect`.
- `error` is the operator of an `Error` from the test body. Its message is the text of the `Error`, so make that text say what went wrong.

## Test your code

A failing test proves something only when it fails for the right reason. A test that should fail at `be_equal`, but fails at `be_ok` because the setup broke, hides the real problem. You can check that with Dream Test: run the suite silently, and read the operator of each failure from the report.

### Check why each test fails <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/assertions_failure_reasons.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{type AssertionFailure, type RunReport, type TestResult}
import dream_test/unit.{describe, it}
import gleam/list
import snippets/guides/assertions_failures.{failing_tests}

pub fn tests() {
  describe("The failure examples", [
    it("each fail at the matcher that the test name says", fn() {
      // Act
      let report =
        runner.new([failing_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      failed_operators(report)
      |> should
      |> be_equal([
        #("a different value", ["be_equal"]),
        #("an Error where an Ok was expected", ["be_ok"]),
        #("a None where a Some was expected", ["be_some"]),
        #("a missing item", ["contain"]),
        #("a string with another start", ["start_with"]),
        #("a failure from your own logic", ["fail_with"]),
        #("an Error from the test body", ["error"]),
      ])
      |> or_fail_with("each test should fail at its own matcher")
    }),
  ])
}

/// The name of each test, with the operator of each of its failures.
fn failed_operators(report: RunReport) -> List(#(String, List(String))) {
  types.report_tests(report)
  |> list.map(name_and_operators)
}

fn name_and_operators(result: TestResult) -> #(String, List(String)) {
  #(result.name, list.map(result.failures, operator))
}

fn operator(failure: AssertionFailure) -> String {
  failure.operator
}
```

Each `TestResult` holds its `failures`, a list of `AssertionFailure` values with the `operator`, the `message` and a `payload` with the details that the reporters print. The check passes:

### The report of the check <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_assertions_reasons.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The failure examples
  ✓ each fail at the matcher that the test name says

Summary: 1 run, 0 failed, 1 passed in 0ms
```

## Common pitfalls

**A vague `or_fail_with` message.** *Symptom:* the log says `Message: should work`, and you open the code to find out what "work" meant. *Fix:* say what should be true, in terms of the values: "10 / 2 should be Ok(5)".

**One chain that checks too much.** *Symptom:* a long chain fails, and the message fits only one of its checks. *Fix:* split it into two tests, each with its own message.

**A partial check where the whole value is known.** *Symptom:* a field you didn't check changes, and every test still passes. *Fix:* when you can write out the whole value, use `be_equal` on all of it.

**`be_between` for an inclusive range.** *Symptom:* a value equal to a bound fails. *Fix:* `be_between` leaves out both bounds. Use `be_in_range` to include them.

**`result.unwrap` in a test body.** *Symptom:* a test passes with a default value after the code returned an `Error`. *Fix:* use `be_ok()` or `use value <- result.try(...)`, so an `Error` fails the test.

**A snapshot for a small value.** *Symptom:* a test reads a file to compare a three-item list. *Fix:* use `be_equal`. Snapshots are for output too big to write out by hand.

## Where to go next

- [Write your own matcher](https://github.com/TrustBound/dream_test/blob/main/docs/guides/custom-matchers.md): a matcher for your own types, with its own failure output.
- [Lock down large output with snapshots](https://github.com/TrustBound/dream_test/blob/main/docs/guides/snapshot-testing.md): compare big outputs with a file.
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#matchers): every built-in matcher.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/matchers.html): `dream_test/matchers`.
