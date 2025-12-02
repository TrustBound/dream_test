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
//// fn have_items(context: StepContext) -> AssertionResult {
////   case get_int(context.captures, 0) {
////     Ok(count) -> {
////       world.put(context.world, "cart_count", count)
////       AssertionOk
////     }
////     Error(msg) -> fail_with(msg)
////   }
//// }
////
//// fn check_total(context: StepContext) -> AssertionResult {
////   case world.get(context.world, "cart_count") {
////     Ok(count) -> {
////       count
////       |> should()
////       |> equal(expected)
////       |> or_fail_with("Cart count mismatch")
////     }
////     Error(_) -> fail_with("Cart not found in world")
////   }
//// }
//// ```
////
//// ## Type Safety
////
//// The World stores values dynamically. When retrieving values, you're
//// responsible for ensuring type consistency:
////
//// ```gleam
//// // Store an Int
//// world.put(world, "count", 42)
////
//// // Retrieve as Int - caller ensures type matches
//// case world.get(world, "count") {
////   Ok(count) -> use_count(count)  // count is inferred from usage
////   Error(_) -> handle_missing()
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
/// let world = new_world("shopping_cart::adding_items")
/// ```
///
pub fn new_world(scenario_id: String) -> World {
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
pub fn cleanup(world: World) -> Nil {
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
/// world.put(world, "user", User(name: "Alice", age: 30))
/// world.put(world, "count", 42)
/// world.put(world, "items", ["apple", "banana"])
/// ```
///
pub fn put(world: World, key: String, value: a) -> Nil {
  ets_insert(world.table, key, value)
}

/// Retrieve a value from the World.
///
/// Returns `Ok(value)` if the key exists, `Error(Nil)` if not found.
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
/// - `Error(Nil)`: Key doesn't exist
///
/// ## Example
///
/// ```gleam
/// case world.get(world, "user") {
///   Ok(user) -> process_user(user)
///   Error(_) -> handle_missing()
/// }
/// ```
///
pub fn get(world: World, key: String) -> Result(a, Nil) {
  case ets_lookup(world.table, key) {
    Some(value) -> Ok(value)
    None -> Error(Nil)
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
/// let count = world.get_or(world, "count", 0)
/// let items = world.get_or(world, "items", [])
/// ```
///
pub fn get_or(world: World, key: String, default: a) -> a {
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
/// case world.has(world, "user") {
///   True -> io.println("User exists")
///   False -> io.println("User not found")
/// }
/// ```
///
pub fn has(world: World, key: String) -> Bool {
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
/// world.delete(world, "temporary_data")
/// ```
///
pub fn delete(world: World, key: String) -> Nil {
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
pub fn scenario_id(world: World) -> String {
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
