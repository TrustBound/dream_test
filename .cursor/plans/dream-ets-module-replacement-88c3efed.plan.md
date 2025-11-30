<!-- 88c3efed-c9b2-49db-80d5-84908928f01a 2abd4bf0-1470-40b4-b3c6-229e78297489 -->
# Create dream_ets Module - Dream Quality Standards

## Overview

Build a comprehensive ETS (Erlang Term Storage) wrapper module `dream_ets` that exemplifies Dream's quality standards. This module will serve as a reference implementation demonstrating how to build high-quality Dream modules.

## Dream Quality Standards (MANDATORY)

### Code Quality

1. **No Anonymous Functions** - All functions must be explicitly named. No `fn()` closures in public API.
2. **No Nested Cases** - Each case statement must be in a separate named function. Complex logic split into helper functions.
3. **Builder Pattern** - Mandatory for all table creation. Consistent with `dream_postgres`, `dream_http_client`.
4. **Type Safety First** - Leverage Gleam's type system fully. Make invalid states unrepresentable.
5. **Explicit Over Implicit** - No magic, no hidden behavior. Everything visible in code.
6. **No Closures** - All dependencies explicit in function signatures.

### Testing Standards

1. **100% Test Coverage** - Every public function must have tests.
2. **Black Box Testing** - Test public interfaces only, not implementation details.
3. **AAA Pattern** - Arrange, Act, Assert with blank lines between sections.
4. **Test Naming** - `<function>_<condition>_<result>_test()`
5. **No External Dependencies** - Tests must be isolated, fast, deterministic.
6. **Edge Cases** - Test error paths, boundary conditions, invalid inputs.

### Documentation Standards

1. **All Public Functions Documented** - Every public function has doc comments.
2. **Examples Required** - All documentation includes usage examples with imports.
3. **Builder Pattern Examples** - All examples show builder usage prominently.
4. **Clear and Concise** - Documentation explains what, why, and how.

### Code Organization

1. **Small, Focused Functions** - Each function does one thing well.
2. **Composability** - Functions work together, can be used independently.
3. **Consistent Naming** - Follow `{verb}_{noun}` pattern, no module prefixes.
4. **Simple Over Clever** - Code should be obvious, not clever.

## Phase 1: Module Structure Setup

### 1.1 Create Module Directory Structure

**Location:** `modules/ets/`

**Files to create:**

- `gleam.toml` - Package configuration
- `manifest.toml` - Manifest file (auto-generated)
- `Makefile` - Build/test commands (mirror other modules)
- `README.md` - Comprehensive documentation emphasizing quality standards
- `src/dream_ets/` - Source directory
  - `config.gleam` - Builder configuration (MANDATORY builder pattern)
  - `table.gleam` - Table type and core operations
  - `operations.gleam` - All ETS operations (no nested cases)
  - `encoders.gleam` - Built-in encoders/decoders (all named functions)
  - `helpers.gleam` - Convenience helpers (use builder internally)
  - `internal.gleam` - Internal FFI wrappers (no public API)
  - `internal_ffi.erl` - Erlang FFI (pure wrappers, no logic)
- `test/dream_ets_test.gleam` - Test entry point
  - `config_test.gleam` - Builder pattern tests (AAA pattern)
  - `table_test.gleam` - Table operations tests
  - `operations_test.gleam` - Advanced operations tests
  - `encoders_test.gleam` - Encoder/decoder tests
  - `helpers_test.gleam` - Helper function tests

### 1.2 Dependencies

**gleam.toml:**

```toml
name = "dream_ets"
version = "0.1.0"

[dependencies]
gleam_stdlib = ">= 0.44.0"
gleam_erlang = ">= 1.0.0"
gleam_json = ">= 2.2.0"
gleam_dynamic = ">= 1.0.0"

[dev-dependencies]
gleeunit = ">= 1.0.0"
```

## Phase 2: Core Implementation (Following Quality Standards)

### 2.1 FFI Layer (`internal_ffi.erl`)

**Quality Standard: Pure wrappers, no logic**

All FFI functions are direct Erlang ETS calls with no business logic:

- `ets_new/2` - Create table with options
- `ets_insert/2` - Insert objects
- `ets_lookup/2` - Lookup by key
- `ets_delete/2` - Delete table
- `ets_delete_object/2` - Delete specific object
- `ets_delete_all_objects/1` - Clear table
- `ets_first/1` - Get first key
- `ets_next/2` - Get next key
- `ets_match/2` - Pattern matching
- `ets_match_object/2` - Match objects
- `ets_select/2` - Select with match spec
- `ets_tab2file/2` - Save to file
- `ets_file2tab/1` - Load from file
- `ets_info/1` - Get table info
- `ets_update_element/3` - Update element in tuple
- `ets_insert_new/2` - Insert only if new
- `ets_take/2` - Lookup and delete
- `ets_member/2` - Check membership

