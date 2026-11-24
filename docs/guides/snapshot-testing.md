# Lock down large output with snapshots

Some outputs are too big to write out in a test: a rendered page, a receipt, a JSON document, an error message with ten lines of context. You could check a few parts with `contain_string`, but then a change to every other part slips through. A snapshot test stores the whole output in a file the first time, and compares every later run with that file. This guide shows the first run, what a changed output looks like in the report, how to update a snapshot on purpose, and how to keep snapshot tests from passing when they check nothing.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [When a snapshot fits](#when-a-snapshot-fits)
- [Step 1: Write a snapshot test](#step-1-write-a-snapshot-test)
- [Step 2: Read and commit the snapshot files](#step-2-read-and-commit-the-snapshot-files)
- [Step 3: See a change fail](#step-3-see-a-change-fail)
- [Step 4: Update a snapshot on purpose](#step-4-update-a-snapshot-on-purpose)
- [When the snapshot file is missing](#when-the-snapshot-file-is-missing)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide you'll:

- Snapshot a rendered receipt as text, and a list as its Gleam form.
- Read the snapshot files the first run writes.
- Change the receipt and read the failure: a line diff of the old and the new text.
- Update the snapshot after a change you meant.
- Check that a missing snapshot can't make CI pass without checking anything.

## Before you start

You need Dream Test as a dev dependency and a test runner module. [Write and run your first test](https://github.com/TrustBound/dream_test/blob/main/docs/guides/getting-started.md) sets both up.

```sh
gleam add --dev dream_test
```

The outputs on this page are real outputs of the code shown, with every time set to 0, so they stay the same from run to run.

## When a snapshot fits

| Your situation | Use | Why |
|:---|:---|:---|
| A small value you can write out | `be_equal(expected)` | The expected value sits in the test, where the reader sees it. |
| A big `String`: HTML, JSON, a report, a long message | `match_snapshot(path)` | The file holds the whole text, and any change fails the test. |
| A big value that isn't a `String`: a list, a record, a dict | `match_snapshot_inspect(path)` | It stores `string.inspect(value)`, the value as Gleam code. |
| Output with a timestamp, a random id or a path of the machine | A snapshot of the output after you replace those parts | Unstable data fails the snapshot on every run. |

A snapshot that fails every day for expected reasons trains you to accept every diff without reading it. Then it guards nothing.

## Step 1: Write a snapshot test

The code under test renders a receipt for a list of items with prices in cents. The suite checks the receipt with `match_snapshot`, and the list of items with `match_snapshot_inspect`:

### Snapshot a receipt <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/snapshot_receipt.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/matchers.{
  match_snapshot, match_snapshot_inspect, or_fail_with, should,
}
import dream_test/unit.{describe, it}
import gleam/int
import gleam/list
import gleam/string

/// The code under test: a receipt for a list of items and prices in cents.
pub fn render_receipt(items: List(#(String, Int))) -> String {
  let lines = list.map(items, receipt_line)
  let total = list.fold(items, 0, add_price)
  string.join(lines, "\n") <> "\nTOTAL " <> cents(total) <> "\n"
}

fn receipt_line(item: #(String, Int)) -> String {
  string.pad_end(item.0, 12, ".") <> " " <> cents(item.1)
}

fn add_price(total: Int, item: #(String, Int)) -> Int {
  total + item.1
}

fn cents(amount: Int) -> String {
  int.to_string(amount / 100)
  <> "."
  <> string.pad_start(int.to_string(amount % 100), 2, "0")
}

pub fn tests() {
  describe("Receipt", [
    it("renders the items and the total", fn() {
      render_receipt([#("coffee", 350), #("croissant", 275)])
      |> should
      |> match_snapshot("./test/snapshots/guide_receipt.snap")
      |> or_fail_with("the receipt should match the snapshot")
    }),
    it("keeps the items in order", fn() {
      [#("coffee", 350), #("croissant", 275)]
      |> list.reverse
      |> should
      |> match_snapshot_inspect("./test/snapshots/guide_receipt_items.snap")
      |> or_fail_with("the items should match the snapshot")
    }),
  ])
}
```

`match_snapshot` takes the path of the snapshot file, relative to the project folder where `gleam test` runs. Keep them together, for example in `test/snapshots/`. Both matchers pass the value on, so you can chain other matchers after them.

The first run has no snapshot files. Each snapshot test writes its file and passes:

### The first run <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_snapshot_first.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Receipt
  ✓ renders the items and the total
  ✓ keeps the items in order

Summary: 2 run, 0 failed, 2 passed in 0ms
```

## Step 2: Read and commit the snapshot files

The run wrote two files. `test/snapshots/guide_receipt.snap` holds the receipt exactly as `render_receipt` returned it:

### The receipt snapshot <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snapshots/guide_receipt.snap"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
coffee...... 3.50
croissant... 2.75
TOTAL 6.25
```

`test/snapshots/guide_receipt_items.snap` holds the reversed list as `string.inspect` writes it, `[#("croissant", 275), #("coffee", 350)]`, with no newline at the end.

Read each new snapshot before you commit it. The first run accepts whatever the code returned, bugs included, so the snapshot is only as right as your review of it. Then commit the `.snap` files with the test. They're part of the test: without them, the test checks nothing.

## Step 3: See a change fail

Now the croissant costs 2.95. Here's the same test with the new price:

### A test of a changed receipt <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/snapshot_changed.gleam#L12-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn changed_receipt_tests() {
  describe("Receipt", [
    it("renders the items and the total", fn() {
      render_receipt([#("coffee", 350), #("croissant", 295)])
      |> should
      |> match_snapshot("./test/snapshots/guide_receipt.snap")
      |> or_fail_with("the receipt should match the snapshot")
    }),
  ])
}
```

The snapshot still holds 2.75, so the test fails:

### The failure of a changed snapshot <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_snapshot_changed.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Receipt
  ✗ renders the items and the total
    match_snapshot
      Message: the receipt should match the snapshot
      Snapshot: ./test/snapshots/guide_receipt.snap
      Diff (- expected, + actual):
          coffee...... 3.50
        - croissant... 2.75
        - TOTAL 6.25
        + croissant... 2.95
        + TOTAL 6.45
    Run it alone: gleam test -- --only "Receipt/renders the items and the total"

Failures:
Receipt
  ✗ renders the items and the total
    match_snapshot
      Message: the receipt should match the snapshot
      Snapshot: ./test/snapshots/guide_receipt.snap
      Diff (- expected, + actual):
          coffee...... 3.50
        - croissant... 2.75
        - TOTAL 6.25
        + croissant... 2.95
        + TOTAL 6.45
    Run it alone: gleam test -- --only "Receipt/renders the items and the total"

Summary: 1 run, 1 failed, 0 passed in 0ms
```

The failure names the snapshot file, then shows a line diff of the text of the file against the new text. A line that starts with `-` is in the snapshot only, a line that starts with `+` is in the new text only, and a line that starts with two spaces is in both. Here the second and third lines changed.

The diff shows the lines around each change and hides the rest: a run of more than 3 unchanged lines away from a change shows as one `... N unchanged lines` line, and a long diff stops after 100 lines with `... N more lines of the diff`. A changed line shows its trailing spaces as `·`, tabs as `→` and carriage returns as `␍`, so a change of whitespace only is visible too. The snapshot comparison ignores newlines at the end of both texts, so the diff never shows them. A snapshot of one line keeps the `Expected:` and `Actual:` lines. `bdd.color()` shows the `-` lines in green and the `+` lines in red.

Now decide. If the change is a bug, fix the code. If you meant it, update the snapshot.

## Step 4: Update a snapshot on purpose

1. Delete the `.snap` file of the test. To do it from code, call `snapshot.clear_snapshot(path)`. `snapshot.clear_snapshots_in_directory(directory)` deletes every `.snap` file in a folder, but not in its subfolders. Both are also in `dream_test/matchers`.
2. Run the tests. The test writes the new value to the file and passes.
3. If you added a `clear_snapshot` or `clear_snapshots_in_directory` call, remove it. If it stays, every run deletes the snapshot and writes it again, and the test checks nothing.
4. Read the new file, then commit it. The diff of the `.snap` file in your pull request shows the reviewer exactly what changed.

## When the snapshot file is missing

A missing snapshot isn't a failure: the test passes and writes the file. That's what makes the first run work, and it's also a trap. If you forget to commit a `.snap` file, CI starts without it, every snapshot test passes, and nothing gets checked. The run is green, and wrong.

So commit every `.snap` file, and check in CI that the run didn't write new ones. For example, a step after `gleam test` that fails when `git status --porcelain test/snapshots` prints anything.

## Test your code

Two things decide whether your snapshot tests guard anything: a changed value must fail, and a missing file must behave as you expect. You can check both with Dream Test. The first check deletes a snapshot file, runs a suite, and looks at the run and the file:

### Check what a missing snapshot does <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/snapshot_first_run.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream_test/file
import dream_test/matchers.{be_equal, match_snapshot, or_fail_with, should}
import dream_test/runner
import dream_test/types
import dream_test/unit.{describe, it}
import gleam/result

const new_snapshot = "build/guide_snapshots/new.snap"

fn suite_with_a_new_snapshot() {
  describe("Receipt", [
    it("renders a new receipt", fn() {
      "TOTAL 0.00\n"
      |> should
      |> match_snapshot(new_snapshot)
      |> or_fail_with("the receipt should match the snapshot")
    }),
  ])
}

pub fn tests() {
  describe("A snapshot test with no snapshot file", [
    it("passes and writes the file", fn() {
      // Arrange
      use Nil <- result.try(
        file.delete(new_snapshot) |> result.map_error(file.error_to_string),
      )

      // Act
      let failed =
        runner.new([suite_with_a_new_snapshot()])
        |> runner.silent()
        |> runner.run()
        |> types.failed

      // Assert
      #(failed, file.read(new_snapshot))
      |> should
      |> be_equal(#(False, Ok("TOTAL 0.00\n")))
      |> or_fail_with("the run should pass and write the value")
    }),
  ])
}
```

The second check is the `tests()` function of the changed receipt module: it runs the changed receipt against the snapshot and expects one failure.

### Check that a change fails <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/guides/snapshot_changed.gleam#L23-L39"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() {
  describe("A changed receipt", [
    it("fails its snapshot test", fn() {
      // Act
      let report =
        runner.new([changed_receipt_tests()])
        |> runner.silent()
        |> runner.run()

      // Assert
      summary.count(report).failed
      |> should
      |> be_equal(1)
      |> or_fail_with("the changed receipt should not match")
    }),
  ])
}
```

Both pass:

### The report of the snapshot checks <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/outputs/guide_snapshot_check.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
A snapshot test with no snapshot file
  ✓ passes and writes the file
A changed receipt
  ✓ fails its snapshot test

Summary: 2 run, 0 failed, 2 passed in 0ms
```

## Common pitfalls

**A `.snap` file that isn't committed.** *Symptom:* CI passes, and the snapshot tests checked nothing. *Fix:* commit every `.snap` file, and fail CI when a run writes a new one.

**A clear call left in the test.** *Symptom:* the snapshot test never fails, whatever you change. *Fix:* remove `clear_snapshot` and `clear_snapshots_in_directory` after the update.

**Unstable data in the output.** *Symptom:* the snapshot test fails on every run, with a different time each time. *Fix:* replace the unstable parts before the match, for example the timestamp with `<time>`.

**A snapshot accepted without a review.** *Symptom:* a bug is in the snapshot, and the test protects it. *Fix:* read every new or changed `.snap` file before you commit it, as you'd read code.

**A snapshot for a tiny value.** *Symptom:* a test reads a file to check a three-item list. *Fix:* use `be_equal`, so the expected value is in the test.

## Where to go next

- [Check values with matchers](https://github.com/TrustBound/dream_test/blob/main/docs/guides/assertions-and-matchers.md): the matchers that chain with snapshots.
- [Choose and read the test output](https://github.com/TrustBound/dream_test/blob/main/docs/guides/reporters.md): render a report to a `String`, for a snapshot of your own output.
- [API reference on HexDocs](https://hexdocs.pm/dream_test/dream_test/matchers/snapshot.html): `match_snapshot`, `match_snapshot_inspect`, `clear_snapshot` and `clear_snapshots_in_directory`.
