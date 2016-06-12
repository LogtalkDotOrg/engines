SO=$(shell eval `swipl --dump-runtime-variables` && echo $$PLSOEXT)
COFLAGS=-O2 -gdwarf-2 -g3
#COFLAGS=-gdwarf-2 -g3

engines.$(SO): engines.c Makefile
	swipl-ld -shared -Wall $(COFLAGS) -shared -o engines engines.c

clean:
	rm -f *~
	rm -f engines.so
