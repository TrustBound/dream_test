-module(dream_test_gherkin_world_ffi).
-export([create_table/1, delete_table/1, insert/3, lookup/2, delete_key/2, unique_id/0, unsafe_coerce/1]).

%% Create a new ETS table with a unique name
create_table(Name) ->
    BinaryName = unicode:characters_to_binary(Name),
    AtomName = binary_to_atom(BinaryName, utf8),
    ets:new(AtomName, [set, public, {keypos, 1}]).

%% Delete an ETS table
delete_table(Table) ->
    ets:delete(Table),
    nil.

%% Insert a key-value pair
insert(Table, Key, Value) ->
    ets:insert(Table, {Key, Value}),
    nil.

%% Lookup a value by key, returns Option
lookup(Table, Key) ->
    case ets:lookup(Table, Key) of
        [{_, Value}] -> {some, Value};
        [] -> none
    end.

%% Delete a key from the table
delete_key(Table, Key) ->
    ets:delete(Table, Key),
    nil.

%% Generate a unique ID using erlang:unique_integer
unique_id() ->
    Int = erlang:unique_integer([positive]),
    integer_to_binary(Int).

%% Unsafe coercion - just returns the value wrapped in Ok
%% The caller is responsible for type safety
unsafe_coerce(Value) ->
    {ok, Value}.








