SO=$(shell eval `swipl --dump-runtime-variables` && echo $$PLSOEXT)

engines.$(SO): engines.c Makefile
	swipl-ld -shared -Wall -O2 -gdwarf-2 -g3 -shared -o engines engines.c

clean:
	rm -f *~
	rm -f engines.so
