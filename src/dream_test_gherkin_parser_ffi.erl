-module(dream_test_gherkin_parser_ffi).
-export([read_file/1]).

%% Read a file and return its contents as a binary string
read_file(Path) ->
    case file:read_file(Path) of
        {ok, Binary} -> {ok, Binary};
        {error, _Reason} -> {error, nil}
    end.


