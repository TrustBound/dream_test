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
    %% project root, and test sources live under ./test/.
    case file:get_cwd() of
        {ok, Cwd} ->
            Rel = module_str_to_rel_gleam_path(ModuleStr),
            Path = filename:join([Cwd, "test", Rel]),
            filelib:is_file(Path);
        _ ->
            %% If we can't determine the CWD, fall back to the older behavior.
            true
    end.

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
                               File = filename:basename(Path),
                               case lists:suffix(".beam", File) of
                                   false -> false;
                                   true ->
                                       ModuleStr = lists:sublist(File, length(File) - 5),
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
                               end
                            end,
                            Files),
        {ok, lists:usort(Modules)}
    catch
        _:_ ->
            {error, <<"discover_test_modules_failed">>}
    end.

%% Dynamically call tests() on a discovered module name.
%%
%% Returns: {ok, Suite} or {error, <<"message">>}
call_tests(ModuleName) ->
    try
        Module = list_to_atom(binary_to_list(ModuleName)),
        case erlang:function_exported(Module, tests, 0) of
            true ->
                {ok, Module:tests()};
            false ->
                {error, <<"no_tests_function">>}
        end
    catch
        _:_ ->
            {error, <<"call_tests_failed">>}
    end.