**Quality Check:** Each function is a single Erlang call, no conditional logic.

### 2.2 Builder Configuration (`config.gleam`)

**Quality Standards:**

- Builder pattern MANDATORY (no direct table creation)
- All functions explicitly named
- No nested cases
- Type-safe at each step

**Type:**

```gleam
pub opaque type TableConfig(k, v) {
  TableConfig(
    name: String,
    table_type: TableType,
    access: Access,
    keypos: Int,
    read_concurrency: Bool,
    write_concurrency: Bool,
    compressed: Bool,
    named_table: Bool,
    key_encoder: Option(fn(k) -> Dynamic),
    key_decoder: Option(Decoder(k)),
    value_encoder: Option(fn(v) -> Dynamic),
    value_decoder: Option(Decoder(v)),
  )
}

pub type TableType {
  Set
  OrderedSet
  Bag
  DuplicateBag
}

pub type Access {
  Public
  Protected
  Private
}
```

**Builder Functions (All Named, No Nesting):**

- `new(name: String) -> TableConfig(k, v)` - Start builder with defaults
- `table_type(config, type_) -> TableConfig` - Set table type
- `access(config, access) -> TableConfig` - Set access mode
- `keypos(config, pos) -> TableConfig` - Set key position
- `read_concurrency(config, enabled) -> TableConfig` - Enable concurrent reads
- `write_concurrency(config, enabled) -> TableConfig` - Enable concurrent writes
- `compressed(config, enabled) -> TableConfig` - Compress table data
- `key(config, encoder, decoder) -> TableConfig` - Set key encoding
- `value(config, encoder, decoder) -> TableConfig` - Set value encoding
- `key_string(config) -> TableConfig(String, v)` - Convenience for string keys
- `value_string(config) -> TableConfig(k, String)` - Convenience for string values
- `value_json(config, to_json, decoder) -> TableConfig` - JSON serialization
- `counter(config) -> TableConfig(String, Int)` - Counter table shortcut
- `create(config) -> Result(Table(k, v), EtsError)` - Create table

**Quality Check:** Each function is a single flat update, no nested cases or conditionals.

**Example Usage (All Documentation Must Show This):**

```gleam
// Simple table with defaults
let assert Ok(table) = ets.new("my_table")
  |> ets.create()

// Configured table
let assert Ok(table) = ets.new("sessions")
  |> ets.key_string()
  |> ets.value_json(session.to_json, session.decoder())
  |> ets.read_concurrency(True)
  |> ets.create()
```

### 2.3 Table Type (`table.gleam`)

**Quality Standards:**

- Opaque type hiding implementation
- Encapsulates encoding/decoding
- Type-safe operations

**Type:**

```gleam
pub opaque type Table(k, v) {
  Table(
    table_ref: EtsTableRef,
    name: String,
    key_encoder: fn(k) -> Dynamic,
    key_decoder: Decoder(k),
    value_encoder: fn(v) -> Dynamic,
    value_decoder: Decoder(v),
  )
}

pub type EtsError {
  TableNotFound
  TableAlreadyExists
  InvalidKey
  InvalidValue
  DecodeError(dynamic.DecodeError)
  EncodeError(String)
  OperationFailed(String)
}
```

### 2.4 Core Operations (`operations.gleam`)

**Quality Standards:**

- No nested cases - each operation is a separate named function
- Encoding/decoding in separate helper functions
- Explicit error handling

**Pattern for All Operations:**

1. Encode key/value (separate helper function)
2. Call FFI (separate helper function)
3. Decode result (separate helper function)
4. Return Result

**Basic Operations:**

- `set(table, key, value) -> Result(Nil, EtsError)` - Insert/update
- `get(table, key) -> Result(Option(v), EtsError)` - Lookup
- `delete(table, key) -> Result(Nil, EtsError)` - Delete key
- `member(table, key) -> Bool` - Check membership
- `delete_table(table) -> Result(Nil, EtsError)` - Delete entire table
- `size(table) -> Int` - Get table size
- `keys(table) -> List(k)` - Get all keys
- `values(table) -> List(v)` - Get all values
- `to_list(table) -> List(#(k, v))` - Convert to list

**Advanced Operations:**

