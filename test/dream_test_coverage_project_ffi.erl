-module(dream_test_coverage_project_ffi).
-export([
    project/1,
    add_source/3,
    compile_source/3,
    compile_outside_source/2,
    add_damaged_beam/2,
    delete_beam/2,
    make_unreadable/2,
    load_module/1,
    add_line_counters_like_another_tool/1,
    run_old_code/1,
    stop_process/1,
    load_original/1,
    line_counts/1,
    with_fixture_lock/1,
    start_measuring_for/4,
    debug_info/4,
    start_server/1,
    ask/1,
    is_alive/1,
    call_answer/1,
    start_while_finishing/2,
    call_in_ended_process/1
]).

%% Helpers for the coverage tests that run in the test run's own BEAM.
%%
%% Each project is a folder build/coverage/projects/<Name> with src/ and
%% ebin/. Its ebin/ is on the code path. Tests reach its src/ folder as
%% `test/../build/coverage/projects/<Name>/src`, because coverage only
%% measures folders below src, test or dev. Module names come from `.erl`
%% file names, so every test uses module names that no other test uses.

-define(PROJECTS_DIRECTORY, "build/coverage/projects").

%% Create an empty project, deleting the project of an earlier run, and
%% return its source directory as coverage sees it.
project(Name) ->
    Directory = filename:join(?PROJECTS_DIRECTORY, unicode:characters_to_list(Name)),
    ok = delete_directory(Directory),
    ok = filelib:ensure_path(filename:join(Directory, "src")),
    ok = filelib:ensure_path(filename:join(Directory, "ebin")),
    true = code:add_patha(filename:absname(filename:join(Directory, "ebin"))),
    unicode:characters_to_binary(["test/../", Directory, "/src"]).

delete_directory(Directory) ->
    case file:del_dir_r(Directory) of
        ok -> ok;
        {error, enoent} -> ok
    end.

%% Write SourceDirectory/File.
add_source(SourceDirectory, File, Text) ->
    ok = file:write_file(filename:join(SourceDirectory, File), Text),
    nil.

%% Compile SourceDirectory/File into the project's ebin/ with debug
%% information of a given kind.
compile_source(SourceDirectory, File, Kind) ->
    Source = unicode:characters_to_list(filename:join(SourceDirectory, File)),
    {ok, Module, Binary} = compile:file(Source, [binary, return_errors | debug_options(Kind)]),
    ok = file:write_file(beam_path(SourceDirectory, atom_to_binary(Module)), Binary),
    nil.

debug_options(<<"debug_info">>) -> [debug_info];
debug_options(<<"no_debug_info">>) -> [];
debug_options(<<"encrypted_debug_info">>) -> [{debug_info_key, "secret"}];
debug_options(<<"missing_debug_info_backend">>) -> [{debug_info, {no_such_backend, []}}];
debug_options(<<"uncompilable_debug_info">>) -> [{debug_info, {?MODULE, uncompilable_forms()}}].

%% Debug information whose code calls a function that does not exist, so
%% the compiler rejects it.
uncompilable_forms() ->
    [
        {attribute, 1, module, uncompilable},
        {attribute, 2, export, [{f, 0}]},
        {function, 3, f, 0, [{clause, 3, [], [], [{call, 3, {atom, 3, missing}, []}]}]}
    ].

%% The debug information backend of `uncompilable_debug_info`: it returns
%% the abstract code that `compile_source` stored.
debug_info(erlang_v1, _Module, Forms, _Options) ->
    {ok, Forms}.

%% Compile the Erlang source Text into the project's ebin/. The source is
%% kept outside the source directory, so coverage reads only the other
%% files there, and its module can have the name of a Gleam module. Its
%% annotations hold lines without columns, as Gleam's do.
compile_outside_source(SourceDirectory, Text) ->
    Path = filename:join([SourceDirectory, "..", "outside.erl"]),
    ok = file:write_file(Path, Text),
    {ok, Module, Binary} = compile:file(unicode:characters_to_list(Path), [binary, return_errors, debug_info, {error_location, line}]),
    ok = file:write_file(beam_path(SourceDirectory, atom_to_binary(Module)), Binary),
    nil.

%% Write a damaged ebin/Module.beam.
add_damaged_beam(SourceDirectory, Module) ->
    ok = file:write_file(beam_path(SourceDirectory, Module), <<"not a beam file">>),
    nil.

%% Delete ebin/Module.beam, for example after the module is loaded.
delete_beam(SourceDirectory, Module) ->
    ok = file:delete(beam_path(SourceDirectory, Module)),
    nil.

beam_path(SourceDirectory, Module) ->
    filename:join([SourceDirectory, "..", "ebin", <<Module/binary, ".beam">>]).

