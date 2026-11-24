import app/cart
import dream_test/coverage
import gleam/int
import gleam/io
import gleam/list

pub fn main() -> Nil {
  let config =
    coverage.new()
    |> coverage.lcov_path("build/coverage/servers/app.info")
  let assert Ok(session) = coverage.start(config)
  serve_requests([[10, 20], [5]])
  let assert Ok(_) = coverage.finish(session)
  Nil
}

fn serve_requests(requests: List(List(Int))) -> Nil {
  list.each(requests, fn(prices) {
    io.println("Cart total: " <> int.to_string(cart.total(prices)))
  })
}
