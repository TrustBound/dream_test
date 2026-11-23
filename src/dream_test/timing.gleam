//// Human-readable duration formatting for test timing.
////
//// Provides utilities for measuring and displaying test execution times
//// in a human-friendly format that scales appropriately.
////
//// ## Duration Scaling
////
//// | Duration          | Display Format |
//// |-------------------|----------------|
//// | < 1ms             | `0.42ms`       |
//// | 1ms - 999ms       | `42ms`         |
//// | 1s - 59s          | `1.2s`         |
//// | 1m - 59m          | `2m 30s`       |
//// | >= 1h             | `1h 15m`       |
////
//// ## Example
////
//// ### Format one and a half seconds <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/timing/module.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream_test/matchers.{be_equal, or_fail_with, should}
//// import dream_test/timing
//// import dream_test/types.{type AssertionResult}
////
//// pub fn formats_one_and_a_half_seconds() -> Result(AssertionResult, String) {
////   timing.format_duration_ms(1500)
////   |> should
////   |> be_equal("1.5s")
////   |> or_fail_with("expected 1.5s")
//// }
//// ```

import gleam/float
import gleam/int

// ============================================================================
// Public API
// ============================================================================

/// Format a duration in milliseconds as a human-readable string.
///
/// Automatically scales to the most appropriate unit:
/// - Milliseconds for durations under 1 second
/// - Seconds (with decimal) for durations under 1 minute
/// - Minutes and seconds for durations under 1 hour
/// - Hours and minutes for longer durations
///
/// ## Example
///
/// ### Format a duration in milliseconds <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/timing/format_duration_ms.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/timing
/// import dream_test/types.{type AssertionResult}
///
/// pub fn formats_forty_two_milliseconds() -> Result(AssertionResult, String) {
///   // Arrange & Act
///   let formatted = timing.format_duration_ms(42)
///
///   // Assert
///   formatted
///   |> should
///   |> be_equal("42ms")
///   |> or_fail_with("expected 42ms")
/// }
/// ```
///
/// ## Parameters
///
/// - `duration_ms`: Duration in milliseconds
///
/// ## Returns
///
/// A human-readable duration string (for example `"42ms"` or `"1.5s"`).
///
pub fn format_duration_ms(duration_ms duration_ms: Int) -> String {
  case duration_ms {
    // Zero or negative
    ms if ms <= 0 -> "0ms"

    // Under 1 second: show milliseconds
    ms if ms < 1000 -> int.to_string(ms) <> "ms"

    // Under 1 minute: show seconds with one decimal
    ms if ms < 60_000 -> format_seconds(ms)

    // Under 1 hour: show minutes and seconds
    ms if ms < 3_600_000 -> format_minutes_seconds(ms)

    // 1 hour or more: show hours and minutes
    ms -> format_hours_minutes(ms)
  }
}

/// Format a duration in microseconds as a human-readable string.
///
/// Similar to `format_duration_ms` but accepts microseconds.
/// Useful when working with high-precision timing.
///
/// ## Examples
///
/// ### Format a duration in microseconds <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/timing/format_duration_us.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/timing
/// import dream_test/types.{type AssertionResult}
///
/// pub fn formats_half_a_millisecond() -> Result(AssertionResult, String) {
///   timing.format_duration_us(500)
///   |> should
///   |> be_equal("0.5ms")
///   |> or_fail_with("expected 0.5ms")
/// }
/// ```
///
/// ## Parameters
///
/// - `duration_us`: Duration in microseconds
///
/// ## Returns
///
/// A human-readable duration string (for example `"0.5ms"` or `"42ms"`).
/// A negative duration gives `"0.0ms"`, the same as `0`.
pub fn format_duration_us(duration_us duration_us: Int) -> String {
  case duration_us {
    // Negative: show zero, as for 0
    us if us < 0 -> "0.0ms"

    // Under 1ms: show fractional milliseconds
    us if us < 1000 -> format_sub_millisecond(us)

    // 1ms or more: convert to ms and use standard formatting
    us -> format_duration_ms(us / 1000)
  }
}

/// Get the current monotonic time in milliseconds.
///
/// Use this to measure elapsed time between two points.
/// Monotonic time is not affected by system clock changes.
///
/// ## Example
///
/// ### Read the monotonic clock in milliseconds <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/timing/now_ms.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/timing
/// import dream_test/types.{type AssertionResult}
///
/// pub fn now_ms_never_goes_back() -> Result(AssertionResult, String) {
///   let first = timing.now_ms()
///   let second = timing.now_ms()
///   let is_monotonic = second >= first
///
///   is_monotonic
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("expected now_ms to be monotonic")
/// }
/// ```
///
/// ## Returns
///
/// A monotonic timestamp in milliseconds.
pub fn now_ms() -> Int {
  erlang_monotonic_time_ms()
}

/// Get the current monotonic time in microseconds.
///
/// Higher precision version of `now_ms()` for sub-millisecond timing.
///
/// ## Example
///
/// ### Read the monotonic clock in microseconds <a href="https://github.com/TrustBound/dream_test/blob/3.0.0/examples/snippets/test/snippets/doc/timing/now_us.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream_test/matchers.{be_equal, or_fail_with, should}
/// import dream_test/timing
/// import dream_test/types.{type AssertionResult}
///
/// pub fn now_us_never_goes_back() -> Result(AssertionResult, String) {
///   let first = timing.now_us()
///   let second = timing.now_us()
///   let is_monotonic = second >= first
///
///   is_monotonic
///   |> should
///   |> be_equal(True)
///   |> or_fail_with("expected now_us to be monotonic")
/// }
/// ```
///
/// ## Returns
///
/// A monotonic timestamp in microseconds.
pub fn now_us() -> Int {
  erlang_monotonic_time_us()
}

// ============================================================================
// Internal Helpers
// ============================================================================

fn format_sub_millisecond(us: Int) -> String {
  let ms_float = int.to_float(us) /. 1000.0
  format_float_one_decimal(ms_float) <> "ms"
}

fn format_seconds(ms: Int) -> String {
  let seconds_float = int.to_float(ms) /. 1000.0
  format_float_one_decimal(seconds_float) <> "s"
}

fn format_minutes_seconds(ms: Int) -> String {
  let total_seconds = ms / 1000
  let minutes = total_seconds / 60
  let seconds = total_seconds % 60

  case seconds {
    0 -> int.to_string(minutes) <> "m"
    s -> int.to_string(minutes) <> "m " <> int.to_string(s) <> "s"
  }
}

fn format_hours_minutes(ms: Int) -> String {
  let total_minutes = ms / 60_000
  let hours = total_minutes / 60
  let minutes = total_minutes % 60

  case minutes {
    0 -> int.to_string(hours) <> "h"
    m -> int.to_string(hours) <> "h " <> int.to_string(m) <> "m"
  }
}

/// The value with one decimal place, rounded. The callers never pass a
/// negative value.
fn format_float_one_decimal(value: Float) -> String {
  let tenths = float.round(value *. 10.0)
  int.to_string(tenths / 10) <> "." <> int.to_string(tenths % 10)
}

// ============================================================================
// FFI
// ============================================================================

@external(erlang, "dream_test_timing_ffi", "monotonic_time_ms")
fn erlang_monotonic_time_ms() -> Int

@external(erlang, "dream_test_timing_ffi", "monotonic_time_us")
fn erlang_monotonic_time_us() -> Int
