# MOTHBALL.md

## Commands to run (sanity)

```bash
make test
make examples
```

## DONE (hexdocs/snippets are in the “good” format)

Core:

- `src/dream_test/unit.gleam`
- `src/dream_test/unit_context.gleam`
- `src/dream_test/runner.gleam`
- `src/dream_test/parallel.gleam`
- `src/dream_test/context.gleam`
- `src/dream_test/sandbox.gleam`
- `src/dream_test/process.gleam`
- `src/dream_test/discover.gleam`

Matchers:

- `src/dream_test/matchers.gleam`
- `src/dream_test/matchers/boolean.gleam`
- `src/dream_test/matchers/collection.gleam`
- `src/dream_test/matchers/comparison.gleam`
- `src/dream_test/matchers/equality.gleam`
- `src/dream_test/matchers/option.gleam`
- `src/dream_test/matchers/result.gleam`
- `src/dream_test/matchers/snapshot.gleam`
- `src/dream_test/matchers/string.gleam`

Reporters:

- `src/dream_test/reporters.gleam`
- `src/dream_test/reporters/json.gleam`

Gherkin:

- `src/dream_test/gherkin/world.gleam`

Snippets harness:

- `examples/snippets/test/snippets_test.gleam` (uses `discover.tests("snippets/**.gleam")`)
- `src/dream_test_test_discovery_ffi.erl` (discovery ignores modules without `tests/0`)

## NOT DONE YET (needs the same treatment)

Core:

- `src/dream_test/file.gleam`
- `src/dream_test/types.gleam`
- `src/dream_test/timing.gleam`

Reporters:

- `src/dream_test/reporters/types.gleam`
- `src/dream_test/reporters/bdd.gleam`
- `src/dream_test/reporters/progress.gleam`
- `src/dream_test/reporters/gherkin.gleam`

Gherkin:

- `src/dream_test/gherkin/steps.gleam`
- `src/dream_test/gherkin/types.gleam`
- `src/dream_test/gherkin/feature.gleam`
- `src/dream_test/gherkin/step_trie.gleam`
- `src/dream_test/gherkin/parser.gleam`
- `src/dream_test/gherkin/discover.gleam`

## Rules to follow (with concrete examples)

### Hexdocs rules

- **No repo paths in docs**

  - Bad: “See `examples/snippets/test/snippets/utils/file_helpers.gleam`”
  - Good: explain the concept + show the actual example code inline.

- **Every example is verbatim from `examples/snippets/test/snippets/**`\*\*

  - Good: copy/paste an excerpt exactly as-is from a snippet module.
  - Bad: “pseudo-code”, or rewriting snippet code to “read nicer” in docs.

- **Every public item gets complete docs**

  - Minimum per `pub fn`: 1–2 sentence purpose + **Parameters** + **Returns** + **Example**.
  - Minimum per `pub type`: concept + constructors/fields (as applicable) + an example if it helps.

- **Examples should read like real usage**
  - Prefer expression-only excerpts.
  - If an excerpt only makes sense in a specific place, say it plainly:
    “Use this inside an `it` block.” / “Use this in test setup.”

Example (good: expression-only excerpt):

```gleam
"hello world"
|> should
|> start_with("hello")
|> or_fail_with("expected string to start with \"hello\"")
```

Example (good: small block only when setup is required):

```gleam
let path = "./test/tmp/clear_snapshot_example.snap"
use _ <- result.try(file.write(path, "hello"))

clear_snapshot(path)
|> should
|> be_equal(Ok(Nil))
|> or_fail_with("expected clear_snapshot to succeed")
```

### Public API rules

- **Named params always (labeled args or config record)**
  - Good (labeled args; still supports positional calls):

```gleam
pub fn call_actor(
  subject subject: Subject(msg),
  make_message make_message: fn(Subject(reply)) -> msg,
  timeout_ms timeout_ms: Int,
) -> reply
```

- Good (config record) when there are many parameters or it improves readability.

- **Prefer semantic return types over tuples**
  - Bad:

```gleam
pub fn run_thing(...) -> (Int, String)
```

- Good:

```gleam
pub type RunThingResult {
  RunThingResult(count: Int, message: String)
}
```

- **No nested `case` in public functions**
  - If you see `case` inside a `case` in a `pub fn`, refactor (extract helpers, flatten branches).

### Snippet rules

- **One assertion per `it` and return it**
  - Bad:

```gleam
it("does a thing", fn() {
  let _ = value |> should |> be_equal(1) |> or_fail_with("...")
  Ok(succeed())
})
```

- Good:

```gleam
it("does a thing", fn() {
  value
  |> should
  |> be_equal(1)
  |> or_fail_with("...")
})
```

- **Setup does not assert**
  - If setup can fail: use `use` to short-circuit into the test’s single failure.

## Good hexdocs examples (copy these patterns)

Source files to copy patterns from:

- `src/dream_test/process.gleam` (module docs + “Use this inside an `it` block” + labeled args)
- `src/dream_test/matchers/snapshot.gleam` (explicit Behavior/Returns)
- `src/dream_test/matchers/string.gleam` (simple matcher docs)
