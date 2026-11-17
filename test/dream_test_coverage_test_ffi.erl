-module(dream_test_coverage_test_ffi).
-export([
    unique_name/0,
    add_broken_beam_first_in_path/2,
    remove_from_path/1,
    run_in_peer/1,
    run_in_embedded_peer/1,
    run_main_in_new_vm/2,
    run_measured_main_in_new_vm/3,
    set_environment_variable/2,
    unset_environment_variable/1,
    start_server_in_new_vm/2,
    send_server_request/2,
    wait_for_server_exit/1,
    read_line/0,
    child_project/1,
    add_source/2,
    compile_source/1,
    compile_like_old_gleam/2,
    compile_like_new_gleam/3,
    format/1
]).
%% Called inside the child node only.
-export([prepare_child/1]).
%% Called inside a new `erl` process only.
-export([call_main/2]).

%% Helpers for the coverage tests that need a child node or a new `erl`
%% process: tests that change the code server mode, the working directory
%% or an environment variable, and tests whose main stops its BEAM.

-define(PROJECTS_DIRECTORY, "build/coverage/child_projects").

%% ---------------------------------------------------------------------------
%% Running a child
%% ---------------------------------------------------------------------------

%% Run a zero-argument function in a new child node.
%% Returns {ok, Value} or {error, Reason} (as a string).
run_in_peer(Function) ->
    run_in_child(Function, []).

%% The same, in a child that runs in embedded mode.
run_in_embedded_peer(Function) ->
    run_in_child(Function, ["-mode", "embedded"]).

