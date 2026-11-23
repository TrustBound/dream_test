import dream_test/gherkin/discover.{type FeatureDiscovery}

pub fn feature_files() -> FeatureDiscovery {
  discover.features("test/*.feature")
}