%% Take away every permission on SourceDirectory/File, so reading it fails.
make_unreadable(SourceDirectory, File) ->
    ok = file:change_mode(filename:join(SourceDirectory, File), 8#000),
    nil.

load_module(Module) ->
    {module, _} = code:ensure_loaded(binary_to_atom(Module)),
    nil.

%% Load a module again with line counters but without dream_test's mark,
%% as another coverage tool would.
add_line_counters_like_another_tool(Module) ->
    Name = binary_to_atom(Module),
    {module, Name} = code:ensure_loaded(Name),
    {ok, {Name, [{abstract_code, {raw_abstract_v1, Forms}}]}} = beam_lib:chunks(code:which(Name), [abstract_code]),
    {ok, Name, Binary} = compile:forms(Forms, [binary, return_errors, line_coverage, force_line_counters]),
    {module, Name} = code:load_binary(Name, code:which(Name), Binary),
    nil.

%% Start a process that runs `Module:wait/0`, then load the module again, so
%% the process runs old code. Returns the process.
run_old_code(Module) ->
    Name = binary_to_atom(Module),
    {module, Name} = code:ensure_loaded(Name),
    Process = spawn(Name, wait, []),
    {module, Name} = code:load_file(Name),
    Process.

stop_process(Process) ->
    exit(Process, kill),
    nil.

%% Load the module's .beam file again, without line counters. Old code that
%% no process runs is removed first.
load_original(Module) ->
    Name = binary_to_atom(Module),
    true = code:soft_purge(Name),
    {module, Name} = code:load_file(Name),
    nil.

%% The line counts of a module, as the VM holds them.
line_counts(Module) ->
    [{Line, Calls} || {Line, Calls} <- code:get_coverage(line, binary_to_atom(Module))].

%% Run Function while holding the lock of the shared fixture modules, so
%% two tests never measure them at the same time.
%%
%% The lock is a process that gives the lock to one test at a time, in the
%% order that the tests ask. A test that waits gets a message when the lock
%% is free. `global:trans/4` is not used: a caller that finds its lock taken
%% sleeps a random time of up to 8 seconds before it tries again, so a test
%% can time out while the lock is free.
with_fixture_lock(Function) ->
    Lock = fixture_lock(),
    Ref = erlang:monitor(process, Lock),
    Lock ! {acquire, self(), Ref},
    receive
        {granted, Ref} -> ok;
        {'DOWN', Ref, process, Lock, Reason} -> erlang:error({fixture_lock_stopped, Reason})
    end,
    try
        Function()
    after
        Lock ! {release, Ref},
        erlang:demonitor(Ref, [flush])
    end.

%% The lock process, started by the first test that needs it. It is not
%% linked to that test, so it lives until the end of the test run.
fixture_lock() ->
    case whereis(dream_test_fixture_lock) of
        undefined ->
            Pid = spawn(fun() -> lock_loop(none, queue:new()) end),
            try register(dream_test_fixture_lock, Pid) of
                true -> Pid
            catch
                error:badarg ->
                    %% Another test registered a lock process first.
                    exit(Pid, kill),
                    fixture_lock()
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

%% `dream_test_coverage_ffi:start_measuring/1` for a runtime that is not
%% the one the tests run on, with no modules to measure.
start_measuring_for(Supported, CompilerLoaded, OtpRelease, EmulatorFlavor) ->
    dream_test_coverage_ffi:start_if_supported(
        Supported,
        compiler_load(CompilerLoaded),
        unicode:characters_to_list(OtpRelease),
        binary_to_atom(EmulatorFlavor),
        [],
        #{}
    ).

compiler_load(true) -> {module, compile};
compiler_load(false) -> {error, nofile}.

%% Start a process that runs `Module:serve/0`. Returns the process.
start_server(Module) ->
    spawn(binary_to_atom(Module), serve, []).

%% Send `{ask, self()}` to a process from `start_server/1` and return its
%% answer, or `timeout` after one second.
ask(Process) ->
    Process ! {ask, self()},
    receive
        {answer, Answer} -> Answer
    after 1000 -> timeout
    end.

is_alive(Process) ->
    erlang:is_process_alive(Process).

%% Call `Module:answer/0`.
call_answer(Module) ->
    (binary_to_atom(Module)):answer().

%% Finish Session, and start a second run with Config at the moment
%% `dream_test_coverage_ffi` reads the line counters of Session. Returns
%% what the second start returned. A second session that started is
%% finished.
start_while_finishing(Session, Config) ->
    {coverage_session, _Config, Measurement, Modules, _Excluded, _Marks, _Inexact} = Session,
    Step = fun() -> self() ! {second_start, 'dream_test@coverage':start(Config)} end,
    _ = dream_test_coverage_ffi:stop_measuring_after(Step, Measurement, Modules),
    receive
        {second_start, Second} -> finish_second(Second)
    end.

finish_second({ok, Session} = Second) ->
    _ = 'dream_test@coverage':finish(Session),
    Second;
finish_second(Second) ->
    Second.

%% Call Function in a new process, and wait until that process ends.
%% Returns what Function returned.
call_in_ended_process(Function) ->
    {Process, Monitor} = spawn_monitor(fun() -> exit({returned, Function()}) end),
    receive
        {'DOWN', Monitor, process, Process, {returned, Value}} -> Value
    end.
