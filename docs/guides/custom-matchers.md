# Write your own matcher

The built-in matchers know about `Int`s, `String`s, lists, `Result`s and `Option`s. They don't know about your types. When every test of a web handler starts with three lines that pull the status out of a response and compare it, the tests get long, and the failures say `Expected: 200, Actual: 404` with no hint of what was compared. A matcher of your own fixes both: the test reads `|> have_status(200)`, and the failure says what it expected in your words. This guide builds two matchers for a response type, shows the failure they print, and tests them.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [What a matcher is](#what-a-matcher-is)
- [Which kind of matcher to write](#which-kind-of-matcher-to-write)
- [Step 1: Write a matcher that checks](#step-1-write-a-matcher-that-checks)
- [Step 2: Write a matcher that unwraps](#step-2-write-a-matcher-that-unwraps)
- [Step 3: Use them in a test](#step-3-use-them-in-a-test)
- [Step 4: Read the failure](#step-4-read-the-failure)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Write `have_status(expected)`, a matcher that checks a field of your type and passes the value on.
- Write `have_body()`, a matcher that unwraps a field, so the built-in string matchers can check it.
- Chain them with built-in matchers in a test.
- Read the failure your matcher prints.
- Test the matchers themselves, pass, fail and pass-through, with exact values.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up, and [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md) shows how assertion pipelines work.

```sh
gleam add --dev dream_test
```

The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## What a matcher is

There's no special API for matchers. A matcher is a function that takes a `MatchResult(a)` and returns a `MatchResult(b)`, both from `dream_test/types`:

- `MatchOk(value)` means every matcher so far passed, and `value` is what the next one checks.
- `MatchFailed(failure)` means a matcher failed. `failure` is an `AssertionFailure` with an `operator` (the matcher's name), a `message` and a `payload` with the details the reporters print.

`should` turns your value into `MatchOk(value)`. Each matcher looks at what it gets: a failure passes through unchanged, and a value gets checked. `or_fail_with` ends the chain and puts its message into the failure. The built-in matchers in `dream_test/matchers` are written exactly this way.

## Which kind of matcher to write

| Your situation | Write | Returns |
|:---|:---|:---|
| Check something about the value, and keep checking the same value | A checking matcher, like `have_status` | `MatchResult(a)` for a `MatchResult(a)` |
| Get a part of the value out, for the next matcher | An unwrapping matcher, like `have_body` or the built-in `be_ok` | `MatchResult(b)` for a `MatchResult(a)` |
| A check you use once, in one test | No matcher. A `case` with `succeed()` and `fail_with(...)` | `Result(AssertionResult, String)` |

## Step 1: Write a matcher that checks

Here's the module of this guide: a `Response` type, the `handle` function under test, the two matchers, and the tests of `handle` itself. In your project, the matchers go in a helper module under `test/`, next to the tests that use them. Start with `have_status`:

### A response type and its matchers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/custom_matchers_response.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{
  type MatchResult, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/option.{Some}

/// A response of your web handler.
pub type Response {
  Response(status: Int, body: String)
}

/// The handler under test.
pub fn handle(path: String) -> Response {
  case path {
    "/hello/" <> name -> Response(status: 200, body: "Hello, " <> name)
    _ -> Response(status: 404, body: "Not found")
  }
}

/// Passes when the response has the status `expected`. The next matcher
/// gets the same response.
pub fn have_status(
  result: MatchResult(Response),
  expected: Int,
) -> MatchResult(Response) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> check_status(response, expected)
  }
}

fn check_status(response: Response, expected: Int) -> MatchResult(Response) {
  case response.status == expected {
    True -> MatchOk(response)
    False ->
      MatchFailed(AssertionFailure(
        operator: "have_status",
        message: "",
        payload: Some(CustomMatcherFailure(
          actual: int.to_string(response.status),
          description: "expected the status " <> int.to_string(expected),
        )),
      ))
  }
}

/// Unwraps the body of the response. The next matcher gets the body.
pub fn have_body(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> MatchOk(response.body)
  }
}

pub fn tests() {
  describe("handle", [
    it("greets the name in the path", fn() {
      // Act
      let response = handle("/hello/alice")

      // Assert
      response
      |> should
      |> be_equal(Response(status: 200, body: "Hello, alice"))
      |> or_fail_with("the handler should greet alice")
    }),
    it("answers 404 for another path", fn() {
      // Act
      let response = handle("/hello")

      // Assert
      response
      |> should
      |> be_equal(Response(status: 404, body: "Not found"))
      |> or_fail_with("the handler should not know /hello")
    }),
  ])
}
```

Walk through `have_status`:

- The first argument is the `MatchResult` from the chain, so the matcher fits in a pipe: `|> have_status(200)` calls `have_status(previous, 200)`.
- `MatchFailed(failure) -> MatchFailed(failure)` passes an earlier failure through. The first failure in a chain is the one the report shows.
- `check_status` does the real work. On success it returns `MatchOk(response)`, the same value, so another matcher can check the same response.
- On failure it builds an `AssertionFailure`. The `operator` is the name the report prints under the test. Leave `message` empty: `or_fail_with` fills it in. The payload `CustomMatcherFailure(actual:, description:)` holds two texts, and the reporters print both.

## Step 2: Write a matcher that unwraps

`have_body` in the same module changes the type. It takes a `MatchResult(Response)` and returns a `MatchResult(String)`. It never fails by itself: it only passes the body on, so the built-in string matchers can check it. That's how `be_ok` works too, from `Result(a, e)` to `a`.

An unwrapping matcher that can fail, such as one that parses JSON from the body, returns `MatchFailed` with its own operator when the part isn't there.

## Step 3: Use them in a test

Import your matchers next to the built-in ones, and chain them:

### Use the matchers in a test <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/custom_matchers_usage.gleam#L1-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{contain_string, or_fail_with, should}
import dream_test/unit.{describe, it}
import snippets/guides/custom_matchers_response.{handle, have_body, have_status}

pub fn tests() {
  describe("handle", [
    it("greets a user by name", fn() {
      handle("/hello/alice")
      |> should
      |> have_status(200)
      |> have_body()
      |> contain_string("alice")
      |> or_fail_with("the greeting should name alice")
    }),
  ])
}
```

The chain reads as one sentence: "handling /hello/alice should have status 200, have a body, and the body should contain alice".

## Step 4: Read the failure

Here's a test of a path the handler doesn't know. It fails at your matcher:

### A test that fails at the custom matcher <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/custom_matchers_usage.gleam#L18-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// A test that fails at the custom matcher, for the report in the guide.
/// It is not in `tests`, so test discovery does not run it.
pub fn failing_tests() {
  describe("handle", [
    it("greets a user who is not there", fn() {
      handle("/hello")
      |> should
      |> have_status(200)
      |> have_body()
      |> contain_string("alice")
      |> or_fail_with("the greeting should name alice")
    }),
  ])
}
```

The report:

### The failure of a custom matcher <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_custom_matchers_failure.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
handle
  ✗ greets a user who is not there
    have_status
      Message: the greeting should name alice
      Description: expected the status 200
      Actual:      404
    Run it alone: gleam test -- --only "handle/greets a user who is not there"

Failures:
handle
  ✗ greets a user who is not there
    have_status
      Message: the greeting should name alice
      Description: expected the status 200
      Actual:      404
    Run it alone: gleam test -- --only "handle/greets a user who is not there"

Summary: 1 run, 1 failed, 0 passed in 0ms
```

The operator is `have_status`, the name you gave it. `Description` and `Actual` come from the `CustomMatcherFailure` payload. The chain stopped there, so `have_body` and `contain_string` never ran, and the report doesn't blame them.

Write the description so that it reads with the actual value: "expected the status 200", then `404`. When your type has no short text form, put the part that matters into `actual`, not the whole value.

## Test your code

A matcher is code that every test trusts, so a bug in it hides bugs everywhere. A matcher is also a pure function, so its tests are plain: call it with a `MatchOk` or a `MatchFailed`, and compare the result with the exact value you expect. Test the three cases every matcher has: it passes, it fails, and it passes an earlier failure through.

### Tests for the matchers <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/custom_matchers_matcher_tests.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/types.{
  AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
}
import dream_test/unit.{describe, group, it}
import gleam/option.{None, Some}
import snippets/guides/custom_matchers_response.{
  Response, have_body, have_status,
}

pub fn tests() {
  describe("Response matchers", [
    group("have_status", [
      it("passes the response on when the status matches", fn() {
        // Arrange
        let response = Response(status: 200, body: "ok")

        // Act
        let result = have_status(MatchOk(response), 200)

        // Assert
        result
        |> should
        |> be_equal(MatchOk(response))
        |> or_fail_with("a matching status should pass the response on")
      }),
      it("fails with the actual status when it differs", fn() {
        // Arrange
        let response = Response(status: 404, body: "Not found")

        // Act
        let result = have_status(MatchOk(response), 200)

        // Assert
        result
        |> should
        |> be_equal(
          MatchFailed(AssertionFailure(
            operator: "have_status",
            message: "",
            payload: Some(CustomMatcherFailure(
              actual: "404",
              description: "expected the status 200",
            )),
          )),
        )
        |> or_fail_with("a different status should fail with both statuses")
      }),
      it("keeps a failure from an earlier matcher", fn() {
        // Arrange
        let earlier =
          AssertionFailure(operator: "be_ok", message: "", payload: None)

        // Act
        let result = have_status(MatchFailed(earlier), 200)

        // Assert
        result
        |> should
        |> be_equal(MatchFailed(earlier))
        |> or_fail_with("an earlier failure should pass through unchanged")
      }),
    ]),
    group("have_body", [
      it("passes the body on", fn() {
        // Act
        let result = have_body(MatchOk(Response(status: 200, body: "Hi")))

        // Assert
        result
        |> should
        |> be_equal(MatchOk("Hi"))
        |> or_fail_with("the next matcher should get the body")
      }),
    ]),
  ])
}
```

The second test pins the whole failure: the operator, the empty message and the payload. If someone changes the description, the test fails and shows the new value. The report:

### The report of the matcher tests <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_custom_matchers_checks.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Response matchers
  have_status
    ✓ passes the response on when the status matches
    ✓ fails with the actual status when it differs
    ✓ keeps a failure from an earlier matcher
  have_body
    ✓ passes the body on

Summary: 4 run, 0 failed, 4 passed in 0ms
```

## Common pitfalls

**A failure that doesn't pass through.** *Symptom:* a test fails at a later matcher, and the report blames the wrong check. *Fix:* start every matcher with `MatchFailed(failure) -> MatchFailed(failure)`, and test that case, as the third test does.

**A message in the matcher.** *Symptom:* your text vanishes from the report. *Fix:* `or_fail_with` replaces the `message` of the failure. Put the details in the payload, and leave `message` empty.

**An operator that doesn't match the function name.** *Symptom:* the report names a matcher nobody can find with a search. *Fix:* use the function name as the `operator`.

**A matcher for a one-off check.** *Symptom:* a module of matchers that each serve one test. *Fix:* for a single test, a `case` with `succeed()` and `fail_with(...)` is shorter. Write a matcher when the check repeats.

## Where to go next

- [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md): the built-in matchers you'll chain with yours.
- [Reference](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reference.md#matchers): every built-in matcher and its failure payload.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/types.html): `MatchResult`, `AssertionFailure` and `FailurePayload`.
