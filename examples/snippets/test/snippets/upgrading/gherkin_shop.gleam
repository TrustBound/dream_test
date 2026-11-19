import dream_test/gherkin/feature.{feature, given, scenario, then, when}
import dream_test/gherkin/steps.{
  type StepContext, type StepRegistry, get_int, get_string, get_word,
}
import dream_test/matchers.{be_equal, be_true, or_fail_with, should}
import gleam/dict.{type Dict}
import gleam/option
import gleam/result
import gleam/string

pub type Shop {
  Shop(cart: Dict(String, Int), last_error: String, order_id: String)
}

fn empty_shop() -> Shop {
  Shop(cart: dict.new(), last_error: "", order_id: "")
}

fn add_item(
  cart: Dict(String, Int),
  product: String,
  quantity: Int,
) -> Result(Dict(String, Int), String) {
  case quantity > 0 {
    True ->
      Ok(
        dict.upsert(cart, product, fn(current) {
          option.unwrap(current, 0) + quantity
        }),
      )
    False -> Error("invalid quantity")
  }
}

fn step_try_add_product(
  shop: Shop,
  context: StepContext,
) -> Result(Shop, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product <- result.try(get_word(context.captures, 1))

  case add_item(shop.cart, product, quantity) {
    Ok(updated) -> Ok(Shop(..shop, cart: updated, last_error: ""))
    Error(message) -> Ok(Shop(..shop, last_error: message))
  }
}

fn step_place_order(shop: Shop, context: StepContext) -> Result(Shop, String) {
  Ok(Shop(..shop, order_id: context.scenario_id))
}

pub fn register(registry: StepRegistry(Shop)) -> StepRegistry(Shop) {
  registry
  |> steps.given("I have an empty cart", step_empty_cart)
  |> steps.when("I add {int} {word} to the cart", step_add_product)
  |> steps.when("I try to add {int} {word} to the cart", step_try_add_product)
  |> steps.when("I place the order", step_place_order)
  |> steps.then("the cart has {int} {word}", step_cart_has)
  |> steps.then("the error is {string}", step_error_is)
  |> steps.then("the order id starts with {string}", step_order_id_starts)
}

fn step_empty_cart(_shop: Shop, _context: StepContext) -> Result(Shop, String) {
  Ok(empty_shop())
}

fn step_add_product(shop: Shop, context: StepContext) -> Result(Shop, String) {
  use quantity <- result.try(get_int(context.captures, 0))
  use product <- result.try(get_word(context.captures, 1))
  use updated <- result.try(add_item(shop.cart, product, quantity))
  Ok(Shop(..shop, cart: updated))
}

fn step_cart_has(shop: Shop, context: StepContext) {
  use expected <- result.try(get_int(context.captures, 0))
  use product <- result.try(get_word(context.captures, 1))
  dict.get(shop.cart, product)
  |> result.unwrap(0)
  |> should
  |> be_equal(expected)
  |> or_fail_with("wrong quantity of " <> product)
}

fn step_error_is(shop: Shop, context: StepContext) {
  use expected <- result.try(get_string(context.captures, 0))
  shop.last_error
  |> should
  |> be_equal(expected)
  |> or_fail_with("wrong error")
}

fn step_order_id_starts(shop: Shop, context: StepContext) {
  use prefix <- result.try(get_string(context.captures, 0))
  string.starts_with(shop.order_id, prefix)
  |> should
  |> be_true()
  |> or_fail_with("the order id should start with " <> prefix)
}

pub fn tests() {
  let steps = steps.new(initial: empty_shop()) |> register

  feature("Shop", steps, [
    scenario("Adding apples", [
      given("I have an empty cart"),
      when("I add 2 apples to the cart"),
      when("I add 3 apples to the cart"),
      then("the cart has 5 apples"),
    ]),
    scenario("Adding no apples", [
      given("I have an empty cart"),
      when("I try to add 0 apples to the cart"),
      then("the error is \"invalid quantity\""),
      then("the cart has 0 apples"),
    ]),
    scenario("Placing an order", [
      given("I have an empty cart"),
      when("I add 1 apples to the cart"),
      when("I place the order"),
      then("the order id starts with \"Shop::Placing an order#\""),
    ]),
  ])
}
