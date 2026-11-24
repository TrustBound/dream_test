import dream_test/coverage.{type CoverageError, type CoverageSession}

pub fn start_in_missing_directory() -> Result(CoverageSession, CoverageError) {
  coverage.new()
  |> coverage.source_directory("src/does_not_exist")
  |> coverage.start()
  // -> Error(SourceDirectoryNotFound("src/does_not_exist"))
}
