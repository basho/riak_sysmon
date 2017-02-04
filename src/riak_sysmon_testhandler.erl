%% -------------------------------------------------------------------
%%
%% Copyright (c) 2011-2017 Basho Technologies, Inc.
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
%%
%% -------------------------------------------------------------------

%% @doc Support for EUnit testing: simple event-collecting event handler.
-module(riak_sysmon_testhandler).

-ifdef(TEST).

-behaviour(gen_event).

%% API
-export([start_link/0, add_handler/1, get_events/1]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2,
         handle_info/2, terminate/2, code_change/3]).

-record(state, {
          list = [] :: list()
         }).

%%%===================================================================
%%% gen_event callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% Creates an event manager
%%
%% start_link() -> {ok, Pid} | {error, Error}
%%--------------------------------------------------------------------
start_link() ->
    gen_event:start_link({local, ?MODULE}).

%%--------------------------------------------------------------------
%% Adds an event handler
%%
%% add_handler(gen_event:emgr_name()) -> ok | {'EXIT', Reason} | term()
%%--------------------------------------------------------------------
add_handler(EventServer) ->
    gen_event:add_sup_handler(EventServer, ?MODULE, []).

get_events(EventServer) ->
    gen_event:call(EventServer, ?MODULE, get_events).

%%%===================================================================
%%% gen_event callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% Whenever a new event handler is added to an event manager,
%% this function is called to initialize the event handler.
%%
%% init(Args) -> {ok, State}
%%--------------------------------------------------------------------
init([]) ->
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% Whenever an event manager receives an event sent using
%% gen_event:notify/2 or gen_event:sync_notify/2, this function is
%% called for each installed event handler to handle the event.
%%
%% handle_event(Event, State) ->
%%                          {ok, State} |
%%                          {swap_handler, Args1, State1, Mod2, Args2} |
%%                          remove_handler
%%--------------------------------------------------------------------
handle_event(Event, #state{list = List} = State) ->
    {ok, State#state{list = [Event|List]}}.

%%--------------------------------------------------------------------
%% Whenever an event manager receives a request sent using
%% gen_event:call/3,4, this function is called for the specified
%% event handler to handle the request.
%%
%% handle_call(Request, State) ->
%%                   {ok, Reply, State} |
%%                   {swap_handler, Reply, Args1, State1, Mod2, Args2} |
%%                   {remove_handler, Reply}
%%--------------------------------------------------------------------
handle_call(get_events, State) ->
    {ok, lists:reverse(State#state.list), State#state{list = []}};
handle_call(_Request, State) ->
    Reply = not_supported,
    {ok, Reply, State}.

%%--------------------------------------------------------------------
%% This function is called for each installed event handler when
%% an event manager receives any other message than an event or a
%% synchronous request (or a system message).
%%
%% handle_info(Info, State) ->
%%                         {ok, State} |
%%                         {swap_handler, Args1, State1, Mod2, Args2} |
%%                         remove_handler
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% Whenever an event handler is deleted from an event manager, this
%% function is called. It should be the opposite of Module:init/1 and
%% do any necessary cleaning up.
%%
%% terminate(Reason, State) -> void()
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Convert process state when code is changed
%%
%% code_change(OldVsn, State, Extra) -> {ok, NewState}
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-endif. % TEST
