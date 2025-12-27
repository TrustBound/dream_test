%% Erlang FFI helpers for the live progress reporter.
-module(dream_test_reporter_progress_ffi).

-export([columns/0]).

columns() ->
  case io:columns() of
    {ok, C} when is_integer(C), C > 0 ->
      C;
    _ ->
      env_columns_or_default()
  end.

env_columns_or_default() ->
  case os:getenv("COLUMNS") of
    false ->
      80;
    Str ->
      parse_int_or_default(Str, 80)
  end.

parse_int_or_default(Str, Default) ->
  case string:to_integer(Str) of
    {Int, _Rest} when is_integer(Int), Int > 0 ->
      Int;
    _ ->
      Default
  end.




