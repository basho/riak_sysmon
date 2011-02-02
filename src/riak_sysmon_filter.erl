%% Copyright (c) 2011 Basho Technologies, Inc.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.

%% @doc Filtering/rate-limiting mechanism for the Erlang virtual machine's
%% `system_monitor' events.
%%
%% See the `README.md' file at the top of the source repository for details.

-module(riak_sysmon_filter).

-behaviour(gen_server).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif. % TEST

%% API
-export([start_link/0, start_link/1]).
-export([add_custom_handler/2, call_custom_handler/2, call_custom_handler/3]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).
-ifdef(TEST).
-export([stop_timer/0, start_timer/0]).        % For testing use only!
-endif. % TEST

-record(state, {
          proc_count = 0      :: integer(),
          proc_limit = 10     :: integer(),
          port_count = 0      :: integer(),
          port_limit = 10     :: integer(),
          tref                :: term(),
          bogus_msg_p = false :: boolean()
         }).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    start_link([gc, heap, port, dist_port]).

%% @doc Start riak_sysmon filter process
%%
%% The `MonitorProps' arg is a property list that may contain zero
%% or more of the following atoms:
%% <ul>
%% <li> <b>gc</b> Enable long garbage collection events.
%%      The minimum time (in milliseconds) is defined by the application
%%      `riak_sysmon' environment variable `gc_ms_limit'.
%%      </li>
%% <li> <b>heap</b> Enable process large heap events. </li>
%%      The minimum size (in machine words) is defined by the application
%%      `riak_sysmon' environment variable `process_heap_limit'.
%% <li> <b>busy_port</b> Enable `busy_port' events. </li>
%% <li> <b>busy_dist_port</b> Enable `busy_dist_port' events. </li>
%% </ul>

start_link(MonitorProps) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, MonitorProps, []).

%% @doc Add a custom handler module to the `riak_sysmon'.
%%
%% See the source code of the
%% {@link riak_sysmon_example_handler:add_handler/0} function for
%% a usage example.

add_custom_handler(Module, Args) ->
    gen_event:add_sup_handler(riak_sysmon_handler, Module, Args).
    
call_custom_handler(Module, Call) ->
    call_custom_handler(Module, Call, infinity).

%% @doc Make a synchronous call to a `riak_sysmon' specific custom
%% event handler.
%%
%% See the source code of the
%% {@link riak_sysmon_example_handler:get_call_count/0} function for
%% a usage example.

