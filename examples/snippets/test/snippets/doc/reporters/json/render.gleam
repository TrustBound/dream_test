import dream_test/reporters/json
import dream_test/reporters/types as reporter_types
import dream_test/types.{type RunReport}

pub fn render_compact_json(report: RunReport) -> String {
  json.render(
    config: reporter_types.JsonReporterConfig(pretty: False),
    report: report,
  )
}
