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
%% Returns: {ok, [<<"unit@foo_test">>, ...]} or {error, <<"message">>}
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
        _:_ ->
            {error, <<"discover_test_modules_failed">>}
    end.

%% The module name of a `.beam` file that discovery keeps, as
%% `{true, Name}`, or `false`. The glob always ends in `.beam` (see
%% `to_beam_glob` in discover.gleam), so each match is a `.beam` file.
%% Discovery skips stale compiled modules that no longer have a
%% corresponding .gleam file under ./test/, and modules without tests/0.
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
test_module_loaded(_NotLoaded, _Module, _ModuleStr) ->
    false.

test_module_exports_tests(true, ModuleStr) ->
    {true, list_to_binary(ModuleStr)};
test_module_exports_tests(false, _ModuleStr) ->
    false.

%% Dynamically call tests() on a discovered module name. Discovery keeps
%% only modules that export tests/0.
%%
%% Returns: {ok, Suite} or {error, <<"message">>}
call_tests(ModuleName) ->
    try
        Module = list_to_atom(binary_to_list(ModuleName)),
        {ok, Module:tests()}
    catch
        _:_ ->
            {error, <<"call_tests_failed">>}
    end.
