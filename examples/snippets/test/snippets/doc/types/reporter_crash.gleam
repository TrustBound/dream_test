import dream_test/types

pub fn second_reporter_crash() -> types.ReporterCrash {
  types.ReporterCrash(position: 2, reason: "error:badarith")
}
