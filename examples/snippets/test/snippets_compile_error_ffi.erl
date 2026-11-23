-module(snippets_compile_error_ffi).
-export([compile_package/3]).

%% `gleam compile-package --target erlang --package Package --out Out --lib
%% Lib` in the current folder: {ok, {ExitStatus, Output}}, with stdout and
%% stderr together, or {error, nil} when gleam is not on the PATH. The
%% command uses only the compiled packages under Lib, so it needs no
%% network.
compile_package(Package, Out, Lib) ->
    compile_package_with(os:find_executable("gleam"), Package, Out, Lib).

compile_package_with(false, _Package, _Out, _Lib) ->
    {error, nil};
compile_package_with(Gleam, Package, Out, Lib) ->
    Port = open_port({spawn_executable, Gleam},
                     [{args, ["compile-package", "--target", "erlang",
                              "--package", Package, "--out", Out,
                              "--lib", Lib]},
                      binary, exit_status, stderr_to_stdout]),
    {ok, collect(Port, <<>>)}.

collect(Port, Text) ->
    receive
        {Port, {data, Data}} -> collect(Port, <<Text/binary, Data/binary>>);
        {Port, {exit_status, Status}} -> {Status, Text}
    end.
