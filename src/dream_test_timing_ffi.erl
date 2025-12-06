-module(dream_test_timing_ffi).
-export([monotonic_time_ms/0, monotonic_time_us/0]).

%% Get monotonic time in milliseconds
monotonic_time_ms() ->
    erlang:monotonic_time(millisecond).

%% Get monotonic time in microseconds
monotonic_time_us() ->
    erlang:monotonic_time(microsecond).





