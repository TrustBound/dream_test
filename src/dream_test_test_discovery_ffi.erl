-module(dream_test_test_discovery_ffi).

-export([discover_test_modules/1, call_tests/1]).

module_str_to_rel_gleam_path(ModuleStr) ->
    lists:map(fun(C) ->
                 case C of
                     $@ -> $/;
                     _ -> C
                 end
              end,
              ModuleStr)
    ++ ".gleam".

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
            lists:append(
                lists:map(fun(Dir) ->
                             filelib:wildcard(
                                 filename:join(Dir, GlobStr))
                          end,
                          Paths)),
        Modules =
            lists:filtermap(fun(Path) ->
                               %% The glob always ends in `.beam` (see
                               %% `to_beam_glob` in discover.gleam), so each
                               %% match is a `.beam` file.
                               ModuleStr = filename:basename(Path, ".beam"),
                               %% Avoid running stale compiled modules that no longer have a
                               %% corresponding .gleam file under ./test/.
                               case has_matching_test_source(ModuleStr) of
                                   false -> false;
                                   true ->
                                       Module = list_to_atom(ModuleStr),
                                       case code:ensure_loaded(Module) of
                                           {module, _} ->
                                               case erlang:function_exported(Module,
                                                                             tests,
                                                                             0)
                                               of
                                                   true ->
                                                       {true, list_to_binary(ModuleStr)};
                                                   false -> false
                                               end;
                                           _ -> false
                                       end
                               end
                            end,
                            Files),
        {ok, lists:usort(Modules)}
    catch
        _:_ ->
            {error, <<"discover_test_modules_failed">>}
    end.

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
