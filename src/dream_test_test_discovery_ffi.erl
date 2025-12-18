-module(dream_test_test_discovery_ffi).
-export([discover_test_modules/1, call_tests/1]).

%% Discover compiled test modules matching a beam filename glob.
%%
%% - beam_glob: a glob like "unit@*_test.beam" (basename pattern)
%%
%% Returns: {ok, [<<"unit@foo_test">>, ...]} or {error, <<"message">>}
discover_test_modules(BeamGlob) ->
    try
        GlobStr = binary_to_list(BeamGlob),
        Paths = code:get_path(),
        Files = lists:append(lists:map(fun(Dir) ->
            filelib:wildcard(filename:join(Dir, GlobStr))
        end, Paths)),
        Modules = lists:filtermap(fun(Path) ->
            File = filename:basename(Path),
            case lists:suffix(".beam", File) of
                false -> false;
                true ->
                    ModuleStr = lists:sublist(File, length(File) - 5),
                    case lists:suffix("_test", ModuleStr) of
                        false -> false;
                        true ->
                            Module = list_to_atom(ModuleStr),
                            case code:ensure_loaded(Module) of
                                {module, _} ->
                                    case erlang:function_exported(Module, tests, 0) of
                                        true -> {true, list_to_binary(ModuleStr)};
                                        false -> false
                                    end;
                                _ -> false
                            end
                    end
            end
        end, Files),
        {ok, lists:usort(Modules)}
    catch
        _:_ -> {error, <<"discover_test_modules_failed">>}
    end.

%% Dynamically call tests() on a discovered module name.
%%
%% Returns: {ok, Suite} or {error, <<"message">>}
call_tests(ModuleName) ->
    try
        Module = list_to_atom(binary_to_list(ModuleName)),
        case erlang:function_exported(Module, tests, 0) of
            true -> {ok, Module:tests()};
            false -> {error, <<"no_tests_function">>}
        end
    catch
        _:_ -> {error, <<"call_tests_failed">>}
    end.


