import dream_test/reporters/hook_failures
import dream_test/types.{type RunReport}

pub fn hook_failure_section(report: RunReport) -> String {
  hook_failures.format(types.report_hook_failures(report))
  // -> "Setup and teardown failures:\n  after_all in Database\n    could not drop the schema\n"
}
