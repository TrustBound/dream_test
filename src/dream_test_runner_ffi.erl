-module(dream_test_runner_ffi).
-export([end_program/1]).

%% Ask the BEAM to stop with Status, then wait until the init process kills
%% this process at the end of the shutdown, so the caller never returns.
%%
%% The wait is a `receive` with no patterns, so it loads no module: the
%% code server stops early in the shutdown, and a call that must load a
%% module (for example `timer:sleep(infinity)`) can crash here. The shutdown
%% stops the applications, so their stop paths run and the output is
%% written before the BEAM exits.
end_program(Status) ->
    ok = init:stop(Status),
    receive after infinity -> nil end.
