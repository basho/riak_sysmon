######################################################
# NOTE:                                              #
# Do not put commands of importance in this Makefile #
# it should only be used to drive rebar              #
######################################################
.PHONY: all compile xref dialyzer test doc help clean

PROJDIR := $(realpath $(CURDIR))
REBAR := $(PROJDIR)/rebar3

all: test

rebar3:
	@echo "Fetching rebar3 into $(PROJDIR)..."
	curl -sLO https://s3.amazonaws.com/rebar3/rebar3 && chmod +x $(REBAR)

compile: rebar3
	$(REBAR) as prod compile

xref: compile
	$(REBAR) as check xref

dialyzer: compile xref
	$(REBAR) as check dialyzer

test: dialyzer
	$(REBAR) eunit

doc: compile
	$(REBAR) edoc

clean: 
	$(REBAR) clean
	@rm -f $(REBAR)

help:
	@echo ''
	@echo ' Targets:'
	@echo '-------------------------------------------'
	@echo ' all     - Compile, run dialyzer and tests '
	@echo ' compile - Compile with "prod" profile     '
	@echo ' test    - Compile and run all tests       '
	@echo ' doc     - Build documentation             '
	@echo ' clean   - Clean project                   '
	@echo '-------------------------------------------'
	@echo ''
