//// Scenario state management for Gherkin tests.
////
//// Each scenario gets its own World instance for storing state between steps.
//// The World is automatically created before a scenario runs and cleaned up after.
////
//// ## How It Works
////
//// The World uses ETS (Erlang Term Storage) for mutable storage with process
//// isolation. Each scenario gets a unique table that's cleaned up automatically.
////
//// ## Example
////
//// ```gleam
//// import dream_test/gherkin/feature.{feature, given, scenario, then, when}
//// import dream_test/gherkin/steps.{type StepContext, get_float, step}
//// import dream_test/gherkin/world.{get_or, put}
//// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
//// import dream_test/reporters/bdd
//// import dream_test/reporters/progress
//// import dream_test/runner
//// import gleam/io
//// import gleam/result
////
//// // NOTE: We annotate `StepContext` because record field access needs a known type.
//// fn step_have_balance(context: StepContext) {
////   // {float} captures the numeric value (even with $ prefix)
////   let balance = get_float(context.captures, 0) |> result.unwrap(0.0)
////   put(context.world, "balance", balance)
////   Ok(succeed())
//// }
////
//// fn step_withdraw(context: StepContext) {
////   let current = get_or(context.world, "balance", 0.0)
////   let amount = get_float(context.captures, 0) |> result.unwrap(0.0)
////   put(context.world, "balance", current -. amount)
////   Ok(succeed())
//// }
////
//// fn step_balance_is(context: StepContext) {
////   let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
////   get_or(context.world, "balance", 0.0)
////   |> should
////   |> be_equal(expected)
////   |> or_fail_with("Balance mismatch")
//// }
////
//// pub fn register(registry) {
////   registry
////   |> step("I have a balance of ${float}", step_have_balance)
////   |> step("I withdraw ${float}", step_withdraw)
////   |> step("my balance should be ${float}", step_balance_is)
//// }
////
//// pub fn tests() {
////   let steps = steps.new() |> register()
////
////   feature("Bank Account", steps, [
////     scenario("Withdrawal", [
////       given("I have a balance of $100.00"),
////       when("I withdraw $30.00"),
////       then("my balance should be $70.00"),
////     ]),
////   ])
//// }
////
//// pub fn main() {
////   runner.new([tests()])
////   |> runner.progress_reporter(progress.new())
////   |> runner.results_reporters([bdd.new()])
////   |> runner.exit_on_failure()
////   |> runner.run()
//// }
//// ```

import gleam/option.{type Option, None, Some}

// ============================================================================
// Types
// ============================================================================

/// Opaque type representing scenario state.
///
/// Each scenario gets a unique World instance backed by an ETS table.
/// The World is created before the scenario runs and cleaned up after.
///
pub opaque type World {
  World(id: String, table: EtsTable)
}

/// Internal ETS table reference
type EtsTable

// ============================================================================
// World Lifecycle
// ============================================================================

/// Create a new World for a scenario.
///
/// Called automatically by the runner before each scenario.
/// Each World gets a unique ETS table for isolated storage.
///
/// ## Parameters
///
/// - `scenario_id`: Unique identifier for the scenario
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/world
///
/// pub fn main() {
///   // In normal gherkin runs, the runner creates and cleans up the World for you.
///   let w = world.new_world("example_scenario")
///   world.cleanup(w)
/// }
/// ```
///
pub fn new_world(scenario_id scenario_id: String) -> World {
  let table_name = "gherkin_world_" <> scenario_id <> "_" <> unique_id()
  let table = create_ets_table(table_name)
  World(id: scenario_id, table: table)
}

/// Clean up the World after a scenario completes.
///
/// Called automatically by the runner after each scenario.
/// Deletes the ETS table and frees resources.
///
/// ## Parameters
///
/// - `world`: The World to clean up
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/world
///
/// pub fn main() {
///   // In normal gherkin runs, the runner creates and cleans up the World for you.
///   let w = world.new_world("example_scenario")
///   world.cleanup(w)
/// }
/// ```
///
pub fn cleanup(world world: World) -> Nil {
  delete_ets_table(world.table)
}

// ============================================================================
// Storage Operations
// ============================================================================

