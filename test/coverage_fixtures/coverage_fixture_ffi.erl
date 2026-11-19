%% Fixture for the coverage tests: an Erlang module in the source directory.
-module(coverage_fixture_ffi).
-export([double/1]).

double(Number) ->
    Number * 2.
