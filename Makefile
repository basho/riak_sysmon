.PHONY: all deps clean test doc

all:
	./rebar compile

deps:
	./rebar get-deps

clean:
	./rebar clean

test: all
	./rebar eunit

doc: all
	./rebar doc
