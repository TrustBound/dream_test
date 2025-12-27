//// Failure demo (moved to tests).
////
//// `dream_test` is a dev dependency in this example app, so `src/` modules
//// can’t import it. The intentional failure demo now lives in
//// `test/shopping_cart_test.gleam` behind an env var toggle:
////
////   touch test/DEMO_FAILURES && gleam test
////
//// This file is kept as a stub so older links don’t hard-error during builds.

pub fn main() {
  Nil
}
