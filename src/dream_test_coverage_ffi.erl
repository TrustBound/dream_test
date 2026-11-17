-module(dream_test_coverage_ffi).
-export([
    start_cover/0,
    list_source_files/1,
    compile_module/1,
    analyse_module/1
]).

%% Erlang side of `dream_test/coverage`.
%%
%% Every function returns a Gleam `Result`. Error tuples must match the
%% constructors of `dream_test/coverage.CoverageError` exactly.

%% Start the BEAM `cover` server.
%%
%% An already running cover server is an error: another tool owns it, and
%% sharing it would mix that tool's data into this report.
start_cover() ->
    case cover:start() of
        {ok, _Pid} -> {ok, nil};
        {error, Reason} -> {error, {cover_start_failed, format_reason(Reason)}}
    end.

%% List the `.gleam` and `.erl` files under a source directory.
%%
%% Paths are relative to the directory and sorted.
list_source_files(Directory) ->
    case filelib:is_dir(Directory) of
        true -> {ok, source_files_in(Directory)};
        false -> {error, {source_directory_not_found, Directory}}
    end.

source_files_in(Directory) ->
    DirectoryString = unicode:characters_to_list(Directory),
    Gleam = filelib:wildcard("**/*.gleam", DirectoryString),
    Erlang = filelib:wildcard("**/*.erl", DirectoryString),
    lists:sort([unicode:characters_to_binary(Path) || Path <- Gleam ++ Erlang]).

%% Load a module and replace it with a cover-compiled version.
%%
%% `cover:compile_beam/1` reads the abstract code from the loaded module's
%% `.beam` file, so no source compile happens. Gleam keeps that abstract code
%% in the `Dbgi` chunk.
compile_module(ModuleName) ->
    Module = binary_to_atom(ModuleName, utf8),
    case code:ensure_loaded(Module) of
        {module, Module} -> compile_loaded_module(ModuleName, Module);
        {error, Reason} -> {error, {module_not_loaded, ModuleName, format_reason(Reason)}}
    end.

compile_loaded_module(ModuleName, Module) ->
    case cover:compile_beam(Module) of
        {ok, Module} -> {ok, nil};
        {error, Reason} -> {error, {module_compile_failed, ModuleName, format_reason(Reason)}}
    end.

%% Return `{line_coverage, Line, Calls}` for every executable line, sorted by line.
%%
%% Line 0 entries are compiler-generated code with no source line; they are
%% dropped.
analyse_module(ModuleName) ->
    Module = binary_to_atom(ModuleName, utf8),
    case cover:analyse(Module, calls, line) of
        {ok, Entries} -> {ok, line_coverage(Entries)};
        {error, Reason} -> {error, {analysis_failed, ModuleName, format_reason(Reason)}}
    end.

line_coverage(Entries) ->
    Lines = [{line_coverage, Line, Calls} || {{_Module, Line}, Calls} <- Entries, Line > 0],
    lists:keysort(2, Lines).

format_reason(Reason) ->
    unicode:characters_to_binary(io_lib:format("~tp", [Reason])).
