-module(snippets_doc_blocks_ffi).
-export([
    wildcard/2,
    git_show/2,
    exports_tests/1,
    run_main_in_new_vm/2,
    run_main_in_new_vm_with_coverage_lock/2
]).

%% The files under Root that match Pattern, as paths relative to Root, in
%% order.
wildcard(Pattern, Root) ->
    Paths = filelib:wildcard(binary_to_list(Pattern), binary_to_list(Root)),
    [unicode:characters_to_binary(Path) || Path <- lists:sort(Paths)].

%% `git -C Root show Spec`: {ok, Text}, or {error, nil} when git is not
%% installed or the revision or the file is missing (for example a shallow
%% clone with no tags). The error text of git is not printed.
git_show(Root, Spec) ->
    git_show_with(os:find_executable("git"), Root, Spec).

git_show_with(false, _Root, _Spec) ->
    {error, nil};
git_show_with(Git, Root, Spec) ->
    Port = open_port({spawn_executable, Git},
                     [{args, ["-C", Root, "show", Spec]},
                      binary, exit_status, stderr_to_stdout]),
    collect(Port, <<>>).

collect(Port, Text) ->
    receive
        {Port, {data, Data}} -> collect(Port, <<Text/binary, Data/binary>>);
        {Port, {exit_status, 0}} -> {ok, Text};
        {Port, {exit_status, _Status}} -> {error, nil}
    end.

%% Whether the module Name loads and exports `tests/0`. This is the test
%% that discovery makes: a module without `tests/0` is skipped.
exports_tests(Name) ->
    Module = binary_to_atom(Name),
    case code:ensure_loaded(Module) of
        {module, Module} -> erlang:function_exported(Module, tests, 0);
        {error, _Reason} -> false
    end.

%% Run `Module:main()` in a new `erl` process with the code path of this
%% test run, from the current folder (the snippets project). The process
%% stops with `init:stop(0)` after `main` returns, the same way as the
%% wrapper of a main in Gleam 1.14 and newer. Returns {ExitStatus, Output},
%% with stdout and stderr together.
%%
%% The new process gets DeadlineMs milliseconds in all, from its start. A
%% process that does not stop in time is killed, and the status is -1. A
%% worker process starts the new process and waits for it. When the calling
%% process stops first, for example because its test timed out, the worker
%% kills the new process. A crash of the new process writes no
%% erl_crash.dump file.
run_main_in_new_vm(Module, DeadlineMs) ->
    Caller = self(),
    Ref = make_ref(),
    {Worker, Monitor} = spawn_monitor(
        fun() -> run_for(Caller, Ref, Module, DeadlineMs) end
    ),
    receive
        {Ref, Result} ->
            erlang:demonitor(Monitor, [flush]),
            Result;
        {'DOWN', Monitor, process, Worker, Reason} ->
            erlang:error({main_worker_stopped, Reason})
    end.

%% `run_main_in_new_vm/2`, while this process holds the coverage lock. The
%% deadline starts when this process has the lock.
run_main_in_new_vm_with_coverage_lock(Module, DeadlineMs) ->
    snippets_coverage_lock_ffi:with_lock(
        fun() -> run_main_in_new_vm(Module, DeadlineMs) end
    ).

%% In the worker: start the new process, collect its output and send the
%% result to Caller.
run_for(Caller, Ref, Module, DeadlineMs) ->
    CallerMonitor = erlang:monitor(process, Caller),
    Deadline = erlang:monotonic_time(millisecond) + DeadlineMs,
    Eval = io_lib:format("'~ts':main(), init:stop(0).", [Module]),
    Port = open_port(
        {spawn_executable, os:find_executable("erl")},
        [exit_status, binary, stderr_to_stdout, use_stdio,
         {env, [{"ERL_CRASH_DUMP_SECONDS", "0"}]},
         {args, ["-noshell" | code_path_args()] ++ ["-eval", lists:flatten(Eval)]}]
    ),
    {os_pid, OsPid} = erlang:port_info(Port, os_pid),
    Result = collect_output(Port, OsPid, CallerMonitor, Deadline, DeadlineMs, <<>>),
    Caller ! {Ref, Result}.

collect_output(Port, OsPid, CallerMonitor, Deadline, DeadlineMs, Output) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {Port, {data, Data}} ->
            collect_output(Port, OsPid, CallerMonitor, Deadline, DeadlineMs,
                           <<Output/binary, Data/binary>>);
        {Port, {exit_status, Status}} ->
            {Status, Output};
        {'DOWN', CallerMonitor, process, _Caller, _Reason} ->
            caller_stopped(kill_new_process(Port, OsPid))
    after Remaining ->
        Seconds = integer_to_binary(DeadlineMs div 1000),
        {-1, <<Output/binary, "\n[the main did not stop in ", Seconds/binary,
               " seconds: ", (kill_text(kill_new_process(Port, OsPid)))/binary,
               "]">>}
    end.

%% The caller stopped and the new process is killed or had already ended:
%% stop the worker. No process monitors the worker after its caller
%% stopped, so a kill that failed is written to the standard error stream
%% before the worker stops with the kill error.
caller_stopped(killed) ->
    exit(normal);
caller_stopped(already_ended) ->
    exit(normal);
caller_stopped({kill_failed, Text}) ->
    io:format(standard_error,
              "the caller stopped, and the kill of its main process failed: ~ts~n",
              [Text]),
    exit({kill_of_main_failed, Text}).

kill_text(killed) ->
    <<"killed">>;
kill_text(already_ended) ->
    <<"it had already ended">>;
kill_text({kill_failed, Text}) ->
    <<"the kill failed: ", Text/binary>>.

%% Kill the operating system process of the new BEAM, and close its port.
%% Closing the port alone does not stop it: the BEAM does not stop at the
%% end of its standard input. `kill` writes nothing when it succeeds. The
%% port is already closed when the process ended just before the kill.
kill_new_process(Port, OsPid) ->
    KillOutput = os:cmd("kill -KILL " ++ integer_to_list(OsPid)),
    try
        port_close(Port)
    catch
        error:badarg -> ok
    end,
    kill_result(unicode:characters_to_binary(KillOutput)).

kill_result(<<>>) ->
    killed;
kill_result(Text) ->
    kill_failure(string:find(Text, <<"No such process">>), string:trim(Text)).

%% `kill` says `No such process` when the process had already ended, which
%% is not a failure.
kill_failure(nomatch, Text) ->
    {kill_failed, Text};
kill_failure(_Found, _Text) ->
    already_ended.

code_path_args() ->
    lists:append([["-pa", Path] || Path <- code:get_path(), is_build_path(Path)]).

is_build_path(Path) ->
    string:find(Path, "/build/") =/= nomatch.
