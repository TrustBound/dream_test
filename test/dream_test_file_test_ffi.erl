-module(dream_test_file_test_ffi).
-export([with_file_on_full_disk/1]).

%% Helpers for the tests of dream_test/file that need a full disk.

-define(WORK_DIRECTORY, "test/tmp/file_api_test").
-define(FILL_CHUNK_BYTES, 4096).

%% Call `Function(Path)`, where `Path` is a new file on a device that has
%% no free space, and return {Path, Result}. The device is real:
%% - Linux: /dev/full, which gives `enospc` for each write.
%% - macOS: a 1 MB HFS+ disk image, attached and filled. The image is
%%   detached and deleted after the call, also when the call crashes.
%% Crashes with a clear reason on other systems, so the test fails.
with_file_on_full_disk(Function) ->
    case os:type() of
        {unix, linux} -> {<<"/dev/full">>, Function(<<"/dev/full">>)};
        {unix, darwin} -> with_full_disk_image(Function);
        Other -> erlang:error({no_full_disk_on_this_system, Other})
    end.

with_full_disk_image(Function) ->
    Name = "full_disk_" ++ os:getpid() ++ "_"
        ++ integer_to_list(erlang:unique_integer([positive])),
    Directory = filename:absname(filename:join(?WORK_DIRECTORY, Name)),
    Image = filename:join(Directory, "full.dmg"),
    MountPoint = filename:join(Directory, "mount"),
    ok = filelib:ensure_path(MountPoint),
    try
        ok = command("hdiutil", ["create", "-quiet", "-size", "1m", "-fs", "HFS+",
                                 "-volname", "dtfull", Image]),
        ok = command("hdiutil", ["attach", "-quiet", "-nobrowse",
                                 "-mountpoint", MountPoint, Image]),
        try
            ok = fill(filename:join(MountPoint, "fill")),
            Path = unicode:characters_to_binary(filename:join(MountPoint, "file.txt")),
            {Path, Function(Path)}
        after
            detach(MountPoint)
        end
    after
        ok = file:del_dir_r(Directory)
    end.

%% Write chunks to a file until the device has no free space.
fill(Path) ->
    {ok, Device} = file:open(Path, [write, raw, binary]),
    Chunk = binary:copy(<<0>>, ?FILL_CHUNK_BYTES),
    Result = fill_loop(Device, Chunk),
    ok = file:close(Device),
    Result.

fill_loop(Device, Chunk) ->
    case file:write(Device, Chunk) of
        ok -> fill_loop(Device, Chunk);
        {error, enospc} -> ok;
        {error, Reason} -> {error, Reason}
    end.

%% Detach the image. A process can still have a file open on it for a short
%% time, so a second try forces the detach.
detach(MountPoint) ->
    case command("hdiutil", ["detach", "-quiet", MountPoint]) of
        ok -> ok;
        {error, _} -> ok = command("hdiutil", ["detach", "-quiet", "-force", MountPoint])
    end.

%% Run a program and give ok for exit status 0, or its output.
command(Program, Arguments) ->
    Executable = os:find_executable(Program),
    Port = open_port(
        {spawn_executable, Executable},
        [exit_status, binary, stderr_to_stdout, use_stdio, {args, Arguments}]
    ),
    collect(Port, <<>>).

collect(Port, Output) ->
    receive
        {Port, {data, Data}} -> collect(Port, <<Output/binary, Data/binary>>);
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, Status}} -> {error, {Status, Output}}
    end.
