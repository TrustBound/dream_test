%% Erlang FFI helpers for dream_test/sandbox.
%%
%% We use this to optionally run a test function while catching crashes so we
%% can suppress noisy crash reports while still reporting SandboxCrashed.
-module(sandbox_ffi).

-export([run_catching/1]).

run_catching(Fun) ->
  try
    {ok, Fun()}
  catch
    Class:Reason:Stack ->
      %% Keep it simple and stable for tests: include class + reason.
      Text0 = io_lib:format("~p:~p", [Class, Reason]),
      Text = lists:flatten(Text0),
      _ = Stack,
      {error, Text}
  end.



