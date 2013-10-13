-module(riak_sysmon_schema_tests).

-include_lib("eunit/include/eunit.hrl").
-compile(export_all).

-define(DEFAULT_PROCESS_LIMIT, 30).
-define(DEFAULT_PORT_LIMIT, 2).
-define(DEFAULT_GC_MS_LIMIT, 0).
-define(DEFAULT_HEAP_WORD_LIMIT, 40111000).
-define(DEFAULT_BUSY_PORT, true).
-define(DEFAULT_BUSY_DIST_PORT, true).
-define(PLUS1(X), (X+1)).

%% basic schema test will check to make sure that all defaults from the schema
%% make it into the generated app.config
basic_schema_test() ->
    %% The defaults are defined in ../priv/riak_sysmon.schema. it is the file under test. 
    Config = cuttlefish_unit:generate_config("../priv/riak_sysmon.schema", []),

    cuttlefish_unit:assert_config(Config, "riak_sysmon.process_limit", ?DEFAULT_PROCESS_LIMIT),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.port_limit", ?DEFAULT_PORT_LIMIT),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.gc_ms_limit", ?DEFAULT_GC_MS_LIMIT),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.heap_word_limit", ?DEFAULT_HEAP_WORD_LIMIT),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_port", ?DEFAULT_BUSY_PORT),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_dist_port", ?DEFAULT_BUSY_DIST_PORT),
    ok.

override_schema_test() ->
    %% Conf represents the riak.conf file that would be read in by cuttlefish.
    %% this proplists is what would be output by the conf_parse module
    Conf = [
        {["riak_sysmon", "process_limit"], ?PLUS1(?DEFAULT_PROCESS_LIMIT)},
        {["riak_sysmon", "port_limit"], ?PLUS1(?DEFAULT_PORT_LIMIT)},
        {["riak_sysmon", "gc_ms_limit"], ?PLUS1(?DEFAULT_GC_MS_LIMIT)},
        {["riak_sysmon", "heap_word_limit"], ?PLUS1(?DEFAULT_HEAP_WORD_LIMIT)},
        {["riak_sysmon", "busy_port"], not ?DEFAULT_BUSY_PORT},
        {["riak_sysmon", "busy_dist_port"], not ?DEFAULT_BUSY_DIST_PORT} 
    ],

    Config = cuttlefish_unit:generate_config("../priv/riak_sysmon.schema", Conf),

    cuttlefish_unit:assert_config(Config, "riak_sysmon.process_limit", ?PLUS1(?DEFAULT_PROCESS_LIMIT)),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.port_limit", ?PLUS1(?DEFAULT_PORT_LIMIT)),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.gc_ms_limit", ?PLUS1(?DEFAULT_GC_MS_LIMIT)),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.heap_word_limit", ?PLUS1(?DEFAULT_HEAP_WORD_LIMIT)),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_port", not ?DEFAULT_BUSY_PORT),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_dist_port", not ?DEFAULT_BUSY_DIST_PORT),
    ok.

