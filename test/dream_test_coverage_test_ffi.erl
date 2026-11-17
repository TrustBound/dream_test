-module(dream_test_coverage_test_ffi).
-export([
    run_in_peer/1,
    run_in_embedded_peer/1,
    run_main_in_new_vm/2,
    reset_child_output/0,
    child_project/1,
    add_source/2,
    compile_source/2,
    add_damaged_beam/1,
    make_unreadable/1,
    stub_cover/1,
    stop_cover/0,
    format/1
]).
%% Called inside the child node only.
-export([prepare_child/1, preload_build_modules/0, write_native_counts/0]).

%% Helpers for the coverage tests.
%%
%% `cover` runs once per BEAM instance, and this test run already uses it to
%% measure dream_test itself. So tests that start coverage run in a child
%% node. Each child starts with native line counters (`+JPcover
%% line_counters`) and reloads dream_test's own coverage modules with the
%% `line_coverage` compile option. The child's `cover` then measures only the
%% test's fixture code, while the native counters measure dream_test's
%% coverage code, including the lines that run before `cover` starts. After
%% the test, the child writes those counts as an LCOV file into
%% build/coverage/parts/, and dream_test's own run merges them with
%% `coverage.merge_lcov`.

-define(PARTS_DIRECTORY, "build/coverage/parts").
-define(PROJECTS_DIRECTORY, "build/coverage/child_projects").

%% The modules measured with native counters, and their source files.
self_modules() ->
    [
        {'dream_test@coverage', "src/dream_test/coverage.gleam"},
        {'dream_test@coverage@report', "src/dream_test/coverage/report.gleam"},
        {'dream_test@coverage@format', "src/dream_test/coverage/format.gleam"},
        {'dream_test@coverage@json_summary', "src/dream_test/coverage/json_summary.gleam"},
        {'dream_test@coverage@cobertura', "src/dream_test/coverage/cobertura.gleam"},
        {'dream_test@coverage@markdown', "src/dream_test/coverage/markdown.gleam"},
        {'dream_test@coverage@html', "src/dream_test/coverage/html.gleam"},
        {'dream_test@reporters@coverage', "src/dream_test/reporters/coverage.gleam"},
        {dream_test_coverage_ffi, "src/dream_test_coverage_ffi.erl"}
    ].

%% Delete the LCOV parts and child projects of an earlier run.
reset_child_output() ->
    ok = delete_directory(?PARTS_DIRECTORY),
    ok = delete_directory(?PROJECTS_DIRECTORY),
    nil.

