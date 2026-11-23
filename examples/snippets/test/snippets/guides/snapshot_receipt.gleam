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
