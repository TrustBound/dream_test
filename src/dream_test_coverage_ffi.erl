-module(dream_test_coverage_ffi).
-export([
    start_if_supported/6,
    list_source_files/1,
    start_measuring/2,
    stop_measuring/2,
    stop_measuring_after/3,
    match_files/1,
    is_regular_file/1,
    erlang_function_last_line/1,
    system_time_ms/0,
    environment_variable/1,
    delete_html_pages/1
]).

%% Erlang side of `dream_test/coverage`.
%%
%% Every function that can fail returns a Gleam `Result`. Error tuples must
%% match the constructors of `dream_test/coverage.CoverageError` exactly.
%%
%% Lines are counted with the native line counters of the BEAM (Erlang/OTP
%% 27 and later, with the JIT): each measured module is recompiled with the
%% `line_coverage` and `force_line_counters` options and loaded again, and
%% `code:get_coverage(line, Module)` reads its counts. The counters belong
%% to each module, so more than one measurement can run in one BEAM, as long
%% as no module is in two of them.

%% The compile option that marks a module this file recompiled.
-define(MARKER, {dream_test_coverage, line_counters}).
%% The persistent term that holds the claims, and the name of their lock.
-define(CLAIMS, {?MODULE, claims}).

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

%% Start counting the lines of every module in `Modules`, a list of Gleam
%% `CoveredModule` records. `ErlangExternals` maps the source path of each
%% module to the `{Name, Line}` of each function that its Gleam source
%% declares with an `@external(erlang, ...)` attribute (see
%% `without_external_wrappers/2`).
%%
%% Native line counters need Erlang/OTP 27 or later with the JIT, and the
%% compiler application, which recompiles each measured module. Both are
%% checked before any module changes. `code:coverage_support/0` does not
%% exist before OTP 27.
%%
%% Then each module is claimed for this measurement, so two measurements
%% in one BEAM never count the same module. A claim lasts until
%% `stop_measuring/2`, or until the process that called this function ends. Then each module is recompiled
%% from the abstract code in its `.beam` file with native line counters and
%% loaded. A module that an earlier measurement already recompiled keeps its
%% counters, which are set to zero.
%%
%% Returns `{Measurement, SourcePaths}`: the measurement to pass to
%% `stop_measuring/2`, and the source paths of the modules that were built
%% from an Erlang source file. On an error, the claims are given back.
start_measuring(Modules, ErlangExternals) ->
    start_if_supported(
        erlang:function_exported(code, coverage_support, 0) andalso code:coverage_support(),
        code:ensure_loaded(compile),
        erlang:system_info(otp_release),
        erlang:system_info(emu_flavor),
        Modules,
        ErlangExternals
    ).

%% `start_measuring/2` for the facts it reads about the runtime. The tests
%% call it with the facts of a runtime that cannot count lines.
start_if_supported(false, _CompilerLoad, OtpRelease, EmulatorFlavor, _Modules, _ErlangExternals) ->
    {error, {native_coverage_unsupported, unicode:characters_to_binary(OtpRelease), atom_to_binary(EmulatorFlavor)}};
start_if_supported(true, {error, Reason}, _OtpRelease, _EmulatorFlavor, _Modules, _ErlangExternals) ->
    {error, {compiler_not_loaded, load_cause(Reason), format_reason(Reason)}};
start_if_supported(true, {module, compile}, _OtpRelease, _EmulatorFlavor, Modules, ErlangExternals) ->
    Measurement = make_ref(),
    case with_claims_lock(fun claim/2, [Measurement, Modules]) of
        ok -> measure_each(Measurement, Modules, ErlangExternals, []);
        {error, _} = Error -> Error
    end.

measure_each(Measurement, [], _ErlangExternals, ErlangSourcePaths) ->
    {ok, {Measurement, lists:reverse(ErlangSourcePaths)}};
