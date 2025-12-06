-module(dream_test_reporter_json_ffi).
-export([get_os/0, get_otp_version/0, get_gleam_version/0, get_timestamp_ms/0]).

%% Get the operating system type as a string
get_os() ->
    {OsFamily, _OsName} = os:type(),
    atom_to_binary(OsFamily, utf8).

%% Get the OTP release version
get_otp_version() ->
    list_to_binary(erlang:system_info(otp_release)).

%% Get the Gleam version from the gleam_stdlib application
%% Falls back to "unknown" if not available
get_gleam_version() ->
    case application:get_key(gleam_stdlib, vsn) of
        {ok, Version} -> list_to_binary(Version);
        undefined -> <<"unknown">>
    end.

%% Get current Unix timestamp in milliseconds
get_timestamp_ms() ->
    erlang:system_time(millisecond).





