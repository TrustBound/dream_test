-module(snippets_doc_blocks_ffi).
-export([
    wildcard/2,
    git_show/2,
    exports_tests/1,
    run_main_in_new_vm/1,
    run_main_in_new_vm_with_coverage_lock/1
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
%% with stdout and stderr together. A process that does not stop in 50
%% seconds is closed, and the status is -1.
run_main_in_new_vm(Module) ->
    Eval = io_lib:format("'~ts':main(), init:stop(0).", [Module]),
    Port = open_port(
        {spawn_executable, os:find_executable("erl")},
        [exit_status, binary, stderr_to_stdout, use_stdio,
         {args, ["-noshell" | code_path_args()] ++ ["-eval", lists:flatten(Eval)]}]
    ),
    collect_output(Port, <<>>).

%% `run_main_in_new_vm/1`, while this process holds the coverage lock.
run_main_in_new_vm_with_coverage_lock(Module) ->
    snippets_coverage_lock_ffi:with_lock(fun() -> run_main_in_new_vm(Module) end).

collect_output(Port, Output) ->
    receive
        {Port, {data, Data}} -> collect_output(Port, <<Output/binary, Data/binary>>);
        {Port, {exit_status, Status}} -> {Status, Output}
    after 50000 ->
        port_close(Port),
        {-1, <<Output/binary, "\n[timed out after 50 seconds]">>}
    end.

code_path_args() ->
    lists:append([["-pa", Path] || Path <- code:get_path(), is_build_path(Path)]).

is_build_path(Path) ->
    string:find(Path, "/build/") =/= nomatch.