/// Store a value in the World.
///
/// Stores any value by string key. If the key already exists,
/// the value is replaced.
///
/// ## Parameters
///
/// - `world`: The World to store in
/// - `key`: String key for the value
/// - `value`: Any value to store
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/feature.{feature, given, scenario, then, when}
/// import dream_test/gherkin/steps.{type StepContext, get_float, step}
/// import dream_test/gherkin/world.{get_or, put}
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import gleam/io
/// import gleam/result
///
/// // NOTE: We annotate `StepContext` because record field access needs a known type.
/// fn step_have_balance(context: StepContext) {
///   // {float} captures the numeric value (even with $ prefix)
///   let balance = get_float(context.captures, 0) |> result.unwrap(0.0)
///   put(context.world, "balance", balance)
///   Ok(succeed())
/// }
///
/// fn step_withdraw(context: StepContext) {
///   let current = get_or(context.world, "balance", 0.0)
///   let amount = get_float(context.captures, 0) |> result.unwrap(0.0)
///   put(context.world, "balance", current -. amount)
///   Ok(succeed())
/// }
///
/// fn step_balance_is(context: StepContext) {
///   let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
///   get_or(context.world, "balance", 0.0)
///   |> should
///   |> be_equal(expected)
///   |> or_fail_with("Balance mismatch")
/// }
///
/// pub fn register(registry) {
///   registry
///   |> step("I have a balance of ${float}", step_have_balance)
///   |> step("I withdraw ${float}", step_withdraw)
///   |> step("my balance should be ${float}", step_balance_is)
/// }
///
/// pub fn tests() {
///   let steps = steps.new() |> register()
///
///   feature("Bank Account", steps, [
///     scenario("Withdrawal", [
///       given("I have a balance of $100.00"),
///       when("I withdraw $30.00"),
///       then("my balance should be $70.00"),
///     ]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
pub fn put(world world: World, key key: String, value value: a) -> Nil {
  ets_insert(world.table, key, value)
}

/// Retrieve a value from the World.
///
/// Returns `Ok(value)` if the key exists, `Error(message)` if not found.
/// The caller is responsible for ensuring type consistency.
///
/// ## Parameters
///
/// - `world`: The World to query
/// - `key`: String key to look up
///
/// ## Returns
///
/// - `Ok(value)`: Key exists, returns the stored value
/// - `Error(String)`: Key doesn't exist (human-readable message)
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/feature.{feature, given, scenario, then}
/// import dream_test/gherkin/steps.{type StepContext, step}
/// import dream_test/gherkin/world.{get, put}
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import gleam/io
///
/// fn step_store(context: StepContext) {
///   put(context.world, "count", 42)
///   Ok(succeed())
/// }
///
/// fn step_count_is_42(context: StepContext) {
///   case get(context.world, "count") {
///     Ok(count) ->
///       count
///       |> should
///       |> be_equal(42)
///       |> or_fail_with("count mismatch")
///     Error(message) -> Error(message)
///   }
/// }
///
/// pub fn register(registry) {
///   registry
///   |> step("count is stored", step_store)
///   |> step("count should be 42", step_count_is_42)
/// }
///
/// pub fn tests() {
///   let steps = steps.new() |> register()
///
///   feature("World: get", steps, [
///     scenario("Reading a stored value", [
///       given("count is stored"),
///       then("count should be 42"),
///     ]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
pub fn get(world world: World, key key: String) -> Result(a, String) {
  case ets_lookup(world.table, key) {
    Some(value) -> Ok(value)
    None -> Error("World key not found: " <> key)
  }
}

/// Retrieve a value or return a default.
///
/// Convenience function that returns the stored value if the key exists,
/// or the provided default if not found.
///
/// ## Parameters
///
/// - `world`: The World to query
/// - `key`: String key to look up
/// - `default`: Default value to return if key not found
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/feature.{feature, given, scenario, then, when}
/// import dream_test/gherkin/steps.{type StepContext, get_float, step}
/// import dream_test/gherkin/world.{get_or, put}
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import gleam/io
/// import gleam/result
///
/// // NOTE: We annotate `StepContext` because record field access needs a known type.
/// fn step_have_balance(context: StepContext) {
///   // {float} captures the numeric value (even with $ prefix)
///   let balance = get_float(context.captures, 0) |> result.unwrap(0.0)
///   put(context.world, "balance", balance)
///   Ok(succeed())
/// }
///
/// fn step_withdraw(context: StepContext) {
///   let current = get_or(context.world, "balance", 0.0)
///   let amount = get_float(context.captures, 0) |> result.unwrap(0.0)
///   put(context.world, "balance", current -. amount)
///   Ok(succeed())
/// }
///
/// fn step_balance_is(context: StepContext) {
///   let expected = get_float(context.captures, 0) |> result.unwrap(0.0)
///   get_or(context.world, "balance", 0.0)
///   |> should
///   |> be_equal(expected)
///   |> or_fail_with("Balance mismatch")
/// }
///
/// pub fn register(registry) {
///   registry
///   |> step("I have a balance of ${float}", step_have_balance)
///   |> step("I withdraw ${float}", step_withdraw)
///   |> step("my balance should be ${float}", step_balance_is)
/// }
///
/// pub fn tests() {
///   let steps = steps.new() |> register()
///
///   feature("Bank Account", steps, [
///     scenario("Withdrawal", [
///       given("I have a balance of $100.00"),
///       when("I withdraw $30.00"),
///       then("my balance should be $70.00"),
///     ]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
pub fn get_or(world world: World, key key: String, default default: a) -> a {
  case get(world, key) {
    Ok(value) -> value
    Error(_) -> default
  }
}

