import dream_test/file
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, it}
import dream_test/unit_context.{
  after_each, before_all, before_each, describe as ctx_describe, group,
  it as ctx_it,
}

pub fn tests() {
  describe("hook ordering", [
    it("runs before_each outer→inner and after_each inner→outer", fn() {
      let log_path = "test/fixtures/file/temp/hook_order/order.txt"

      let suite =
        ctx_describe("root", Nil, [
          before_all(fn(_ctx: Nil) { write_string(log_path, "") }),

          // Outer hooks
          before_each(fn(_ctx: Nil) { append_line(log_path, "outer_before\n") }),
          after_each(fn(_ctx: Nil) { append_line(log_path, "outer_after\n") }),

          group("inner", [
            // Inner hooks (declared in between; position shouldn't matter)
            after_each(fn(_ctx: Nil) { append_line(log_path, "inner_after\n") }),
            before_each(fn(_ctx: Nil) {
              append_line(log_path, "inner_before\n")
            }),

            ctx_it("passes", fn(_ctx: Nil) { Ok(AssertionOk) }),
          ]),
        ])

      let results = runner.new([suite]) |> runner.run()
      let assert [_r] = results

      file.read(log_path)
      |> should
      |> be_equal(Ok("outer_before\ninner_before\ninner_after\nouter_after\n"))
      |> or_fail_with("hook order should be deterministic")
    }),
  ])
}

fn append_line(path: String, line: String) -> Result(Nil, String) {
  case file.read(path) {
    Ok(existing) -> write_string(path, existing <> line)
    Error(e) -> Error(file.error_to_string(e))
  }
}

fn write_string(path: String, content: String) -> Result(Nil, String) {
  case file.write(path, content) {
    Ok(_) -> Ok(Nil)
    Error(e) -> Error(file.error_to_string(e))
  }
}
