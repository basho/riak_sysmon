.PHONY: all deps clean doc

all: compile

compile:
	./rebar3 compile

clean:
	./rebar3 clean

doc: all
	./rebar3 doc

include tools.mk
