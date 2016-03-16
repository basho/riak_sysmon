{application, riak_sysmon,
 [
  {description, "Rate-limiting system_monitor event handler"},
  {vsn, "2.0.0"},
  {modules, [
             riak_sysmon_app,
             riak_sysmon_example_handler,
             riak_sysmon_filter,
             riak_sysmon_sup,
             riak_sysmon_testhandler
            ]},
  {applications, [
                  kernel,
                  stdlib,
                  sasl
                 ]},
  {registered, []},
  {mod, {riak_sysmon_app, []}},
  {env, [
        ]}
 ]}.
