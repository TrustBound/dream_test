-module(snippets_child_vm_ffi).
-export([run/4, run_with_coverage_lock/4]).

%% Run `Module:Function()` in a new `erl` process (the child), with the code
%% path of this test run and the current folder (the snippets project).
%%
%% Module is the Gleam module name (`snippets/doc/unit/describe`), and
%% Function is the name of a public function with no arguments. Only the
%% characters `a-z`, `0-9`, `_` and `/` are accepted, so the names cannot
%% change the Erlang expression that the child evaluates. No shell starts
%% the child: `erl` gets its arguments as a list.
%%
%% The child stops with status 0 when the function returns. A function that
%% crashes writes the error to the standard error stream of the child, and
%% the child stops with status 1. A function can also stop the child itself,
%% for example with `runner.exit_on_failure()`.
%%
%% Environment is a list of `{Name, Value}` pairs that the child gets in
%% its environment. The child never inherits `DREAM_TEST_COVERAGE` from the
%% test run: it has that variable only when Environment names it. So the
%% result does not depend on how the test run was started.
%%
%% Returns `{ok, {Status, Output, ErrorOutput}}`, where Output is what the
%% child wrote to its standard output, and ErrorOutput is what it wrote to
%% the `standard_error` IO device. The child writes ErrorOutput to a file
%% under `build/child_vm/`, which is deleted after it is read.
%%
%% The child gets DeadlineMs milliseconds in all. A child that does not stop
%% in time is killed, and the result is `{error, Text}` with the output so
%% far. A worker process starts the child and waits for it. When the calling
%% process stops first, for example because its test timed out, the worker
%% kills the child. So the child never runs longer than the test.
run(Module, Function, Environment, DeadlineMs) ->
    case valid_name(Module) andalso valid_name(Function) of
        true -> run_valid(Module, Function, Environment, DeadlineMs);
        false -> {error, <<"not a module or function name: ", Module/binary, ".", Function/binary>>}
    end.

%% `run/3`, while this process holds the coverage lock of the snippet tests.
%% Use it for a function that measures coverage, because those write files
%% under `build/coverage`. The deadline starts when this process has the
%% lock.
run_with_coverage_lock(Module, Function, Environment, DeadlineMs) ->
    snippets_coverage_lock_ffi:with_lock(
        fun() -> run(Module, Function, Environment, DeadlineMs) end
    ).

valid_name(<<>>) ->
    false;
valid_name(Name) ->
    lists:all(fun valid_character/1, binary_to_list(Name)).

valid_character(Character) when Character >= $a, Character =< $z -> true;
valid_character(Character) when Character >= $0, Character =< $9 -> true;
valid_character($_) -> true;
valid_character($/) -> true;
valid_character(_Character) -> false.

run_valid(Module, Function, Environment, DeadlineMs) ->
    Caller = self(),
    Ref = make_ref(),
    {Worker, Monitor} = spawn_monitor(
        fun() -> run_for(Caller, Ref, Module, Function, Environment, DeadlineMs) end
    ),
    receive
        {Ref, Result} ->
            erlang:demonitor(Monitor, [flush]),
            Result;
        {'DOWN', Monitor, process, Worker, Reason} ->
            erlang:error({child_vm_worker_stopped, Reason})
    end.

%% In the worker: start the child, collect its output and send the result
%% to Caller.
run_for(Caller, Ref, Module, Function, Environment, DeadlineMs) ->
    CallerMonitor = erlang:monitor(process, Caller),
    Deadline = erlang:monotonic_time(millisecond) + DeadlineMs,
    ErrorPath = error_output_path(),
    ok = filelib:ensure_dir(ErrorPath),
    Port = open_port(
        {spawn_executable, os:find_executable("erl")},
        [exit_status, binary, use_stdio,
         {env, child_environment(Environment)},
         {args, ["-noshell" | code_path_args()]
                ++ ["-eval", child_expression(Module, Function, ErrorPath)]}]
    ),
    {os_pid, OsPid} = erlang:port_info(Port, os_pid),
    Result = collect_output(Port, OsPid, CallerMonitor, Deadline, DeadlineMs, <<>>, ErrorPath),
    Caller ! {Ref, Result}.

child_environment(Environment) ->
    [{"ERL_CRASH_DUMP_SECONDS", "0"}, {"DREAM_TEST_COVERAGE", false}]
    ++ [{binary_to_list(Name), binary_to_list(Value)} || {Name, Value} <- Environment].