- `insert_new(table, key, value) -> Result(Bool, EtsError)` - Insert only if new
- `take(table, key) -> Result(Option(v), EtsError)` - Lookup and delete
- `update_element(table, key, pos, value) -> Result(Nil, EtsError)` - Update tuple element
- `delete_all_objects(table) -> Result(Nil, EtsError)` - Clear table
- `match(table, pattern) -> List(v)` - Pattern matching
- `select(table, match_spec) -> List(v)` - Select with match spec

**Quality Check:** Each function calls named helpers for encoding/decoding, no inline logic.

### 2.5 Encoders (`encoders.gleam`)

**Quality Standards:**

- All functions explicitly named
- No anonymous functions
- Each encoder/decoder is a separate function

**Built-in Encoders/Decoders:**

- `string_encoder(s: String) -> Dynamic`
- `string_decoder() -> Decoder(String)`
- `int_encoder(i: Int) -> Dynamic`
- `int_decoder() -> Decoder(Int)`
- `bool_encoder(b: Bool) -> Dynamic`
- `bool_decoder() -> Decoder(Bool)`
- `float_encoder(f: Float) -> Dynamic`
- `float_decoder() -> Decoder(Float)`
- `json_encoder(to_json: fn(v) -> json.Json) -> fn(v) -> Dynamic` - Returns named function
- `json_decoder(decoder: Decoder(v)) -> Decoder(v)`

**Quality Check:** No closures in public API. `json_encoder` returns a function, but it's a named return type.

### 2.6 Helpers (`helpers.gleam`)

**Quality Standards:**

- All convenience functions MUST use builder internally
- No direct table creation bypassing builder
- Explicit function names

**Convenience Functions:**

- `new_counter(name: String) -> Result(Table(String, Int), EtsError)` - Uses builder internally
- `new_string_table(name: String) -> Result(Table(String, String), EtsError)` - Uses builder internally

**Counter Operations:**

- `increment(table, key) -> Result(Int, EtsError)` - Atomic increment
- `increment_by(table, key, amount) -> Result(Int, EtsError)` - Increment by amount
- `decrement(table, key) -> Result(Int, EtsError)` - Atomic decrement
- `decrement_by(table, key, amount) -> Result(Int, EtsError)` - Decrement by amount

**Quality Check:** `new_counter()` implementation must show builder usage:

```gleam
pub fn new_counter(name: String) -> Result(Table(String, Int), EtsError) {
  new(name)
  |> counter()
  |> create()
}
```

## Phase 3: Comprehensive Testing (Following Testing Standards)

### 3.1 Test Structure

**Testing Standards:**

- **100% Coverage** - Every public function tested
- **Black Box** - Test public interfaces only
- **AAA Pattern** - Arrange, Act, Assert with blank lines
- **Test Naming** - `<function>_<condition>_<result>_test()`
- **No External Dependencies** - Isolated, fast, deterministic

### 3.2 Test Files

**config_test.gleam - Builder Pattern Tests:**

- `new_with_name_creates_config_with_defaults_test()`
- `table_type_sets_table_type_test()`
- `access_sets_access_mode_test()`
- `read_concurrency_enables_read_concurrency_test()`
- `write_concurrency_enables_write_concurrency_test()`
- `compressed_enables_compression_test()`
- `key_string_sets_string_key_encoding_test()`
- `value_string_sets_string_value_encoding_test()`
- `counter_creates_counter_config_test()`
- `create_with_valid_config_returns_table_test()`
- `create_with_duplicate_name_returns_error_test()`
- `builder_pattern_allows_chaining_test()`

**table_test.gleam - Basic Operations:**

- `set_with_valid_key_value_stores_value_test()`
- `set_with_existing_key_updates_value_test()`
- `get_with_existing_key_returns_value_test()`
- `get_with_nonexistent_key_returns_none_test()`
- `delete_with_existing_key_removes_key_test()`
- `delete_with_nonexistent_key_returns_error_test()`
- `member_with_existing_key_returns_true_test()`
- `member_with_nonexistent_key_returns_false_test()`
- `size_with_empty_table_returns_zero_test()`
- `size_with_three_items_returns_three_test()`
- `keys_with_empty_table_returns_empty_list_test()`
- `keys_with_items_returns_all_keys_test()`
- `values_with_empty_table_returns_empty_list_test()`
- `values_with_items_returns_all_values_test()`
- `to_list_with_empty_table_returns_empty_list_test()`
- `to_list_with_items_returns_all_pairs_test()`

**operations_test.gleam - Advanced Operations:**