/// Check if a key exists in the World.
///
/// Returns `True` if the key exists, `False` otherwise.
///
/// ## Parameters
///
/// - `world`: The World to query
/// - `key`: String key to check
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/feature.{feature, given, scenario, then, when}
/// import dream_test/gherkin/steps.{type StepContext, step}
/// import dream_test/gherkin/world.{delete, has, put}
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import gleam/io
///
/// fn step_store(context: StepContext) {
///   put(context.world, "temp", True)
///   Ok(succeed())
/// }
///
/// fn step_delete(context: StepContext) {
///   delete(context.world, "temp")
///   Ok(succeed())
/// }
///
/// fn step_is_absent(context: StepContext) {
///   has(context.world, "temp")
///   |> should
///   |> be_equal(False)
///   |> or_fail_with("expected temp to be absent")
/// }
///
/// pub fn register(registry) {
///   registry
///   |> step("temp is stored", step_store)
///   |> step("temp is deleted", step_delete)
///   |> step("temp should be absent", step_is_absent)
/// }
///
/// pub fn tests() {
///   let steps = steps.new() |> register()
///
///   feature("World: has + delete", steps, [
///     scenario("Deleting a key", [
///       given("temp is stored"),
///       when("temp is deleted"),
///       then("temp should be absent"),
///     ]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
pub fn has(world world: World, key key: String) -> Bool {
  case ets_lookup(world.table, key) {
    Some(_) -> True
    None -> False
  }
}

/// Delete a key from the World.
///
/// Removes a key-value pair. If the key doesn't exist, this is a no-op.
///
/// ## Parameters
///
/// - `world`: The World to modify
/// - `key`: String key to delete
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/feature.{feature, given, scenario, then, when}
/// import dream_test/gherkin/steps.{type StepContext, step}
/// import dream_test/gherkin/world.{delete, has, put}
/// import dream_test/matchers.{be_equal, or_fail_with, should, succeed}
/// import dream_test/reporters/bdd
/// import dream_test/reporters/progress
/// import dream_test/runner
/// import gleam/io
///
/// fn step_store(context: StepContext) {
///   put(context.world, "temp", True)
///   Ok(succeed())
/// }
///
/// fn step_delete(context: StepContext) {
///   delete(context.world, "temp")
///   Ok(succeed())
/// }
///
/// fn step_is_absent(context: StepContext) {
///   has(context.world, "temp")
///   |> should
///   |> be_equal(False)
///   |> or_fail_with("expected temp to be absent")
/// }
///
/// pub fn register(registry) {
///   registry
///   |> step("temp is stored", step_store)
///   |> step("temp is deleted", step_delete)
///   |> step("temp should be absent", step_is_absent)
/// }
///
/// pub fn tests() {
///   let steps = steps.new() |> register()
///
///   feature("World: has + delete", steps, [
///     scenario("Deleting a key", [
///       given("temp is stored"),
///       when("temp is deleted"),
///       then("temp should be absent"),
///     ]),
///   ])
/// }
///
/// pub fn main() {
///   runner.new([tests()])
///   |> runner.progress_reporter(progress.new())
///   |> runner.results_reporters([bdd.new()])
///   |> runner.exit_on_failure()
///   |> runner.run()
/// }
/// ```
///
pub fn delete(world world: World, key key: String) -> Nil {
  ets_delete(world.table, key)
}

/// Get the scenario ID for this World.
///
/// Useful for debugging and logging.
///
/// ## Parameters
///
/// - `world`: The World to query
///
/// ## Returns
///
/// The scenario ID string.
///
/// ## Example
///
/// ```gleam
/// import dream_test/gherkin/world
///
/// pub fn main() {
///   let w = world.new_world("example_scenario")
///   let id = world.scenario_id(w)
///   world.cleanup(w)
///   id
/// }
/// ```
///
pub fn scenario_id(world world: World) -> String {
  world.id
}

// ============================================================================
// ETS FFI
// ============================================================================

@external(erlang, "dream_test_gherkin_world_ffi", "create_table")
fn create_ets_table(name: String) -> EtsTable

@external(erlang, "dream_test_gherkin_world_ffi", "delete_table")
fn delete_ets_table(table: EtsTable) -> Nil

@external(erlang, "dream_test_gherkin_world_ffi", "insert")
fn ets_insert(table: EtsTable, key: String, value: a) -> Nil

@external(erlang, "dream_test_gherkin_world_ffi", "lookup")
fn ets_lookup(table: EtsTable, key: String) -> Option(a)

@external(erlang, "dream_test_gherkin_world_ffi", "delete_key")
fn ets_delete(table: EtsTable, key: String) -> Nil

@external(erlang, "dream_test_gherkin_world_ffi", "unique_id")
fn unique_id() -> String