run_in_child(Function, ExtraArgs) ->
    case peer:start_link(#{connection => standard_io, args => ExtraArgs ++ code_path_args()}) of
        {ok, Peer, _Node} -> prepare_call_and_stop(Peer, Function);
        {error, Reason} -> {error, format(Reason)}
    end.

prepare_call_and_stop(Peer, Function) ->
    {ok, Root} = file:get_cwd(),
    {module, ?MODULE} = peer:call(Peer, code, load_abs, [filename:rootname(code:which(?MODULE))]),
    ok = peer:call(Peer, ?MODULE, prepare_child, [Root], 60000),
    Result =
        try peer:call(Peer, erlang, apply, [Function, []], 60000) of
            Value -> {ok, Value}
        catch
            Class:Reason -> {error, format({Class, Reason})}
        end,
    peer:stop(Peer),
    Result.

%% In the child: remember the project root, and load every build module
%% when the child runs in embedded mode.
prepare_child(Root) ->
    persistent_term:put({?MODULE, root}, Root),
    case code:get_mode() of
        embedded -> preload_build_modules();
        interactive -> ok
    end.

%% Embedded mode only loads the modules of the boot script (kernel and
%% stdlib), so load the build modules and the compiler (for line counters)
%% by hand.
preload_build_modules() ->
    BuildPaths = [Path || Path <- code:get_path(), is_build_path(Path)],
    OtpPaths = filelib:wildcard(filename:join([code:root_dir(), "lib", "compiler-*", "ebin"])),
    Beams = lists:append([filelib:wildcard(filename:join(Path, "*.beam")) || Path <- BuildPaths ++ OtpPaths]),
    lists:foreach(fun(Beam) -> code:load_abs(filename:rootname(Beam)) end, Beams).

%% ---------------------------------------------------------------------------
%% Building projects inside a child
%% ---------------------------------------------------------------------------

%% Create an empty project (src/ and ebin/), deleting the project of an
%% earlier run, and make it the working directory. Its ebin/ is added to the
%% code path.
child_project(Name) ->
    Root = persistent_term:get({?MODULE, root}),
    Directory = filename:join([Root, ?PROJECTS_DIRECTORY, unicode:characters_to_list(Name)]),
    ok = delete_directory(Directory),
    ok = filelib:ensure_path(filename:join(Directory, "src")),
    ok = filelib:ensure_path(filename:join(Directory, "ebin")),
    true = code:add_patha(filename:join(Directory, "ebin")),
    ok = file:set_cwd(Directory),
    unicode:characters_to_binary(Directory).

%% Write src/File in the current project.
add_source(File, Text) ->
    ok = file:write_file(filename:join("src", File), Text),
    nil.

%% Compile src/File into ebin/ with debug information.
compile_source(File) ->
    Source = unicode:characters_to_list(filename:join("src", File)),
    {ok, Module, Binary} = compile:file(Source, [binary, return_errors, debug_info]),
    ok = file:write_file(filename:join("ebin", atom_to_list(Module) ++ ".beam"), Binary),
    nil.

%% Build ebin/Module.beam the way Gleam before 1.19 does: write the
%% generated Erlang source to _gleam_artefacts/Module.erl, then compile that
%% file. ErlangSource names the `.gleam` file with `-file` attributes.
compile_like_old_gleam(Module, ErlangSource) ->
    ok = filelib:ensure_path("_gleam_artefacts"),
    Source = unicode:characters_to_list(filename:join("_gleam_artefacts", <<Module/binary, ".erl">>)),
    ok = file:write_file(Source, ErlangSource),
    {ok, _, Binary} = compile:file(Source, [binary, return_errors, debug_info]),
    ok = file:write_file(filename:join("ebin", <<Module/binary, ".beam">>), Binary),
    nil.

%% Build ebin/Module.beam the way Gleam 1.19 does: compile abstract code
%% directly, with one `-file` attribute that names the `.gleam` file.
compile_like_new_gleam(Module, ErlangSource, GleamPath) ->
    {ok, Tokens, _} = erl_scan:string(unicode:characters_to_list(ErlangSource)),
    Forms = [Form || FormTokens <- split_forms(Tokens, []), {ok, Form} <- [erl_parse:parse_form(FormTokens)]],
    FileAttribute = {attribute, 0, file, {unicode:characters_to_list(GleamPath), 0}},
    {ok, _, Binary} = compile:forms([FileAttribute | Forms], [binary, return_errors, debug_info]),
    ok = file:write_file(filename:join("ebin", <<Module/binary, ".beam">>), Binary),
    nil.

split_forms([], []) -> [];
split_forms([{dot, _} = Dot | Rest], Current) -> [lists:reverse([Dot | Current]) | split_forms(Rest, [])];
split_forms([Token | Rest], Current) -> split_forms(Rest, [Token | Current]).

delete_directory(Directory) ->
    case file:del_dir_r(Directory) of
        ok -> ok;
        {error, enoent} -> ok
    end.

%% ---------------------------------------------------------------------------
%% Running a main in a new `erl` process
%% ---------------------------------------------------------------------------

%% Run `Module:Function()` in a new `erl` process, then stop it with status
%% 0, the same way as Gleam's own wrapper of a main: `init:stop(0)` after
%% the main returns. A main that already asked for `init:stop(1)` keeps
%% status 1, because the first stop request wins.
%% Returns {ExitStatus, Output}, with stdout and stderr together.
run_main_in_new_vm(Module, Function) ->
    Eval = io_lib:format("'~ts':'~ts'(), init:stop(0).", [Module, Function]),
    run_in_new_vm(Eval, []).

%% The same, but the process measures dream_test's own `src` from before
%% the call until the BEAM stops, and writes an LCOV part that the test run
%% merges (see test/dream_test/coverage_child_measure.gleam). Use it only for a main
%% that runs runner lines that no other test reaches, because each measured
%% process adds about 1.4 seconds.
%% Environment is a Gleam list of #(Name, Option(Value)): `Some(Value)` sets
%% the variable and `None` removes it.
run_measured_main_in_new_vm(Module, Function, Environment) ->
    Eval = io_lib:format(
        "'dream_test@coverage_child_measure':run_measured(<<\"~ts\">>, <<\"~ts\">>), init:stop(0).",
        [Module, Function]
    ),
    run_in_new_vm(Eval, Environment).

run_in_new_vm(Eval, Environment) ->
    Erl = os:find_executable("erl"),
    Port = open_port(
        {spawn_executable, Erl},
        [exit_status, binary, stderr_to_stdout, use_stdio,
         {env, [environment_entry(Entry) || Entry <- Environment]},
         {args, ["-noshell" | code_path_args()] ++ ["-eval", lists:flatten(Eval)]}]
    ),
    collect_output(Port, <<>>).

%% In a new `erl` process: call `Module:Function()`.
call_main(Module, Function) ->
    _ = (binary_to_atom(Module)):(binary_to_atom(Function))(),
    nil.

environment_entry({Name, {some, Value}}) ->
    {unicode:characters_to_list(Name), unicode:characters_to_list(Value)};
environment_entry({Name, none}) ->
    {unicode:characters_to_list(Name), false}.

%% Set an environment variable of this node. In the test run's own node,
%% set only variables that no other test reads, because every test and
%% every `erl` process the tests start share this environment.
set_environment_variable(Name, Value) ->
    true = os:putenv(unicode:characters_to_list(Name), unicode:characters_to_list(Value)),
    nil.

%% Remove an environment variable of this node. In the test run's own node,
%% remove only variables that no other test reads.
unset_environment_variable(Name) ->
    true = os:unsetenv(unicode:characters_to_list(Name)),
    nil.

%% ---------------------------------------------------------------------------
%% A server in its own `erl` process
%% ---------------------------------------------------------------------------

%% Start `Module:Function()` in a new `erl` process that halts with status 0
%% when the function returns. Requests go to its standard input, one per
%% line, and replies come back from its standard output, one per line.
%% Returns the port, which only the calling process can use.
start_server_in_new_vm(Module, Function) ->
    Erl = os:find_executable("erl"),
    Eval = io_lib:format("'~ts':'~ts'(), erlang:halt(0).", [Module, Function]),
    open_port(
        {spawn_executable, Erl},
        [exit_status, binary, stderr_to_stdout, use_stdio, {line, 65536},
         {args, ["-noshell" | code_path_args()] ++ ["-eval", lists:flatten(Eval)]}]
    ).

%% Send one request line and return the reply line. Returns
%% `{error, Output}` when the server exits or does not reply in 60 seconds.
send_server_request(Port, Request) ->
    true = port_command(Port, [Request, "\n"]),
    receive
        {Port, {data, {eol, Reply}}} -> {ok, Reply};
        {Port, {exit_status, Status}} -> {error, format({exited, Status})}
    after 60000 ->
        port_close(Port),
        {error, <<"timed out after 60 seconds">>}
    end.

%% Wait for the server to halt and return its exit status, or -1 after 60
%% seconds.
wait_for_server_exit(Port) ->
    receive
        {Port, {exit_status, Status}} -> Status
    after 60000 ->
        port_close(Port),
        -1
    end.

%% In the server: read one line from standard input, without the newline.
%% The end of the input is `{error, nil}`.
read_line() ->
    case io:get_line("") of
        eof -> {error, nil};
        {error, _Reason} -> {error, nil};
        Line -> {ok, string:trim(unicode:characters_to_binary(Line), trailing, "\n")}
    end.

collect_output(Port, Output) ->
    receive
        {Port, {data, Data}} -> collect_output(Port, <<Output/binary, Data/binary>>);
        {Port, {exit_status, Status}} -> {Status, Output}
    after 60000 ->
        port_close(Port),
        {-1, <<Output/binary, "\n[timed out after 60 seconds]">>}
    end.

code_path_args() ->
    lists:append([["-pa", Path] || Path <- code:get_path(), is_build_path(Path)]).

is_build_path(Path) ->
    string:find(Path, "/build/") =/= nomatch.

format(Term) ->
    unicode:characters_to_binary(io_lib:format("~tp", [Term])).

%% A name that no other call gives, in this run or an earlier run that left
%% files in `build`: the time in nanoseconds and a counter of this BEAM.
unique_name() ->
    Time = integer_to_binary(os:system_time(nanosecond)),
    Counter = integer_to_binary(erlang:unique_integer([positive])),
    <<Time/binary, "_", Counter/binary>>.

%% Put Directory first in the code path, with a broken beam file named
%% `<Module>.beam` in it. Returns nil.
add_broken_beam_first_in_path(Directory, Module) ->
    ok = filelib:ensure_path(Directory),
    Path = filename:join(Directory, <<Module/binary, ".beam">>),
    ok = file:write_file(Path, <<"not a beam file">>),
    true = code:add_patha(unicode:characters_to_list(Directory)),
    nil.

%% Remove Directory from the code path. Returns nil.
remove_from_path(Directory) ->
    _ = code:del_path(unicode:characters_to_list(Directory)),
    nil.
