-module(dream_test_coverage_part_application).
-behaviour(application).
-export([hold_until_stop/1]).
-export([start/2, prep_stop/1, stop/1, wait_for_shutdown/0]).

%% An application that writes the LCOV part of a measured `erl` process
%% when the BEAM stops (see test/dream_test/coverage_child_measure.gleam).
%%
%% A main can stop the BEAM with `init:stop(1)` (`runner.exit_on_failure`
%% with a failure). The init process then stops every application before
%% it kills the other processes, and the application master calls
%% `prep_stop/1` and waits for it. So the part is written after the last
%% line of the main ran, and before the BEAM exits, for each way that the
%% main ends.

-define(APPLICATION, dream_test_coverage_part).

%% Start the application with the coverage session that it finishes.
hold_until_stop(Session) ->
    ok = application:load(
        {application, ?APPLICATION, [
            {description, "Writes the LCOV part of a measured erl process"},
            {vsn, "1"},
            {modules, [?MODULE]},
            {registered, []},
            {applications, [kernel, stdlib]},
            {mod, {?MODULE, Session}}
        ]}
    ),
    ok = application:start(?APPLICATION),
    nil.

start(normal, Session) ->
    {ok, spawn_link(?MODULE, wait_for_shutdown, []), Session}.

prep_stop(Session) ->
    'dream_test@coverage_child_measure':finish(Session),
    Session.

stop(_Session) ->
    ok.

%% The top process of the application. It has no work: the application
%% master stops it with an exit signal after `prep_stop/1`.
wait_for_shutdown() ->
    receive
    after infinity -> ok
    end.
