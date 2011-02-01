{application, riak_sysmon,
 [
  {description, "Rate-limiting system_monitor event handler"},
  {vsn, "0.1.0"},
  {modules, [
             riak_sysmon_app,
             riak_sysmon_filter,
             riak_sysmon_handler,
             riak_sysmon_sup
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
