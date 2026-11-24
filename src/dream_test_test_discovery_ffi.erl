-module(dream_test_test_discovery_ffi).

-export([discover_test_modules/1, call_tests/1]).

module_str_to_rel_gleam_path(ModuleStr) ->
    [path_char(C) || C <- ModuleStr] ++ ".gleam".

%% Gleam writes the `/` of a module path as `@` in the module name.
path_char($@) ->
    $/;
path_char(C) ->
    C.

has_matching_test_source(ModuleStr) ->
    %% Discovery is used from `gleam test` runners; in that context the CWD is the
    %% project root, and test sources live under ./test/. The path is relative
    %% to the CWD, so a CWD that cannot be read gives no match.
    filelib:is_file(filename:join("test", module_str_to_rel_gleam_path(ModuleStr))).

%% Discover compiled test modules matching a beam filename glob.
%%
%% - beam_glob: a glob like "unit@*_test.beam" (basename pattern)
%%
%% Returns: {ok, [Found, ...]} or {error, <<"message">>}. Each Found is
%% {ok, <<"unit@foo_test">>} for a module that loads and exports tests/0,
%% or {error, <<"unit@foo_test: cannot load the module: <reason>">>} for a
%% module with a test source whose beam file does not load.
discover_test_modules(BeamGlob) ->
    try
        GlobStr = binary_to_list(BeamGlob),
        Paths = code:get_path(),
        Files =
            [File
             || Dir <- Paths,
                File <- filelib:wildcard(filename:join(Dir, GlobStr))],
        Modules = lists:filtermap(fun test_module/1, Files),
        {ok, lists:usort(Modules)}
    catch
        Class:Reason ->
            {error, crash_text(<<"cannot search for test modules: ">>,
                               Class, Reason)}
    end.

%% What discovery finds for a `.beam` file: `{true, {ok, Name}}`,
%% `{true, {error, Text}}` when the module does not load, or `false`. The
%% glob always ends in `.beam` (see `to_beam_glob` in discover.gleam), so
%% each match is a `.beam` file. Discovery skips stale compiled modules
%% that no longer have a corresponding .gleam file under ./test/, and
%% modules without tests/0. A module that has a test source but does not
%% load is an error, so a broken test module never makes a run pass.
test_module(Path) ->
    ModuleStr = filename:basename(Path, ".beam"),
    test_module_with_source(has_matching_test_source(ModuleStr), ModuleStr).

test_module_with_source(false, _ModuleStr) ->
    false;
test_module_with_source(true, ModuleStr) ->
    Module = list_to_atom(ModuleStr),
    test_module_loaded(code:ensure_loaded(Module), Module, ModuleStr).

test_module_loaded({module, _}, Module, ModuleStr) ->
    test_module_exports_tests(erlang:function_exported(Module, tests, 0),
                              ModuleStr);
test_module_loaded({error, Reason}, _Module, ModuleStr) ->
    Name = unicode:characters_to_binary(ModuleStr),
    {true, {error, value_text(<<Name/binary, ": cannot load the module: ">>,
                              Reason)}}.

test_module_exports_tests(true, ModuleStr) ->
    {true, {ok, list_to_binary(ModuleStr)}};
test_module_exports_tests(false, _ModuleStr) ->
    false.

%% Dynamically call tests() on a discovered module name. Discovery keeps
%% only modules that export tests/0.
%%
%% The value must have the shape of a `dream_test/suite.TestSuite`: a name
%% and a list of parts, where each part holds the `TestInfo` of its tests
%% and the functions that run them. Every suite has this one type, whatever
%% context its tests get, so a suite from unit_context or a Gherkin feature
%% loads like any other suite. The runner reads these fields outside any
%% `try`, so a value of another shape is an error here and never crashes
%% the run.
%%
%% Returns: {ok, Suite} or {error, <<"message">>}
call_tests(ModuleName) ->
    Module = binary_to_atom(ModuleName),
    try Module:tests() of
        Suite -> checked_suite(Suite)
    catch
        Class:Reason ->
            {error, crash_text(<<"tests() crashed: ">>, Class, Reason)}
    end.

checked_suite({test_suite, Name, Parts} = Suite) when is_binary(Name) ->
    checked(all_parts(Parts), Suite);
checked_suite(Other) ->
    checked(false, Other).

checked(true, Suite) ->
    {ok, Suite};
checked(false, Value) ->
    {error, value_text(<<"tests() did not return a test suite: ">>, Value)}.

%% True when the value is a proper list of parts: a place, the `TestInfo`
%% of each test, and the functions that give the tests and run them.
all_parts([]) ->
    true;
all_parts([{part, {place, _Groups, _Source}, Tests, TestsAt, Run} | Rest])
  when is_function(TestsAt, 1), is_function(Run, 2) ->
    all_test_infos(Tests) andalso all_parts(Rest);
all_parts(_Other) ->
    false.

all_test_infos([]) ->
    true;
all_test_infos([{test_info, Name, _Groups, _Tags, _Kind, _Source} | Rest])
  when is_binary(Name) ->
    all_test_infos(Rest);
all_test_infos(_Other) ->
    false.

%% `<Prefix><Class>:<Reason>`, as `sandbox.run_catching` writes a crash,
%% on one line.
crash_text(Prefix, Class, Reason) ->
    Text = unicode:characters_to_binary(
             io_lib:format("~0tp:~0tp", [Class, Reason])),
    <<Prefix/binary, Text/binary>>.

%% `<Prefix><Value>`, on one line.
value_text(Prefix, Value) ->
    Text = unicode:characters_to_binary(io_lib:format("~0tp", [Value])),
    <<Prefix/binary, Text/binary>>.
