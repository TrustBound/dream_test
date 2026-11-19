-module(dream_test_gherkin_discover_ffi).
-export([wildcard/1]).

%% Find files matching a glob pattern.
%% Uses Erlang's filelib:wildcard/1 which supports:
%%   - * matches any characters except /
%%   - ** matches any characters including /
%%   - ? matches a single character
%%   - [abc] matches a, b, or c
%%   - {a,b} matches a or b
%%
%% Returns: {ok, [Path, ...]}, or {error, <<"<class>:<reason>">>} for a
%% pattern that cannot be searched, for example "{a" with no closing brace.
wildcard(Pattern) ->
    try
        Files = filelib:wildcard(unicode:characters_to_list(Pattern)),
        {ok, [unicode:characters_to_binary(F) || F <- Files]}
    catch
        Class:Reason ->
            {error, unicode:characters_to_binary(
                      io_lib:format("~0tp:~0tp", [Class, Reason]))}
    end.
