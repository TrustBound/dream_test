-module(snippets_doc_blocks_ffi).
-export([wildcard/2, git_show/2]).

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
