.PHONY: all deps clean doc

all: deps compile

compile:
	./rebar compile

deps:
	./rebar get-deps

clean:
	./rebar clean

doc: all
	./rebar doc

include tools.mk
