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
        Class:Reason ->
            {error, crash_text(<<"cannot search for test modules: ">>,
                               Class, Reason)}
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
%% The value must have the shape of a `TestSuite`: a root with a name, a
%% list of tags and a list of nodes, where each node is a group, a test or
%% a hook. discover.gleam reads these fields outside any `try`, so a value
%% of another shape is an error here and never crashes the run.
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

checked_suite({root, _Seed, Name, Tags, Children} = Suite)
  when is_binary(Name) ->
    suite_with_nodes(is_text_list(Tags), first_bad_node(Children), Suite);
checked_suite(Other) ->
    {error, value_text(<<"tests() did not return a test suite: ">>, Other)}.

suite_with_nodes(false, _Bad, Suite) ->
    {error, value_text(<<"tests() did not return a test suite: ">>, Suite)};
suite_with_nodes(true, none, Suite) ->
    {ok, Suite};
suite_with_nodes(true, {bad, Node}, _Suite) ->
    {error,
     value_text(<<"tests() returned a node that is not a test, a group or a hook: ">>,
                Node)}.

%% The first node of a list, at any depth, that is not a test, a group or a
%% hook, as {bad, Node}, or none. The tail of a list that is not proper is
%% bad too.
first_bad_node([]) ->
    none;
first_bad_node([Node | Rest]) ->
    first_bad_or_next(bad_in_node(Node), Rest);
first_bad_node(Tail) ->
    {bad, Tail}.

first_bad_or_next(none, Rest) ->
    first_bad_node(Rest);
first_bad_or_next(Bad, _Rest) ->
    Bad.

bad_in_node({group, Name, Tags, Children} = Node) when is_binary(Name) ->
    bad_in_group(is_text_list(Tags), Node, Children);
bad_in_node({test, Name, Tags, _Kind, _Run, _Timeout, _Source} = Node)
  when is_binary(Name) ->
    bad_unless(is_text_list(Tags), Node);
bad_in_node({Hook, _Run})
  when Hook =:= before_all; Hook =:= before_each;
       Hook =:= after_each; Hook =:= after_all ->
    none;
bad_in_node(Node) ->
    {bad, Node}.

bad_in_group(true, _Node, Children) ->
    first_bad_node(Children);
bad_in_group(false, Node, _Children) ->
    {bad, Node}.

bad_unless(true, _Node) ->
    none;
bad_unless(false, Node) ->
    {bad, Node}.

is_text_list([]) ->
    true;
is_text_list([Text | Rest]) when is_binary(Text) ->
    is_text_list(Rest);
is_text_list(_Other) ->
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