measure_each(Measurement, [{covered_module, _ModuleName, SourcePath} = Covered | Rest], ErlangExternals, ErlangSourcePaths) ->
    case measure_module(Covered, maps:get(SourcePath, ErlangExternals)) of
        {ok, true} -> measure_each(Measurement, Rest, ErlangExternals, [SourcePath | ErlangSourcePaths]);
        {ok, false} -> measure_each(Measurement, Rest, ErlangExternals, ErlangSourcePaths);
        {error, _} = Error -> give_back(Measurement, Error)
    end.

give_back(Measurement, Error) ->
    ok = with_claims_lock(fun release/1, [Measurement]),
    Error.

%% Stop a measurement: read the line counts of every module, then give back
%% its claims. Both steps hold the claims lock, so no other measurement can
%% claim a module and set its counters to zero before they are read. Returns `{SourcePath, Lines}` for each module, where Lines
%% holds `{line_coverage, Line, Calls}` for every executable line, sorted.
%%
%% The modules keep their counters, so code that still runs them is still
%% counted, but nothing reads those counts. The next measurement of a
%% module sets them to zero.
stop_measuring(Measurement, Modules) ->
    stop_measuring_after(fun no_step/0, Measurement, Modules).

%% `stop_measuring/2` that calls `Step()` just before it reads the counters.
%% The tests use `Step` to start another measurement at that moment.
stop_measuring_after(Step, Measurement, Modules) ->
    with_claims_lock(fun read_then_release/3, [Step, Measurement, Modules]).

%% A measurement that does not hold every one of its modules was stopped
%% before, or its process ended and another measurement took one of them.
read_then_release(Step, Measurement, Modules) ->
    case holds_every_module(Measurement, Modules) of
        true -> read_and_release(Step, Measurement, Modules);
        false -> {error, session_already_finished}
    end.

read_and_release(Step, Measurement, Modules) ->
    Step(),
    Files = read_each(Modules, []),
    ok = release(Measurement),
    Files.

no_step() ->
    ok.

read_each([], Files) ->
    {ok, lists:reverse(Files)};
read_each([{covered_module, ModuleName, SourcePath} | Rest], Files) ->
    Module = binary_to_atom(ModuleName, utf8),
    case is_measured(Module) of
        true -> read_each(Rest, [{SourcePath, line_coverage(code:get_coverage(line, Module))} | Files]);
        false -> {error, {module_not_analysed, ModuleName, SourcePath, not_instrumented, format_reason(code:which(Module))}}
    end.

