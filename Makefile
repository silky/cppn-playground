.PHONY: compile
	
WHITELIST := 'Makefile\|src/'

compile:
	mkdir -p dist
	elm make src/Main.elm --optimize --output=dist/main.js

devel:
	commando -p cat -q -j \
	| grep --line-buffered    $(WHITELIST)    \
	| uniqhash                                \
	| conscript make
