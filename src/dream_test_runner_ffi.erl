-module(dream_test_runner_ffi).
-export([end_program/1, start_outermost_run/0, finish_outermost_run/1, command_line_arguments/0]).

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

-define(RUN_OWNER, dream_test_outermost_run).

%% Whether the calling process starts the outermost run: true when no
%% live process runs one. A run inside a test of another run gets false,
%% so only the outermost run reads the command line.
start_outermost_run() ->
    Owner = persistent_term:get(?RUN_OWNER, none),
    take_outermost_run(is_pid(Owner) andalso is_process_alive(Owner)).

take_outermost_run(true) -> false;
take_outermost_run(false) ->
    persistent_term:put(?RUN_OWNER, self()),
    true.

%% End the outermost run, so a later run can read the command line.
finish_outermost_run(true) ->
    _ = persistent_term:erase(?RUN_OWNER),
    nil;
finish_outermost_run(false) ->
    nil.

%% The plain arguments of the BEAM: `gleam test -- A B` gives [A, B].
command_line_arguments() ->
    [unicode:characters_to_binary(Argument) || Argument <- init:get_plain_arguments()].
