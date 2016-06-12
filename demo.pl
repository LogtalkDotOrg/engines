:- use_module(engines).

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