call_custom_handler(Module, Call, Timeout) ->
    gen_event:call(riak_sysmon_handler, Module, Call, Timeout).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init(MonitorProps) ->
    GcMsLimit = get_gc_ms_limit(),
    HeapWordLimit = get_heap_word_limit(),
    Opts = lists:flatten(
             [[{long_gc, GcMsLimit} || lists:member(gc, MonitorProps)],
              [{large_heap, HeapWordLimit} || lists:member(heap, MonitorProps)],
              [busy_port || lists:member(busy_port, MonitorProps)],
              [busy_dist_port || lists:member(busy_dist_port, MonitorProps)]]),
    erlang:system_monitor(self(), Opts),
    {ok, #state{proc_limit = get_proc_limit(),
                port_limit = get_port_limit(),
                tref = start_interval_timer()
               }}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(stop_timer, _From, State) ->
    catch timer:cancel(State#state.tref),
    {reply, ok, State#state{tref = undefined}};
handle_call(start_timer, _From, State) ->
    catch timer:cancel(State#state.tref),
    {reply, ok, State#state{tref = start_interval_timer()}};
handle_call(_Request, _From, State) ->
    Reply = not_supported,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info({monitor, _, ProcType, _} = Info,
            #state{proc_count = Procs, proc_limit = ProcLimit} = State)
  when ProcType == long_gc; ProcType == large_heap ->
    NewProcs = Procs + 1,
    if NewProcs =< ProcLimit ->
            gen_event:notify(riak_sysmon_handler, Info);
       true ->
            ok
    end,
    {noreply, State#state{proc_count = NewProcs}};
handle_info({monitor, _, PortType, _} = Info,
            #state{port_count = Ports, port_limit = PortLimit} = State)
  when PortType == busy_port; PortType == busy_dist_port ->
    NewPorts = Ports + 1,
    if NewPorts =< PortLimit ->
            gen_event:notify(riak_sysmon_handler, Info);
       true ->
            ok
    end,
    {noreply, State#state{port_count = NewPorts}};
handle_info({monitor, _, _, _} = Info, #state{bogus_msg_p = false} = State) ->
    error_logger:error_msg("Unknown monitor message: ~P\n", [Info, 20]),
    {noreply, State#state{bogus_msg_p = true}};
handle_info(reset, #state{proc_count = Procs, proc_limit = ProcLimit,
                          port_count = Ports, port_limit = PortLimit} = State)->
    if Procs > ProcLimit ->
            gen_event:notify(riak_sysmon_handler,
                             {suppressed, proc_events, Procs - ProcLimit});
       true ->
            ok
    end,
    if Ports > PortLimit ->
            gen_event:notify(riak_sysmon_handler,
                             {suppressed, port_events, Ports - PortLimit});
       true ->
            ok
    end,
    case erlang:system_monitor() of
        {Pid, _} when Pid == self() ->
            ok;
        Res ->
            error_logger:error_msg("~s: current system monitor is: ~P\n",
                                   [?MODULE, Res, 20])
    end,
    {noreply, State#state{proc_count = 0,
                          port_count = 0}};
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% The default limits below are based on experience.  The proc limit
%% of 30 events/sec rarely gets hit, even on a very busy VM.  The port
%% limit, however, can generate several hundred events/sec.
%%
%% To disable forwarding events of a particular type, use a limit of 0.

get_proc_limit() ->
    nonzero_app_env(riak_sysmon, process_limit, 30).

get_port_limit() ->
    nonzero_app_env(riak_sysmon, port_limit, 30).

%% The default limits below here are more of educated guesses than
%% based on hard experience.  Practical upper limits can vary quite a
%% bit by application & workload and are usually found by
%% experimentation.

get_gc_ms_limit() ->
    nonzero_app_env(riak_sysmon, gc_ms_limit, 50).

get_heap_word_limit() ->
    %% 256 Kwords = 10MB on a 32-bit VM, 20MB on a 64-bit VM
    nonzero_app_env(riak_sysmon, heap_word_limit, 256*1024).

nonzero_app_env(App, Key, Default) ->
    case application:get_env(App, Key) of
        {ok, N} when N >= 0 -> N;
        _                   -> Default
    end.
    
start_interval_timer() ->
    {ok, TRef} = timer:send_interval(1000, reset),
    TRef.

-ifdef(TEST).

stop_timer() ->
    gen_server:call(?MODULE, stop_timer).

start_timer() ->
    gen_server:call(?MODULE, start_timer).

limit_test() ->
    %% Constants ... limits should be at least one or test case will break

    ProcLimit = 10,
    PortLimit = 9,
    EventHandler = riak_sysmon_handler,
    TestHandler = riak_sysmon_testhandler,

    %% Setup part 1: filter server

    catch exit(whereis(?MODULE), kill),
    timer:sleep(10),
    application:set_env(riak_sysmon, process_limit, ProcLimit),
    application:set_env(riak_sysmon, port_limit, PortLimit),
    %% Use huge limits to avoid unexpected messages that could confuse us.
    application:set_env(riak_sysmon, gc_ms_limit, 9999999999),
    application:set_env(riak_sysmon, heap_word_limit, 9999999999),
    {ok, _FilterPid} = ?MODULE:start_link(),
    ?MODULE:stop_timer(),

    %% Setup part 2: gen_event server

    catch exit(whereis(EventHandler), kill),
    timer:sleep(10),
    {ok, _HandlerPid} = gen_event:start_link({local, EventHandler}),
    ok = TestHandler:add_handler(EventHandler),

    %% Check that all legit message types are passed through.

    ProcTypes = [long_gc, large_heap, busy_port, busy_dist_port],
    [?MODULE ! {monitor, yay_pid, ProcType, whatever} || ProcType <- ProcTypes],
    ?MODULE ! reset,
    timer:sleep(100),
    Events1 = TestHandler:get_events(EventHandler),
    [true = lists:keymember(ProcType, 3, Events1) || ProcType <- ProcTypes],
    
    %% Check that limits are enforced.

    [?MODULE ! {monitor, pid1, long_gc, X} ||
        X <- lists:seq(1, (ProcLimit + PortLimit) * 5)],
    [?MODULE ! {monitor, pid2, busy_port, X} ||
        X <- lists:seq(1, (ProcLimit + PortLimit) * 5)],
    ?MODULE ! reset,
    timer:sleep(100),
    Events2 = TestHandler:get_events(EventHandler),
    timer:sleep(50),
    [] = TestHandler:get_events(EventHandler), % Got 'em all
    %% Sanity checks
    ProcLimit = length([X || {monitor, _, long_gc, _} = X <- Events2]),
    PortLimit = length([X || {monitor, _, busy_port, _} = X <- Events2]),
    [_] = [X || {suppressed, proc_events, _} = X <- Events2],
    [_] = [X || {suppressed, port_events, _} = X <- Events2],
    
    ok.

-endif. % TEST