%% One entry per line, with the counts of a line added together: the
%% compiler can copy a line's code, and each copy has its own counter.
%% Line 0 is code with no source line.
line_coverage(Entries) ->
    Counts = lists:foldl(fun add_count/2, #{}, [Entry || {Line, _Calls} = Entry <- Entries, Line > 0]),
    [{line_coverage, Line, Calls} || {Line, Calls} <- lists:sort(maps:to_list(Counts))].

add_count({Line, Calls}, Counts) ->
    Counts#{Line => maps:get(Line, Counts, 0) + Calls}.

%% ---------------------------------------------------------------------------
%% One module
%% ---------------------------------------------------------------------------

%% Make one module count its lines. Returns `{ok, BuiltFromErlangSource}`.
measure_module({covered_module, ModuleName, SourcePath}, Externals) ->
    Module = binary_to_atom(ModuleName, utf8),
    case code:ensure_loaded(Module) of
        {module, Module} -> measure_loaded({Module, ModuleName, SourcePath}, Externals);
        {error, Reason} -> {error, {module_not_loaded, ModuleName, SourcePath, load_cause(Reason), format_reason(Reason)}}
    end.

%% A module that this file recompiled has the `?MARKER` compile option. A
%% module with line counters but no marker was recompiled by another tool,
%% such as `cover`, and that tool owns its counters.
measure_loaded({Module, ModuleName, SourcePath} = Names, Externals) ->
    case {is_measured(Module), code:get_coverage_mode(Module)} of
        {true, _Mode} -> with_abstract_code(fun restart_counters/2, Names, Externals);
        {false, none} -> with_abstract_code(fun add_counters/2, Names, Externals);
        {false, Mode} -> instrument_error(ModuleName, SourcePath, already_instrumented, {coverage_mode, Mode})
    end.

with_abstract_code(Next, {Module, ModuleName, SourcePath} = Names, Externals) ->
    case abstract_code(beam_lib:chunks(code:which(Module), [abstract_code])) of
        {ok, Forms} -> Next(Names, without_external_wrappers(Forms, Externals));
        {error, Cause, Reason} -> instrument_error(ModuleName, SourcePath, Cause, Reason)
    end.

abstract_code({ok, {_Module, [{abstract_code, {raw_abstract_v1, Forms}}]}}) ->
    {ok, Forms};
abstract_code({ok, {_Module, [{abstract_code, no_abstract_code}]}} = Reason) ->
    {error, no_debug_info, Reason};
abstract_code({error, beam_lib, {missing_backend, _BeamFile, _Backend}} = Reason) ->
    {error, no_debug_info, Reason};
abstract_code({error, beam_lib, {key_missing_or_invalid, _BeamFile, abstract_code}} = Reason) ->
    {error, encrypted_debug_info, Reason};
abstract_code(Reason) ->
    {error, debug_info_unreadable, Reason}.

restart_counters({Module, _ModuleName, _SourcePath}, Forms) ->
    ok = code:reset_coverage(Module),
    {ok, built_from_erlang_source(Forms)}.

add_counters({Module, ModuleName, SourcePath}, Forms) ->
    case compile:forms(Forms, [binary, return_errors, line_coverage, force_line_counters, ?MARKER]) of
        {ok, Module, Binary} -> load_counters(Module, ModuleName, SourcePath, Binary, Forms);
        Reason -> instrument_error(ModuleName, SourcePath, recompile_failed, Reason)
    end.

%% Loading new code turns the current code into old code, and a load when
%% old code already exists kills every process that still runs the old code.
%% So remove old code first, but only when no process runs it
%% (`code:soft_purge/1`), and fail when one does.
load_counters(Module, ModuleName, SourcePath, Binary, Forms) ->
    case code:soft_purge(Module) andalso code:load_binary(Module, code:which(Module), Binary) of
        {module, Module} -> {ok, built_from_erlang_source(Forms)};
        false -> instrument_error(ModuleName, SourcePath, old_code_in_use, {old_code_in_use, processes_running_old_code(Module)});
        {error, Reason} -> instrument_error(ModuleName, SourcePath, instrumented_load_failed, Reason)
    end.

processes_running_old_code(Module) ->
    [Process || Process <- erlang:processes(), erlang:check_process_code(Process, Module)].

instrument_error(ModuleName, SourcePath, Cause, Reason) ->
    {error, {module_not_instrumented, ModuleName, SourcePath, Cause, format_reason(Reason)}}.

%% Gleam compiles a function with an `@external(erlang, Module, Function)`
%% attribute to a wrapper that calls `Module:Function` with its own
%% parameters. Gleam code never calls the wrapper: the Gleam compiler calls
%% `Module:Function` directly, also for a reference to the function. So the
%% wrapper's line cannot run from Gleam, and the wrapper gets no counter:
%% every annotation in it is set to line 0, the line of code with no source
%% line (see `line_coverage/1`).
%%
%% A function form is a wrapper when both are true:
%%
%% - Its name and line are in `Externals`, the `{Name, Line}` of each
%%   function that the Gleam source declares with an `@external(erlang, ...)`
%%   attribute. The abstract code alone cannot tell the wrapper from a
%%   function written on one line whose body calls the external with the same
%%   parameters: Gleam compiles both to the same forms.
%% - It has exactly the shape that Gleam 1.19 gives the wrapper: one clause
%%   without guards, whose body is one remote call that passes the clause's
%%   parameters in the same order, with every part on the function's line.
%%
%% Every other form keeps its counters.
without_external_wrappers(Forms, Externals) ->
    [without_wrapper_lines(Form, Externals) || Form <- Forms].

without_wrapper_lines({function, Line, Name, _Arity, Clauses} = Form, Externals) ->
    case lists:member({atom_to_binary(Name), Line}, Externals) andalso is_wrapper(Line, Clauses) of
        true -> erl_parse:map_anno(fun no_source_line/1, Form);
        false -> Form
    end;
without_wrapper_lines(Form, _Externals) ->
    Form.

is_wrapper(Line, [{clause, Line, Parameters, [], [{call, Line, {remote, Line, {atom, _, _}, {atom, _, _}}, Parameters}]}]) ->
    true;
is_wrapper(_Line, _Clauses) ->
    false.

no_source_line(_Annotation) ->
    erl_anno:new(0).

is_measured(Module) ->
    erlang:module_loaded(Module)
        andalso lists:member(?MARKER, proplists:get_value(options, erlang:get_module_info(Module, compile), [])).

%% True when the module's abstract code was compiled from an Erlang source
%% file. The Erlang preprocessor puts a `-file` attribute that names the
%% `.erl` file first. Gleam before 1.19 writes `.erl` files and compiles them,
%% so its line numbers inside functions can drift. Gleam 1.19 and later
%% compile abstract code directly, and every `-file` attribute names the
%% `.gleam` file.
built_from_erlang_source(Forms) ->
    lists:any(fun is_erlang_file_attribute/1, Forms).

is_erlang_file_attribute({attribute, _, file, {File, _}}) ->
    filename:extension(File) =:= ".erl";
is_erlang_file_attribute(_Form) ->
    false.

%% `code:ensure_loaded/1` returns exactly these four errors.
load_cause(Reason) ->
    maps:get(Reason, #{nofile => module_not_built, on_load_failure => on_load_failed, badfile => bad_beam_file, embedded => embedded_mode}).

%% ---------------------------------------------------------------------------
%% Claims
%% ---------------------------------------------------------------------------

%% The claims map module names to `{Measurement, Process}`: the measurement
%% that counts the module, and the process that started it. It lives in a
%% persistent term, and a global lock on this node makes each read and
%% update of it one step.
%%
%% A claim whose process has ended is not a claim: `claim/2` lets another
%% measurement take its module, so a session that is never finished does not
%% hold its modules for the life of the BEAM.
with_claims_lock(Function, Arguments) ->
    Lock = {?CLAIMS, self()},
    true = global:set_lock(Lock, [node()]),
    try
        apply(Function, Arguments)
    after
        global:del_lock(Lock, [node()])
    end.

claim(Measurement, Modules) ->
    Claims = persistent_term:get(?CLAIMS, #{}),
    case [Covered || {covered_module, ModuleName, _} = Covered <- Modules, is_live(maps:get(ModuleName, Claims, none))] of
        [] -> persistent_term:put(?CLAIMS, maps:merge(Claims, #{ModuleName => {Measurement, self()} || {covered_module, ModuleName, _} <- Modules}));
        [{covered_module, ModuleName, SourcePath} | _] -> {error, {module_already_measured, ModuleName, SourcePath}}
    end.

is_live({_Measurement, Process}) -> is_process_alive(Process);
is_live(none) -> false.

release(Measurement) ->
    Claims = persistent_term:get(?CLAIMS, #{}),
    persistent_term:put(?CLAIMS, #{ModuleName => Claim || ModuleName := {Holder, _Process} = Claim <- Claims, Holder =/= Measurement}).

holds_every_module(Measurement, Modules) ->
    Claims = persistent_term:get(?CLAIMS, #{}),
    [] =:= [ModuleName || {covered_module, ModuleName, _} <- Modules, not is_held_by(Measurement, maps:get(ModuleName, Claims, none))].

is_held_by(Measurement, {Measurement, _Process}) -> true;
is_held_by(_Measurement, _Claim) -> false.

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

%% Delete the `files` folder of an HTML report and everything in it, before
%% `coverage.html_path` writes new pages. A folder that does not exist is
%% fine. Any other failure is an `html_delete_failed` error for the folder.
delete_html_pages(Path) ->
    case file:del_dir_r(Path) of
        ok -> {ok, nil};
        {error, enoent} -> {ok, nil};
        {error, Reason} ->
            {error, {html_delete_failed, Path, dream_test_file_ffi:make_error(Path, Reason)}}
    end.
