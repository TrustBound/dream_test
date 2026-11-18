-module(snippets_coverage_lock_ffi).
-export([with_lock/1]).

%% Run Work while holding the coverage lock, so two snippet tests never
%% measure `src` at the same time.
%%
%% The lock is a process that gives the lock to one test at a time, in the
%% order that the tests ask. A test that waits gets a message when the lock
%% is free. `global:trans/2` is not used: a caller that finds its lock taken
%% sleeps a random time of up to 8 seconds before it tries again, so a test
%% can time out while the lock is free.
with_lock(Work) ->
    Lock = lock_process(),
    Ref = erlang:monitor(process, Lock),
    Lock ! {acquire, self(), Ref},
    receive
        {granted, Ref} -> ok;
        {'DOWN', Ref, process, Lock, Reason} -> erlang:error({coverage_lock_stopped, Reason})
    end,
    try
        Work()
    after
        Lock ! {release, Ref},
        erlang:demonitor(Ref, [flush])
    end.

%% The lock process, started by the first test that needs it. It is not
%% linked to that test, so it lives until the end of the test run.
lock_process() ->
    case whereis(snippets_coverage_lock) of
        undefined ->
            Pid = spawn(fun() -> lock_loop(none, queue:new()) end),
            try register(snippets_coverage_lock, Pid) of
                true -> Pid
            catch
                error:badarg ->
                    %% Another test registered a lock process first.
                    exit(Pid, kill),
                    lock_process()
            end;
        Pid ->
            Pid
    end.

%% `Holder` is `none` or `{Pid, Ref, Monitor}`. `Waiting` holds the tests
%% that asked for the lock while another test held it. A holder that exits
%% without a release, for example a test that timed out, frees the lock.
lock_loop(Holder, Waiting) ->
    receive
        {acquire, Pid, Ref} when Holder =:= none ->
            lock_loop(grant(Pid, Ref), Waiting);
        {acquire, Pid, Ref} ->
            lock_loop(Holder, queue:in({Pid, Ref}, Waiting));
        {release, Ref} when element(2, Holder) =:= Ref ->
            next_holder(Holder, Waiting);
        {'DOWN', Monitor, process, _Pid, _Reason} when element(3, Holder) =:= Monitor ->
            next_holder(Holder, Waiting);
        _Other ->
            lock_loop(Holder, Waiting)
    end.

grant(Pid, Ref) ->
    Monitor = erlang:monitor(process, Pid),
    Pid ! {granted, Ref},
    {Pid, Ref, Monitor}.

next_holder({_Pid, _Ref, Monitor}, Waiting) ->
    erlang:demonitor(Monitor, [flush]),
    case queue:out(Waiting) of
        {{value, {Pid, Ref}}, Rest} -> lock_loop(grant(Pid, Ref), Rest);
        {empty, Rest} -> lock_loop(none, Rest)
    end.
