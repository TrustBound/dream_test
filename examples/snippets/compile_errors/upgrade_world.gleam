//// 2.x step code that 3.0.0 does not compile: the `world` module is
//// removed. The upgrade guide shows the compiler error, and the test in
//// `snippets/guides/upgrading_tests.gleam` compiles this file and checks it.

import dream_test/gherkin/steps.{type StepContext}
import dream_test/gherkin/world.{put}

pub fn step_have_items(context: StepContext) {
  put(context.world, "cart", 3)
  Ok(Nil)
}
