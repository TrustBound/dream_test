-module(dream_test_gherkin_discover_ffi).
-export([wildcard/1]).

%% Find files matching a glob pattern.
%% Uses Erlang's filelib:wildcard/1 which supports:
%%   - * matches any characters except /
%%   - ** matches any characters including /
%%   - ? matches a single character
%%   - [abc] matches a, b, or c
%%   - {a,b} matches a or b
wildcard(Pattern) ->
    PatternStr = unicode:characters_to_list(Pattern),
    Files = filelib:wildcard(PatternStr),
    [unicode:characters_to_binary(F) || F <- Files].

