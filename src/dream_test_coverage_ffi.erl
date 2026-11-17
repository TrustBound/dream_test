-module(dream_test_coverage_ffi).
-export([
    start_cover/0,
    list_source_files/1,
    compile_module/2,
    analyse_module/2,
    match_files/1,
    is_regular_file/1,
    erlang_function_last_line/1,
    system_time_ms/0,
    environment_variable/1
]).

%% Erlang side of `dream_test/coverage`.
%%
%% Every function that can fail returns a Gleam `Result`. Error tuples must
%% match the constructors of `dream_test/coverage.CoverageError` exactly.
%% Calls into `cover` are wrapped in `try`, because `cover` raises (rather
%% than returns an error) for some inputs, such as a preloaded module.

%% Start the BEAM `cover` server.
%%
%% An already running cover server is an error: another tool owns it, and
%% sharing it would mix that tool's data into this report.
start_cover() ->
    try cover:start() of
        {ok, _Pid} ->
            {ok, nil};
        {error, {already_started, _Pid} = Reason} ->
            {error, {cover_start_failed, cover_already_running, format_reason(Reason)}};
        {error, Reason} ->
            {error, {cover_start_failed, cover_did_not_start, format_reason(Reason)}}
    catch
        Class:Reason ->
            {error, {cover_start_failed, cover_did_not_start, format_reason({Class, Reason})}}
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
%% `SourcePath` is only used in errors, so messages can name the source file.
%%
%% `cover:compile_beam/1` reads the abstract code from the loaded module's
%% `.beam` file, so no source compile happens. Gleam keeps that abstract code
%% in the `Dbgi` chunk.
compile_module(ModuleName, SourcePath) ->
    Module = binary_to_atom(ModuleName, utf8),
    case code:ensure_loaded(Module) of
        {module, Module} ->
            compile_loaded_module(ModuleName, SourcePath, Module);
        {error, Reason} ->
            {error, {module_not_loaded, ModuleName, SourcePath, load_cause(Reason), format_reason(Reason)}}
    end.

compile_loaded_module(ModuleName, SourcePath, Module) ->
    try cover:compile_beam(Module) of
        {ok, Module} ->
            {ok, nil};
        {error, Reason} ->
            {error, {module_not_instrumented, ModuleName, SourcePath, instrument_cause(Reason), format_reason(Reason)}}
    catch
        Class:Reason ->
            {error, {module_not_instrumented, ModuleName, SourcePath, unknown_instrument_error, format_reason({Class, Reason})}}
    end.

%% `code:ensure_loaded/1` returns exactly these four errors.
load_cause(nofile) -> module_not_built;
load_cause(on_load_failure) -> on_load_failed;
load_cause(badfile) -> bad_beam_file;
load_cause(embedded) -> embedded_mode.

instrument_cause({no_abstract_code, _BeamFile}) -> no_debug_info;
instrument_cause({{missing_backend, _Backend}, _BeamFile}) -> no_debug_info;
instrument_cause({encrypted_abstract_code, _BeamFile}) -> encrypted_debug_info;
instrument_cause({already_cover_compiled, _NoBeam, _Module}) -> already_instrumented;
instrument_cause(BeamFile) when is_list(BeamFile) -> instrumented_load_failed;
instrument_cause(_Other) -> unknown_instrument_error.

%% Return `{line_coverage, Line, Calls}` for every executable line, sorted by line.
%%
%% Line 0 entries are compiler-generated code with no source line; they are
%% dropped.
analyse_module(ModuleName, SourcePath) ->
    Module = binary_to_atom(ModuleName, utf8),
    try cover:analyse(Module, calls, line) of
        {ok, Entries} ->
            {ok, line_coverage(Entries)};
        {error, Reason} ->
            {error, {module_not_analysed, ModuleName, SourcePath, analysis_cause(Reason), format_reason(Reason)}}
    catch
        Class:Reason ->
            {error, {module_not_analysed, ModuleName, SourcePath, unknown_analysis_error, format_reason({Class, Reason})}}
    end.

analysis_cause({not_cover_compiled, _Module}) -> not_instrumented;
analysis_cause(_Other) -> unknown_analysis_error.

line_coverage(Entries) ->
    Lines = [{line_coverage, Line, Calls} || {{_Module, Line}, Calls} <- Entries, Line > 0],
    lists:keysort(2, Lines).

%% The regular files that match a wildcard pattern, sorted.
match_files(Pattern) ->
    Paths = filelib:wildcard(unicode:characters_to_list(Pattern)),
    lists:sort([unicode:characters_to_binary(Path) || Path <- Paths]).

is_regular_file(Path) ->
    filelib:is_regular(Path).

%% The line, counted from 1 at the start of `Source`, of the dot that ends
%% the first function in `Source`, after any attributes such as `-spec` and
%% `-doc`. `erl_scan` reads one form at a time by the rules of the running
%% OTP, so strings, triple-quoted strings, sigils, quoted atoms, character
%% literals and comments never hide or fake the end of a form. Returns
%% `{error, nil}` when the first form that is not an attribute is not a
%% function, or when the source ends or cannot be scanned before its dot.
erlang_function_last_line(Source) ->
    Chars = unicode:characters_to_list(Source),
    function_form(erl_scan:tokens([], Chars, 1)).

function_form({more, Continuation}) ->
    function_form(erl_scan:tokens(Continuation, eof, 1));
function_form({done, {ok, [{'-', _} | _], EndLine}, Rest}) ->
    function_form(erl_scan:tokens([], Rest, EndLine));
function_form({done, {ok, [{atom, _, _}, {'(', _} | _] = Tokens, _}, _Rest}) ->
    form_end(lists:last(Tokens));
function_form(_NotAFunction) ->
    {error, nil}.

form_end({dot, Line}) -> {ok, Line};
form_end(_LastToken) -> {error, nil}.

format_reason(Reason) ->
    unicode:characters_to_binary(io_lib:format("~tp", [Reason])).

%% The time now, in milliseconds since the Unix epoch, for the Cobertura
%% `timestamp` attribute.
system_time_ms() ->
    os:system_time(millisecond).

%% The value of an environment variable, for
%% `runner.coverage_from_environment`. An unset variable is `{error, nil}`.
environment_variable(Name) ->
    case os:getenv(unicode:characters_to_list(Name)) of
        false -> {error, nil};
        Value -> {ok, unicode:characters_to_binary(Value)}
    end.
