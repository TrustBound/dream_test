import dream_test/gherkin/parser
import dream_test/gherkin/types.{type Feature}

pub fn cart_feature() -> Feature {
  let assert Ok(feature) = parser.parse_file("test/cart.feature")
  feature
}