delete_directory(Directory) ->
    case file:del_dir_r(Directory) of
        ok -> ok;
        {error, enoent} -> ok
    end.

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
    Args = ["+JPcover", "line_counters" | ExtraArgs] ++ code_path_args(),
    case peer:start_link(#{connection => standard_io, args => Args}) of
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
    ok = peer:call(Peer, ?MODULE, write_native_counts, [], 60000),
    peer:stop(Peer),
    Result.

%% In the child: remember the project root, load every build module when the
%% child runs in embedded mode, and reload the measured modules with native
%% line counters.
prepare_child(Root) ->
    persistent_term:put({?MODULE, root}, Root),
    case code:get_mode() of
        embedded -> preload_build_modules();
        interactive -> ok
    end,
    lists:foreach(fun({Module, _Source}) -> load_with_line_counters(Module) end, self_modules()).

%% Embedded mode only loads the modules of the boot script (kernel and
%% stdlib), so load the build modules, the compiler (for line counters) and
%% tools (for cover) by hand.
preload_build_modules() ->
    BuildPaths = [Path || Path <- code:get_path(), is_build_path(Path)],
    OtpPaths = filelib:wildcard(filename:join([code:root_dir(), "lib", "{compiler,tools}-*", "ebin"])),
    Beams = lists:append([filelib:wildcard(filename:join(Path, "*.beam")) || Path <- BuildPaths ++ OtpPaths]),
    lists:foreach(fun(Beam) -> code:load_abs(filename:rootname(Beam)) end, Beams).

load_with_line_counters(Module) ->
    Beam = code:which(Module),
    {ok, {Module, [{abstract_code, {raw_abstract_v1, Forms}}]}} = beam_lib:chunks(Beam, [abstract_code]),
    {ok, Module, Binary} = compile:forms(Forms, [binary, debug_info, line_coverage, return_errors]),
    {module, Module} = code:load_binary(Module, Beam, Binary),
    line_counters = code:get_coverage_mode(Module),
    ok.

%% In the child: write the native line counts as one LCOV file.
write_native_counts() ->
    Root = persistent_term:get({?MODULE, root}),
    Name = io_lib:format("~s_~b.info", [os:getpid(), erlang:unique_integer([positive])]),
    Path = filename:join([Root, ?PARTS_DIRECTORY, Name]),
    ok = filelib:ensure_dir(Path),
    Records = [lcov_record(Module, Source) || {Module, Source} <- self_modules()],
    ok = file:write_file(Path, Records).

lcov_record(Module, Source) ->
    Counts = lists:foldl(fun add_count/2, #{}, code:get_coverage(line, Module)),
    Lines = lists:sort(maps:to_list(Counts)),
    [
        "TN:\nSF:", Source, "\n",
        [io_lib:format("DA:~b,~b~n", [Line, Calls]) || {Line, Calls} <- Lines],
        "end_of_record\n"
    ].

%% The same line can have more than one counter (for example, one per clause);
%% line 0 is code with no source line.
add_count({0, _Calls}, Counts) -> Counts;
add_count({Line, Calls}, Counts) -> maps:update_with(Line, fun(Old) -> Old + Calls end, Calls, Counts).

%% ---------------------------------------------------------------------------
%% Building broken projects inside a child
%% ---------------------------------------------------------------------------

%% Create an empty project (src/ and ebin/) and make it the working
%% directory. Its ebin/ is added to the code path.
child_project(Name) ->
    Root = persistent_term:get({?MODULE, root}),
    Unique = io_lib:format("~s_~s_~b", [Name, os:getpid(), erlang:unique_integer([positive])]),
    Directory = filename:join([Root, ?PROJECTS_DIRECTORY, Unique]),
    ok = filelib:ensure_path(filename:join(Directory, "src")),
    ok = filelib:ensure_path(filename:join(Directory, "ebin")),
    true = code:add_patha(filename:join(Directory, "ebin")),
    ok = file:set_cwd(Directory),
    unicode:characters_to_binary(Directory).

%% Write src/File in the current project.
add_source(File, Text) ->
    ok = file:write_file(filename:join("src", File), Text),
    nil.

%% Compile src/File into ebin/ with debug information of a given kind.
compile_source(File, Kind) ->
    Source = unicode:characters_to_list(filename:join("src", File)),
    {ok, Module, Binary} = compile:file(Source, [binary, return_errors | debug_options(Kind)]),
    ok = file:write_file(filename:join("ebin", atom_to_list(Module) ++ ".beam"), Binary),
    nil.

debug_options(<<"debug_info">>) -> [debug_info];
debug_options(<<"no_debug_info">>) -> [];
debug_options(<<"encrypted_debug_info">>) -> [{debug_info_key, "secret"}];
debug_options(<<"missing_debug_info_backend">>) -> [{debug_info, {no_such_backend, []}}].

%% Write ebin/Module.beam with bytes that are not a .beam file.
add_damaged_beam(Module) ->
    ok = file:write_file(filename:join("ebin", <<Module/binary, ".beam">>), <<"not a beam file">>),
    nil.

%% Take away every permission on src/File in the current project, so reading
%% it fails.
make_unreadable(File) ->
    ok = file:change_mode(filename:join("src", File), 8#000),
    nil.

%% Replace `cover` with a stub that behaves in one broken way.
stub_cover(Kind) ->
    Forms = [{attribute, 1, module, cover} | stub_functions(Kind)],
    {ok, cover, Binary} = compile:forms(Forms, [binary, return_errors]),
    code:unstick_mod(cover),
    code:purge(cover),
    {module, cover} = code:load_binary(cover, "stub_cover.beam", Binary),
    nil.

stub_functions(<<"start_returns_error">>) ->
    exports([{start, 0}]) ++ [function(start, [], error_tuple())];
stub_functions(<<"start_raises">>) ->
    exports([{start, 0}]) ++ [function(start, [], raise())];
stub_functions(<<"compile_returns_error">>) ->
    exports([{start, 0}, {compile_beam, 1}])
        ++ [function(start, [], ok_tuple()), function(compile_beam, [{var, 1, '_'}], error_tuple())];
stub_functions(<<"compile_raises">>) ->
    exports([{start, 0}, {compile_beam, 1}])
        ++ [function(start, [], ok_tuple()), function(compile_beam, [{var, 1, '_'}], raise())];
stub_functions(<<"analyse_returns_error">>) ->
    exports([{analyse, 3}]) ++ [function(analyse, [{var, 1, '_'}, {var, 1, '_'}, {var, 1, '_'}], error_tuple())];
stub_functions(<<"analyse_raises">>) ->
    exports([{analyse, 3}]) ++ [function(analyse, [{var, 1, '_'}, {var, 1, '_'}, {var, 1, '_'}], raise())].

exports(Functions) -> [{attribute, 1, export, Functions}].
function(Name, Arguments, Body) ->
    {function, 1, Name, length(Arguments), [{clause, 1, Arguments, [], [Body]}]}.
error_tuple() -> {tuple, 1, [{atom, 1, error}, {atom, 1, boom}]}.
ok_tuple() -> {tuple, 1, [{atom, 1, ok}, {call, 1, {atom, 1, self}, []}]}.
raise() -> {call, 1, {atom, 1, error}, [{atom, 1, boom}]}.

%% Stop the real `cover` server.
stop_cover() ->
    cover:stop(),
    nil.

%% ---------------------------------------------------------------------------
%% Running a main in a new `erl` process
%% ---------------------------------------------------------------------------

%% Run `Module:Function()` in a new `erl` process, then halt with status 0.
%% Returns {ExitStatus, Output}, with stdout and stderr together.
run_main_in_new_vm(Module, Function) ->
    Erl = os:find_executable("erl"),
    Eval = io_lib:format("'~ts':'~ts'(), erlang:halt(0).", [Module, Function]),
    Port = open_port(
        {spawn_executable, Erl},
        [exit_status, binary, stderr_to_stdout, use_stdio,
         {args, ["-noshell" | code_path_args()] ++ ["-eval", lists:flatten(Eval)]}]
    ),
    collect_output(Port, <<>>).

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
