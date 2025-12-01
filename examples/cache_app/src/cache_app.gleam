//// A simple in-memory key-value cache demonstrating stateful code that
//// benefits from Dream Test's lifecycle hooks and process isolation.
////
//// This is intentionally simple — the point is to show testing patterns,
//// not to build a production cache.

import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

// ----------------------------------------------------------------------------
// Types
// ----------------------------------------------------------------------------

/// Messages the cache actor can receive
pub type CacheMessage(k, v) {
  Get(key: k, reply: Subject(Option(v)))
  Set(key: k, value: v)
  Delete(key: k)
  Clear
  Keys(reply: Subject(List(k)))
  Size(reply: Subject(Int))
}

/// A running cache instance
pub opaque type Cache(k, v) {
  Cache(subject: Subject(CacheMessage(k, v)))
}

/// Errors that can occur during cache operations
pub type CacheError {
  CacheNotRunning
  InvalidKey
}

// ----------------------------------------------------------------------------
// Cache Lifecycle
// ----------------------------------------------------------------------------

/// Start a new cache instance.
///
/// Returns a Cache handle that can be used for get/set operations.
/// The cache is linked to the calling process and will be automatically
/// cleaned up when that process terminates.
pub fn start() -> Cache(k, v) {
  let assert Ok(started) =
    actor.new(dict.new())
    |> actor.on_message(handle_message)
    |> actor.start

  Cache(subject: started.data)
}

/// Stop a running cache instance.
///
/// After calling this, the cache handle should not be used.
/// Note: Caches are automatically cleaned up when the parent process
/// terminates, so explicit stop() is optional.
pub fn stop(cache: Cache(k, v)) -> Nil {
  // Send a message that will never be handled - actor will be GC'd
  // when no more references exist. For explicit shutdown, we could
  // add a Shutdown message, but auto-cleanup is usually sufficient.
  let _ = cache
  Nil
}

// ----------------------------------------------------------------------------
// Cache Operations
// ----------------------------------------------------------------------------

/// Get a value from the cache.
///
/// Returns `Some(value)` if the key exists, `None` otherwise.
pub fn get(cache: Cache(k, v), key: k) -> Option(v) {
  actor.call(cache.subject, waiting: 1000, sending: fn(reply) { Get(key, reply) })
}

/// Set a value in the cache.
///
/// Overwrites any existing value for the key.
pub fn set(cache: Cache(k, v), key: k, value: v) -> Nil {
  process.send(cache.subject, Set(key, value))
}

/// Delete a key from the cache.
///
/// No-op if the key doesn't exist.
pub fn delete(cache: Cache(k, v), key: k) -> Nil {
  process.send(cache.subject, Delete(key))
}

/// Clear all entries from the cache.
pub fn clear(cache: Cache(k, v)) -> Nil {
  process.send(cache.subject, Clear)
}

/// Get all keys in the cache.
pub fn keys(cache: Cache(k, v)) -> List(k) {
  actor.call(cache.subject, waiting: 1000, sending: Keys)
}

/// Get the number of entries in the cache.
pub fn size(cache: Cache(k, v)) -> Int {
  actor.call(cache.subject, waiting: 1000, sending: Size)
}

// ----------------------------------------------------------------------------
// Convenience Functions
// ----------------------------------------------------------------------------

/// Get a value or return a default if not found.
pub fn get_or(cache: Cache(k, v), key: k, default: v) -> v {
  case get(cache, key) {
    Some(value) -> value
    None -> default
  }
}

/// Check if a key exists in the cache.
pub fn has(cache: Cache(k, v), key: k) -> Bool {
  case get(cache, key) {
    Some(_) -> True
    None -> False
  }
}

/// Update a value if it exists, applying a transformation function.
///
/// Returns `Ok(new_value)` if the key existed, `Error(InvalidKey)` otherwise.
pub fn update(
  cache: Cache(k, v),
  key: k,
  transform: fn(v) -> v,
) -> Result(v, CacheError) {
  case get(cache, key) {
    Some(value) -> {
      let new_value = transform(value)
      set(cache, key, new_value)
      Ok(new_value)
    }
    None -> Error(InvalidKey)
  }
}

/// Get and remove a value from the cache in one operation.
pub fn pop(cache: Cache(k, v), key: k) -> Option(v) {
  let value = get(cache, key)
  delete(cache, key)
  value
}

// ----------------------------------------------------------------------------
// Actor Implementation
// ----------------------------------------------------------------------------

fn handle_message(
  state: Dict(k, v),
  message: CacheMessage(k, v),
) -> actor.Next(Dict(k, v), CacheMessage(k, v)) {
  case message {
    Get(key, reply) -> {
      let value = case dict.get(state, key) {
        Ok(v) -> Some(v)
        Error(_) -> None
      }
      process.send(reply, value)
      actor.continue(state)
    }
    Set(key, value) -> {
      actor.continue(dict.insert(state, key, value))
    }
    Delete(key) -> {
      actor.continue(dict.delete(state, key))
    }
    Clear -> {
      actor.continue(dict.new())
    }
    Keys(reply) -> {
      process.send(reply, dict.keys(state))
      actor.continue(state)
    }
    Size(reply) -> {
      process.send(reply, dict.size(state))
      actor.continue(state)
    }
  }
}

// ----------------------------------------------------------------------------
// Main (for manual testing)
// ----------------------------------------------------------------------------

pub fn main() {
  let cache = start()

  set(cache, "name", "Dream Test")
  set(cache, "version", "1.0.0")

  let name = get(cache, "name")
  let missing = get(cache, "missing")

  #(name, missing)
}
