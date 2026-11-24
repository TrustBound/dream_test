-module(dream_test_reporter_test_ffi).
-export([
    with_terminal_columns/2,
    without_terminal/1,
    with_columns_variable/2,
    without_gleam_stdlib_application/1,
    crash_render/1,
    crash_render_with_long_reason/1,
    throw_render/1,
    exit_render/1
]).

%% Helpers for the reporter tests. They change only the state that the
%% reporters read: the group leader of the calling process, the COLUMNS
%% environment variable and the application data of gleam_stdlib. Each
%% helper puts the old state back before it returns.

%% ---------------------------------------------------------------------------
%% A fake terminal
%% ---------------------------------------------------------------------------

%% Run Function with a group leader that tells io:columns/0 that the
%% terminal has Columns columns.
with_terminal_columns(Columns, Function) ->
    with_group_leader(Columns, Function).

%% Run Function with a group leader that is not a terminal: it gives
%% {error, enotsup} for the terminal geometry.
without_terminal(Function) ->
    with_group_leader({error, enotsup}, Function).

with_group_leader(GeometryReply, Function) ->
    Old = group_leader(),
    Fake = spawn(fun() -> fake_terminal(GeometryReply) end),
    group_leader(Fake, self()),
    try
        Function()
    after
        group_leader(Old, self()),
        exit(Fake, kill)
    end.

fake_terminal(GeometryReply) ->
    receive
        {io_request, From, ReplyAs, {get_geometry, columns}} ->
            From ! {io_reply, ReplyAs, GeometryReply};
        {io_request, From, ReplyAs, _Request} ->
            From ! {io_reply, ReplyAs, ok}
    end,
    fake_terminal(GeometryReply).

%% ---------------------------------------------------------------------------
%% The COLUMNS environment variable
%% ---------------------------------------------------------------------------

%% Run Function with COLUMNS set to Value ({some, Text}) or unset (none).
%% The environment belongs to the whole node. Only the progress reporter
%% reads COLUMNS, and only when its group leader is not a terminal.
with_columns_variable(Value, Function) ->
    Old = os:getenv("COLUMNS"),
    set_columns(Value),
    try
        Function()
    after
        restore_columns(Old)
    end.

set_columns({some, Text}) ->
    true = os:putenv("COLUMNS", unicode:characters_to_list(Text));
set_columns(none) ->
    true = os:unsetenv("COLUMNS").

restore_columns(false) ->
    true = os:unsetenv("COLUMNS");
restore_columns(Text) ->
    true = os:putenv("COLUMNS", Text).

%% ---------------------------------------------------------------------------
%% The gleam_stdlib application data
%% ---------------------------------------------------------------------------

%% Run Function while the node has no application data for gleam_stdlib,
%% as in a node that runs without the .app file of gleam_stdlib. Only the
%% JSON reporter reads this data.
without_gleam_stdlib_application(Function) ->
    Running = lists:keymember(gleam_stdlib, 1, application:which_applications()),
    case Running of
        true -> ok = application:stop(gleam_stdlib);
        false -> ok
    end,
    ok = application:unload(gleam_stdlib),
    try
        Function()
    after
        ok = application:load(gleam_stdlib),
        case Running of
            true -> ok = application:start(gleam_stdlib);
            false -> ok
        end
    end.

%% ---------------------------------------------------------------------------
%% A custom results reporter that crashes
%% ---------------------------------------------------------------------------

%% A render function for reporter_types.Custom that crashes with a stable
%% reason, so a test can check the exact error text.
crash_render(_Report) ->
    erlang:error(custom_render_crashed).

%% A render function for reporter_types.Custom that crashes with a reason
%% whose text is longer than one line: `~p` breaks it over many lines.
crash_render_with_long_reason(_Report) ->
    erlang:error({long_reason, lists:seq(1, 120)}).

%% A render function for reporter_types.Custom that throws a stable value.
throw_render(_Report) ->
    erlang:throw(custom_render_thrown).

%% A render function for reporter_types.Custom that calls exit/1 with a
%% stable reason. This is an exception in the calling process, not an exit
%% signal from another process.
exit_render(_Report) ->
    erlang:exit(custom_render_exited).
