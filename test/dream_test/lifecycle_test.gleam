import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/process.{get_count, increment, start_counter}
import dream_test/runner
import dream_test/types.{AssertionOk, Passed, SetupFailed}
import dream_test/unit.{
  after_all, after_each, before_each, describe, describe_with_hooks, group,
  hooks, it,
}
import gleam/list

pub fn tests() {
  describe("Lifecycle Hooks", [
    group("before_each", [
      it("runs before each test", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks("Suite", hooks(fn() { Ok(counter) }), [
            before_each(fn(c) {
              increment(c)
              Ok(c)
            }),
            it("test one", fn(_c) { Ok(AssertionOk) }),
            it("test two", fn(_c) { Ok(AssertionOk) }),
          ])

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(2)
        |> or_fail_with("before_each should run once per test")
      }),

      it("inherits hooks from parent describe blocks", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks("Outer", hooks(fn() { Ok(counter) }), [
            before_each(fn(c) {
              increment(c)
              Ok(c)
            }),
            group("Inner", [
              it("nested test", fn(_c) { Ok(AssertionOk) }),
            ]),
          ])

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("Parent before_each should run for nested tests")
      }),
    ]),

    group("after_each", [
      it("runs after each test", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks("Suite", hooks(fn() { Ok(counter) }), [
            after_each(fn(c) {
              increment(c)
              Ok(Nil)
            }),
            it("test one", fn(_c) { Ok(AssertionOk) }),
            it("test two", fn(_c) { Ok(AssertionOk) }),
          ])

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(2)
        |> or_fail_with("after_each should run once per test")
      }),

      it("runs even when test fails", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks("Suite", hooks(fn() { Ok(counter) }), [
            after_each(fn(c) {
              increment(c)
              Ok(Nil)
            }),
            it("failing test", fn(_c) {
              1
              |> should()
              |> equal(2)
              |> or_fail_with("Intentional failure")
            }),
          ])

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("after_each should run even when test fails")
      }),
    ]),

    group("before_all / after_all", [
      it("before_all runs once per group", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks(
            "Suite",
            hooks(fn() {
              increment(counter)
              Ok(counter)
            }),
            [
              it("test one", fn(_c) { Ok(AssertionOk) }),
              it("test two", fn(_c) { Ok(AssertionOk) }),
            ],
          )

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("before_all should run exactly once per group")
      }),

      it("after_all runs once per group", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks("Suite", hooks(fn() { Ok(counter) }), [
            after_all(fn(c) {
              increment(c)
              Ok(Nil)
            }),
            it("test one", fn(_c) { Ok(AssertionOk) }),
            it("test two", fn(_c) { Ok(AssertionOk) }),
          ])

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(1)
        |> or_fail_with("after_all should run exactly once per group")
      }),

      it("before_all failure marks all tests SetupFailed", fn(_) {
        let suite =
          describe_with_hooks(
            "Suite",
            hooks(fn() { Error("Intentional before_all failure") }),
            [
              it("test one", fn(_) { Ok(AssertionOk) }),
              it("test two", fn(_) { Ok(AssertionOk) }),
            ],
          )

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        // Act
        let statuses = list.map(results, fn(r) { r.status })

        // Assert (one assertion)
        statuses
        |> should()
        |> equal([SetupFailed, SetupFailed])
        |> or_fail_with("Both tests should be SetupFailed")
      }),
    ]),

    group("hook execution order", [
      it("before_each runs outer-to-inner", fn(_) {
        let counter = start_counter()

        let suite =
          describe_with_hooks("Outer", hooks(fn() { Ok(counter) }), [
            // Outer hook: add 10
            before_each(fn(c) {
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              increment(c)
              Ok(c)
            }),
            group("Inner", [
              // Inner hook: add 1
              before_each(fn(c) {
                increment(c)
                Ok(c)
              }),
              it("test", fn(_c) { Ok(AssertionOk) }),
            ]),
          ])

        let _results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        get_count(counter)
        |> should()
        |> equal(11)
        |> or_fail_with("Hooks should run outer-to-inner")
      }),
    ]),

    group("combined hooks", [
      it("all hook types work together", fn(_) {
        let before_all_counter = start_counter()
        let before_each_counter = start_counter()
        let after_each_counter = start_counter()
        let after_all_counter = start_counter()

        let suite =
          describe_with_hooks(
            "Suite",
            hooks(fn() {
              increment(before_all_counter)
              Ok(before_each_counter)
            }),
            [
              before_each(fn(c) {
                increment(before_each_counter)
                Ok(c)
              }),
              after_each(fn(_c) {
                increment(after_each_counter)
                Ok(Nil)
              }),
              after_all(fn(_c) {
                increment(after_all_counter)
                Ok(Nil)
              }),
              it("test one", fn(_c) { Ok(AssertionOk) }),
              it("test two", fn(_c) { Ok(AssertionOk) }),
            ],
          )

        let results =
          runner.new([suite]) |> runner.max_concurrency(1) |> runner.run()

        // Act
        let statuses = list.map(results, fn(r) { r.status })
        let counts = [
          get_count(before_all_counter),
          get_count(before_each_counter),
          get_count(after_each_counter),
          get_count(after_all_counter),
        ]

        // Assert (one assertion)
        #(statuses, counts)
        |> should()
        |> equal(#([Passed, Passed], [1, 2, 2, 1]))
        |> or_fail_with("Expected passed tests and correct hook counts")
      }),
    ]),
  ])
}