- `insert_new_with_new_key_returns_true_test()`
- `insert_new_with_existing_key_returns_false_test()`
- `take_with_existing_key_returns_value_and_deletes_test()`
- `take_with_nonexistent_key_returns_none_test()`
- `update_element_updates_tuple_element_test()`
- `update_element_with_invalid_position_returns_error_test()`
- `delete_all_objects_clears_table_test()`
- `match_with_pattern_returns_matching_objects_test()`
- `match_with_no_matches_returns_empty_list_test()`
- `select_with_match_spec_returns_matching_objects_test()`

**encoders_test.gleam - Encoder/Decoder Tests:**

- `string_encoder_encodes_string_test()`
- `string_decoder_decodes_string_test()`
- `string_decoder_with_invalid_input_returns_error_test()`
- `int_encoder_encodes_int_test()`
- `int_decoder_decodes_int_test()`
- `int_decoder_with_invalid_input_returns_error_test()`
- `bool_encoder_encodes_bool_test()`
- `bool_decoder_decodes_bool_test()`
- `float_encoder_encodes_float_test()`
- `float_decoder_decodes_float_test()`
- `json_encoder_encodes_json_test()`
- `json_decoder_decodes_json_test()`
- `json_decoder_with_invalid_json_returns_error_test()`

**helpers_test.gleam - Helper Functions:**

- `new_counter_creates_counter_table_test()`
- `new_counter_uses_builder_internally_test()` - Verify builder usage
- `new_string_table_creates_string_table_test()`
- `new_string_table_uses_builder_internally_test()` - Verify builder usage
- `increment_with_new_key_sets_to_one_test()`
- `increment_with_existing_key_increments_value_test()`
- `increment_by_with_amount_adds_amount_test()`
- `increment_by_with_new_key_sets_to_amount_test()`
- `decrement_with_existing_key_decrements_value_test()`
- `decrement_with_new_key_sets_to_negative_one_test()`
- `decrement_by_with_amount_subtracts_amount_test()`

**Table Type Tests:**

- `set_table_stores_unique_keys_test()`
- `set_table_replaces_existing_key_test()`
- `ordered_set_table_maintains_order_test()`
- `bag_table_allows_duplicate_keys_test()`
- `bag_table_rejects_duplicate_objects_test()`
- `duplicate_bag_table_allows_duplicate_objects_test()`
- `public_table_allows_external_access_test()`
- `protected_table_allows_external_reads_test()`
- `protected_table_restricts_external_writes_test()`
- `private_table_restricts_external_access_test()`

**Error Handling Tests:**

- `get_with_invalid_key_returns_error_test()`
- `set_with_invalid_value_returns_error_test()`
- `delete_table_with_nonexistent_table_returns_error_test()`
- `decode_error_returns_decode_error_test()`
- `encode_error_returns_encode_error_test()`

**Concurrency Tests:**

- `multiple_processes_can_read_concurrently_test()`
- `read_concurrency_enables_concurrent_reads_test()`
- `write_concurrency_enables_concurrent_writes_test()`

**Quality Check:** Every test follows AAA pattern with blank lines. All test names follow convention.

## Phase 4: Documentation (Following Documentation Standards)

### 4.1 Module README

**File:** `modules/ets/README.md`

**Must Include:**

- Overview of ETS and why it's useful
- **Builder pattern examples (PRIMARY focus)** - Show builder usage prominently
- Type safety with encoders/decoders
- All table types explained with examples
- Common use cases (rate limiting, caching, sessions) with builder examples
- Complete API reference
- **Emphasize: Builder pattern is the only way to create tables**
- Quality standards section explaining code organization

### 4.2 Code Documentation

**Every Public Function Must Have:**

- Brief description
- Example usage with imports
- Builder pattern examples where applicable
- Important notes or caveats

**Example:**

````gleam
/// Creates a new ETS table configuration with sensible defaults.
///
/// The builder pattern is mandatory for table creation. Start with `new()`,
/// configure options, then call `create()` to finalize.
///
/// ## Example
///
/// ```gleam
/// import dream_ets as ets
///
/// // Simple table with defaults
/// let assert Ok(table) = ets.new("my_table")
///   |> ets.create()
///
/// // Configured table
/// let assert Ok(table) = ets.new("sessions")
///   |> ets.key_string()
///   |> ets.value_json(session.to_json, session.decoder())
///   |> ets.read_concurrency(True)
///   |> ets.create()
/// ```
pub fn new(name: String) -> TableConfig(k, v) {
  // Implementation
}
````

## Phase 5: Quality Assurance

### 5.1 Code Review Checklist

**Code Quality:**

- [ ] No anonymous functions in public API
- [ ] No nested cases - all split into named functions
- [ ] Builder pattern used for all table creation
- [ ] All functions explicitly named
- [ ] Type-safe throughout
- [ ] No magic, everything explicit

