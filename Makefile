all:
	./rebar compile

clean:
	./rebar clean

test: all
	./rebar eunit

doc: all
	./rebar doc
