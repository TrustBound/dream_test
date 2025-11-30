import dream_test/bootstrap/assertions_test
import dream_test/types_test
import dream_test/assertions/should_test
import dream_test/runner_test
import dream_test/unit_test

pub fn main() {
  assertions_test.main()
  types_test.main()
  should_test.main()
  runner_test.main()
  unit_test.main()
}
