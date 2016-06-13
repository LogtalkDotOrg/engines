:- use_module(engines).
:- use_module(library(yall)).

:- meta_predicate
	fa(?, 0, -).

%%	fa(?Templ, :Goal, -List)
%
%	Engine based findall/3: backtrack over an engine's answers.

fa(Templ, Goal, List) :-
	setup_call_cleanup(
	    engine_create(E, Templ, Goal, []),
	    get_answers(E, List),
	    engine_destroy(E)).

get_answers(E, [H|T]) :-
	engine_get(E, H), !,
	get_answers(E, T).
get_answers(_, []).

%%  find_at_most(+N, ?Template, :Goal, -List)
%
%   Engine based findall/3 variant that finds at most N answers.

find_at_most(N, Template, Goal, List) :-
	engine_create(Engine, Template, Goal),
	collect_at_most(N, Engine, List0),
	engine_destroy(Engine),
	List = List0.

collect_at_most(N, Engine, [X| Xs]) :-
	N > 0,
	engine_get(Engine, X),
	!,
	M is N - 1,
	collect_at_most(M, Engine, Xs).
collect_at_most(_, _, []).

%%	test_gc(+N)
%
%	Test that engines are subject to atom-GC.

test_gc(N) :-
	forall(between(1, N, _), engine_create(_, _, true)),
	garbage_collect_atoms.

%%	create_n(+Count, -Engines:list)
%
%	Create lots of engines, testing creating time and memory
%	resources.

create_n(N, L) :-
	length(L, N),
	maplist(create, L).

create(E) :-
	engine_create(E, _, true).

%%	yield(+Length, -List)
%
%	Fetch  answers  from  an   engine    that   returns  them  using
%	engine_return/1.  This  realises  coroutines,  where  the  slave
%	engine has the initiative.  Note   that  yield_loop/2 eventually
%	fails. If we succeed we would extract   one more answer from the
%	engine.

yield(Len, List) :-
	setup_call_cleanup(
	    engine_create(E, _, yield_loop(1,Len), []),
	    get_answers(E, List),
	    engine_destroy(E)).

yield_loop(I, M) :-
	I =< M, !,
	engine_return(I),
	I2 is I+1,
	yield_loop(I2, M).

%%	rd(+Length, -Sums) is det.
%
%	Use an engine to accumulate state.

rd(N, Sums) :-
	numlist(1, N, List),
	setup_call_cleanup(
	    engine_create(E, _, sum(0), []),
	    maplist([X]>>engine_put(E, [X]), List, Sums),
	    engine_destroy(E)).

sum(Sum) :-
	engine_read(New),
	Sum1 is New + Sum,
	engine_return(Sum1),
	sum(Sum1).

%%	whisper(N, Term)
%
%	Create a chain of N engines that whisper a term from the first
%	to the second, ... up to the end.

whisper(N, From, Final) :-
	engine_create(Last, _, final),
	whisper_list(N, Last, First),
	engine_put(First, [From], Final).

whisper_list(0, First, First) :- !.
whisper_list(N, Next, First) :-
	engine_create(Me, _, add1_and_tell(Next)),
	N1 is N - 1,
	whisper_list(N1, Me, First).

final :-
	engine_read(X),
	writeln(X).

add1_and_tell(Next) :-
	engine_read(X),
	X2 is X + 1,
	debug(whisper, 'Sending ~d to ~p', [X2, Next]),
	engine_put(Next, [X2], _).

%%	no_data
%
%	Test what happens on engine_read/1 if there is no data to read.

no_data :-
	catch(
	    setup_call_cleanup(
		engine_create(E, _, sum(0), []),
		maplist(engine_get(E), [1]),
		engine_destroy(E)),
	    Error,
	    print_message(warning, Error)).
