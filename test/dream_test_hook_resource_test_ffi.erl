-module(dream_test_hook_resource_test_ffi).
-export([new_named_table/1, table_exists/1, delete_table/1, start_linked_crash/1,
         crash_owner/1, links_alive/1, table_owner_alive/1]).

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

%% Start a process that links to the caller and registers it under `Name`.
%% The process waits until `crash_owner(Name)` tells it to exit. Then it
%% exits with reason `boom`, so the caller (the owner) dies through the
%% link. The name is registered before this function returns, so a test
%% can always find the process.
start_linked_crash(Name) ->
    Owner = self(),
    Pid = spawn_link(fun() -> wait_for_crash(Owner) end),
    true = register(Name, Pid),
    nil.

wait_for_crash(Owner) ->
    receive
        {crash, From, Ref} ->
            From ! {Ref, Owner},
            exit(boom)
    end.

%% Tell the process under `Name` to exit, then wait until the owner that
%% started it has exited. When this function returns, the owner is dead.
crash_owner(Name) ->
    Ref = make_ref(),
    Name ! {crash, self(), Ref},
    Owner = receive {Ref, Pid} -> Pid end,
    Monitor = erlang:monitor(process, Owner),
    receive
        {'DOWN', Monitor, process, Owner, _Reason} -> nil
    end.

%% True when the process is alive, links to at least one process, and every
%% process that it links to is alive and not exiting. A pool links to the
%% process that started it, so this says that the process of the hook
%% still runs, with no wait.
links_alive(Pid) ->
    case erlang:process_info(Pid, links) of
        {links, [_ | _] = Links} -> lists:all(fun is_running/1, Links);
        _ -> false
    end.

%% True when the named table exists and its owner is alive and not exiting.
table_owner_alive(Name) ->
    case ets:info(Name, owner) of
        undefined -> false;
        Owner -> is_running(Owner)
    end.

%% A process that exits is `exiting` for a short time before it is gone.
is_running(Pid) ->
    case erlang:process_info(Pid, status) of
        {status, exiting} -> false;
        {status, _} -> true;
        undefined -> false
    end.
