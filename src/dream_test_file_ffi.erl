-module(dream_test_file_ffi).
-export([read_file/1, write_file/2, delete_file/1, delete_files_matching/2]).
%% Also used by dream_test_coverage_ffi, so its errors match `FileError`.
-export([make_error/2]).

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

%% Delete all files in a directory whose names end with the given extension.
%% Returns {ok, Count} where Count is the number of files deleted.
%% A missing directory has no files, so it gives {ok, 0}.
%% Returns {error, FileError} if the directory cannot be listed.
%%
%% The directory is listed and the names are compared as text. No wildcard
%% pattern is made, so characters such as `{`, `[`, `*` and `?` in the
%% directory name have no special meaning.
delete_files_matching(Directory, Extension) ->
    case file:list_dir(Directory) of
        {ok, Names} ->
            Matching = [filename:join(Directory, Name)
                        || Name <- Names, has_extension(Name, Extension)],
            {ok, delete_files_loop(Matching, 0)};
        {error, enoent} ->
            {ok, 0};
        {error, Reason} ->
            {error, make_error(Directory, Reason)}
    end.

has_extension(Name, Extension) ->
    NameBinary = unicode:characters_to_binary(Name),
    NameSize = byte_size(NameBinary),
    ExtensionSize = byte_size(Extension),
    NameSize >= ExtensionSize andalso
        binary:part(NameBinary, NameSize - ExtensionSize, ExtensionSize)
            =:= Extension.

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
