.PHONY: build
	
WHITELIST := 'Makefile\|src/'

build: compile copy

clean:
	rm -rf dist/

compile:
	mkdir -p dist/js
	elm make src/Main.elm --optimize --output=dist/js/main.js

copy:
	cp -r js dist/
	cp index.html dist/
	cp style.css dist/


devel:
	commando -p cat -q -j \
	| grep --line-buffered    $(WHITELIST)    \
	| uniqhash                                \
	| conscript make build
