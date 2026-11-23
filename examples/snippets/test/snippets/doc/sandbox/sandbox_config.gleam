import dream_test/sandbox.{type SandboxConfig, SandboxConfig}

pub fn one_second_config() -> SandboxConfig {
  SandboxConfig(timeout_ms: 1000, show_crash_reports: False)
}