**Testing:**

- [ ] 100% test coverage of public functions
- [ ] All tests follow AAA pattern
- [ ] All test names follow convention
- [ ] Edge cases covered
- [ ] Error paths tested
- [ ] No external dependencies in tests

**Documentation:**

- [ ] All public functions documented
- [ ] All examples show builder pattern
- [ ] README comprehensive
- [ ] Code examples compile and run

**Consistency:**

- [ ] Follows naming conventions
- [ ] Consistent with other Dream modules
- [ ] Code formatted (`gleam format`)
- [ ] No linter errors

### 5.2 Final Verification

**Before Completion:**

1. Run `gleam check` - No type errors
2. Run `gleam test` - All tests pass
3. Run `gleam format --check` - Code formatted
4. Review all public functions for documentation
5. Verify builder pattern in all examples
6. Check for anonymous functions
7. Check for nested cases
8. Verify test coverage

## Success Criteria

1. ✅ Module created following all Dream quality standards
2. ✅ Builder pattern mandatory - all table creation uses builder
3. ✅ No anonymous functions in public API
4. ✅ No nested cases - all logic in named functions
5. ✅ 100% test coverage of public functions
6. ✅ All tests follow AAA pattern and naming convention
7. ✅ Comprehensive documentation with builder examples
8. ✅ Type-safe throughout
9. ✅ Explicit over implicit - no magic
10. ✅ Consistent with other Dream modules
11. ✅ Code formatted and linted
12. ✅ All quality checks pass

## Files to Create

**Create:**

- `modules/ets/gleam.toml`
- `modules/ets/manifest.toml` (auto-generated)
- `modules/ets/Makefile`
- `modules/ets/README.md`
- `modules/ets/src/dream_ets/config.gleam`
- `modules/ets/src/dream_ets/table.gleam`
- `modules/ets/src/dream_ets/operations.gleam`
- `modules/ets/src/dream_ets/encoders.gleam`
- `modules/ets/src/dream_ets/helpers.gleam`
- `modules/ets/src/dream_ets/internal.gleam`
- `modules/ets/src/dream_ets/internal_ffi.erl`
- `modules/ets/test/dream_ets_test.gleam`
- `modules/ets/test/config_test.gleam`
- `modules/ets/test/table_test.gleam`
- `modules/ets/test/operations_test.gleam`
- `modules/ets/test/encoders_test.gleam`
- `modules/ets/test/helpers_test.gleam`

**No modifications to examples** - Focus solely on creating a high-quality module that exemplifies Dream's standards.

### To-dos

- [ ] Create modules/ets/ directory with gleam.toml, Makefile, README.md, manifest.toml, src/, and test/ directories
- [ ] Implement core types: Table, TableConfig, TableType, Access, EtsError in src/dream_ets.gleam
- [ ] Implement builder pattern functions: new(), table_type(), access(), read_concurrency(), write_concurrency(), compressed(), create()
- [ ] Implement convenience helpers: encoders/decoders for primitives, json_encoder/decoder, key_string(), counter(), value_json()
- [ ] Implement table operations: set(), get(), delete(), member(), keys(), values(), to_list(), size(), delete_table()
- [ ] Implement counter operations: increment(), increment_by(), decrement()
- [ ] Write builder tests in test/builder_test.gleam (~10 tests)
- [ ] Write table operations tests in test/table_operations_test.gleam (~12 tests)
- [ ] Write counter tests in test/counter_test.gleam (~6 tests)
- [ ] Write type safety tests in test/type_safety_test.gleam (~7 tests)
- [ ] Write error handling tests in test/error_handling_test.gleam (~5 tests)
- [ ] Write concurrency tests in test/concurrency_test.gleam (~3 tests)
- [ ] Rewrite examples/singleton/src/services/rate_limiter_service.gleam to use dream_ets
- [ ] Update examples/singleton/src/services.gleam to use new rate limiter API
- [ ] Update examples/singleton/src/middleware/rate_limit_middleware.gleam
- [ ] Update examples/singleton/gleam.toml to use dream_ets instead of dream_singleton
- [ ] Run and test the rate limiter example end-to-end
- [ ] Delete modules/singleton/ directory
- [ ] Remove dream_singleton from examples/cms/gleam.toml
- [ ] Update MODULAR_ARCHITECTURE.md to reference dream_ets instead of dream_singleton
- [ ] Write comprehensive README.md for modules/ets/ with examples and decision guides
- [ ] Rename examples/singleton/ to examples/rate_limiter/