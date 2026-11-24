import dream_test/sandbox.{type SandboxConfig}

pub fn debugging_config() -> SandboxConfig {
  sandbox.default_config() |> sandbox.with_crash_reports()
}
