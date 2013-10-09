-module(riak_sysmon_schema_tests).

-include_lib("eunit/include/eunit.hrl").
-compile(export_all).

%% basic schema test will check to make sure that all defaults from the schema
%% make it into the generated app.config
basic_schema_test() ->
    %% The defaults are defined in ../priv/riak_sysmon.schema. it is the file under test. 
    Config = cuttlefish_unit:generate_config("../priv/riak_sysmon.schema", []),

    cuttlefish_unit:assert_config(Config, "riak_sysmon.process_limit", 30),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.port_limit", 2),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.gc_ms_limit", 0),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.heap_word_limit", 40111000),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_port", true),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_dist_port", true),
    ok.

override_schema_test() ->
    %% Conf represents the riak.conf file that would be read in by cuttlefish.
    %% this proplists is what would be output by the conf_parse module
    Conf = [
        {["riak_sysmon", "process_limit"], 60},
        {["riak_sysmon", "port_limit"], 4},
        {["riak_sysmon", "gc_ms_limit"], 2},
        {["riak_sysmon", "heap_word_limit"], 80222000},
        {["riak_sysmon", "busy_port"], false},
        {["riak_sysmon", "busy_dist_port"], false} 
    ],

    Config = cuttlefish_unit:generate_config("../priv/riak_sysmon.schema", Conf),

    cuttlefish_unit:assert_config(Config, "riak_sysmon.process_limit", 60),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.port_limit", 4),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.gc_ms_limit", 2),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.heap_word_limit", 80222000),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_port", false),
    cuttlefish_unit:assert_config(Config, "riak_sysmon.busy_dist_port", false),
    ok.