%% The expression that the child evaluates. It sets standard output to
%% Unicode, the same way as the main wrapper of `gleam run`, sends the
%% `standard_error` IO device to the file at ErrorPath, calls the
%% function, and stops.
child_expression(Module, Function, ErrorPath) ->
    ErlangModule = binary:replace(Module, <<"/">>, <<"@">>, [global]),
    lists:flatten(io_lib:format(
        "ok = io:setopts(standard_io, [binary, {encoding, unicode}]),"
        " {ok, ErrorFile} = file:open(~p, [write, {encoding, utf8}]),"
        " erlang:unregister(standard_error),"
        " erlang:register(standard_error, ErrorFile),"
        " try '~ts':'~ts'() of"
        "   _Returned -> init:stop(0)"
        " catch"
        "   Class:Reason:Stacktrace ->"
        "     io:format(standard_error, \"~~p:~~p~~n~~p~~n\", [Class, Reason, Stacktrace]),"
        "     erlang:halt(1)"
        " end.",
        [ErrorPath, ErlangModule, Function]
    )).

error_output_path() ->
    Unique = integer_to_list(erlang:unique_integer([positive])),
    OsPid = os:getpid(),
    filename:absname(filename:join(["build", "child_vm", OsPid ++ "_" ++ Unique ++ ".stderr"])).

collect_output(Port, OsPid, CallerMonitor, Deadline, DeadlineMs, Output, ErrorPath) ->
    Remaining = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {Port, {data, Data}} ->
            collect_output(Port, OsPid, CallerMonitor, Deadline, DeadlineMs,
                           <<Output/binary, Data/binary>>, ErrorPath);
        {Port, {exit_status, Status}} ->
            {ok, {Status, Output, take_error_output(ErrorPath)}};
        {'DOWN', CallerMonitor, process, _Caller, _Reason} ->
            Killed = kill_child(Port, OsPid),
            _ = file:delete(ErrorPath),
            caller_stopped(Killed)
    after Remaining ->
        Killed = kill_child(Port, OsPid),
        ErrorOutput = take_error_output(ErrorPath),
        {error, <<"the child VM did not stop in ",
                  (integer_to_binary(DeadlineMs))/binary, " ms: ",
                  (kill_text(Killed))/binary,
                  "\nstandard output:\n", Output/binary,
                  "\nstandard error:\n", ErrorOutput/binary>>}
    end.

%% Read the error output file and delete it. A child that stopped before it
%% opened the file wrote no error output.
take_error_output(ErrorPath) ->
    case file:read_file(ErrorPath) of
        {ok, Text} ->
            ok = file:delete(ErrorPath),
            Text;
        {error, enoent} ->
            <<>>
    end.

%% The caller stopped and the child is killed or had already ended: stop
%% the worker. No process monitors the worker after its caller stopped, so
%% a kill that failed is written to the standard error stream before the
%% worker stops with the kill error.
caller_stopped(killed) ->
    exit(normal);
caller_stopped(already_ended) ->
    exit(normal);
caller_stopped({kill_failed, Text}) ->
    io:format(standard_error,
              "the caller stopped, and the kill of its child VM failed: ~ts~n",
              [Text]),
    exit({kill_of_child_vm_failed, Text}).

kill_text(killed) ->
    <<"killed">>;
kill_text(already_ended) ->
    <<"it had already ended">>;
kill_text({kill_failed, Text}) ->
    <<"the kill failed: ", Text/binary>>.

%% Kill the operating system process of the child, and close its port.
%% Closing the port alone does not stop it: the BEAM does not stop at the
%% end of its standard input. The `kill` executable gets its arguments as a
%% list, and the only argument that changes is the process number.
kill_child(Port, OsPid) ->
    KillPort = open_port(
        {spawn_executable, os:find_executable("kill")},
        [exit_status, binary, stderr_to_stdout,
         {args, ["-KILL", integer_to_list(OsPid)]}]
    ),
    KillResult = kill_result(collect_kill(KillPort, <<>>)),
    try
        port_close(Port)
    catch
        error:badarg -> ok
    end,
    KillResult.

collect_kill(KillPort, Text) ->
    receive
        {KillPort, {data, Data}} -> collect_kill(KillPort, <<Text/binary, Data/binary>>);
        {KillPort, {exit_status, 0}} -> ok;
        {KillPort, {exit_status, _Status}} -> {failed, Text}
    end.

%% `kill` says `No such process` when the child had already ended, which is
%% not a failure.
kill_result(ok) ->
    killed;
kill_result({failed, Text}) ->
    case string:find(Text, <<"No such process">>) of
        nomatch -> {kill_failed, string:trim(Text)};
        _Found -> already_ended
    end.

code_path_args() ->
    lists:append([["-pa", Path] || Path <- code:get_path(), is_build_path(Path)]).

is_build_path(Path) ->
    string:find(Path, "/build/") =/= nomatch.
