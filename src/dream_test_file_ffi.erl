-module(dream_test_file_ffi).
-export([read_file/1, write_file/2, delete_file/1, delete_files_matching/2]).

%% Read a file and return its contents as a binary string.
%% Returns {ok, Binary} on success, {error, FileError} on failure.
read_file(Path) ->
    case file:read_file(Path) of
        {ok, Binary} -> {ok, Binary};
        {error, Reason} -> {error, make_error(Path, Reason)}
    end.

%% Write content to a file, creating parent directories if needed.
%% Returns {ok, nil} on success, {error, FileError} on failure.
write_file(Path, Content) ->
    case filelib:ensure_dir(Path) of
        ok ->
            write_file_content(Path, Content);
        {error, Reason} ->
            {error, make_error(Path, Reason)}
    end.

write_file_content(Path, Content) ->
    case file:write_file(Path, Content) of
        ok -> {ok, nil};
        {error, Reason} -> {error, make_error(Path, Reason)}
    end.

%% Delete a file. Returns {ok, nil} on success or if file doesn't exist.
%% Returns {error, FileError} on other failures.
delete_file(Path) ->
    case file:delete(Path) of
        ok -> {ok, nil};
        {error, enoent} -> {ok, nil};
        {error, Reason} -> {error, make_error(Path, Reason)}
    end.

%% Delete all files in a directory matching the given extension.
%% Returns {ok, Count} where Count is the number of files deleted.
%% Returns {error, FileError} if directory access fails.
delete_files_matching(Directory, Extension) ->
    DirStr = binary_to_list(Directory),
    ExtStr = binary_to_list(Extension),
    Pattern = filename:join(DirStr, "*" ++ ExtStr),
    try
        Files = filelib:wildcard(Pattern),
        Count = delete_files_loop(Files, 0),
        {ok, Count}
    catch
        _:Reason ->
            {error, make_error(Directory, Reason)}
    end.

delete_files_loop([], Count) ->
    Count;
delete_files_loop([File | Rest], Count) ->
    case file:delete(File) of
        ok -> delete_files_loop(Rest, Count + 1);
        {error, _} -> delete_files_loop(Rest, Count)
    end.

%% Convert Erlang file error reasons to Gleam FileError type.
%% These constructors must match the Gleam type definition exactly.
make_error(Path, enoent) ->
    {not_found, Path};
make_error(Path, eacces) ->
    {permission_denied, Path};
make_error(Path, eisdir) ->
    {is_directory, Path};
make_error(Path, enospc) ->
    {no_space, Path};
make_error(Path, Reason) when is_atom(Reason) ->
    {file_system_error, Path, atom_to_binary(Reason, utf8)};
make_error(Path, Reason) ->
    {file_system_error, Path, list_to_binary(io_lib:format("~p", [Reason]))}.
