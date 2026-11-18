-module(dream_test_hook_resource_test_ffi).
-export([new_named_table/1, table_exists/1, delete_table/1, start_linked_crash/0]).

%% Helpers for the hook resource tests. A test helper that owns an ETS table
%% is the simplest resource a hook can start: the table lives only while the
%% process that made it lives.

%% Make a public named ETS table that the calling process owns.
new_named_table(Name) ->
    _ = ets:new(Name, [named_table, public, set]),
    nil.

%% True when a table with this name exists.
table_exists(Name) ->
    ets:info(Name) =/= undefined.

%% Delete the named table. A table that is gone already is not an error.
delete_table(Name) ->
    case ets:info(Name) of
        undefined -> nil;
        _ -> _ = ets:delete(Name), nil
    end.

%% Start a process that links to the caller and exits with reason `boom`
%% after 10ms, so the caller dies a short time after it returns.
start_linked_crash() ->
    _ = spawn_link(fun exit_after_delay/0),
    nil.

exit_after_delay() ->
    timer:sleep(10),
    exit(boom).
