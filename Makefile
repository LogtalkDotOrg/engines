engines.so:
	swipl-ld -share -Wall -O2 -gdwarf-2 -g3 -shared -o engines engines.c

clean:
	rm -f *~
	rm -f engines.so
