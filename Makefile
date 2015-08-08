build:
	./node_modules/.bin/coffee -c lib
	
unbuild:
	rm -rf lib
	mv src lib
