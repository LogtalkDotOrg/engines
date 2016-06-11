:- use_module(engines).

:- meta_predicate
	fa(?, 0, -).

%%	fa(?Templ, :Goal, -List)
%
%	Engine based findall/3

fa(Templ, Goal, List) :-
	setup_call_cleanup(
	    engine_create(E, Templ, Goal, []),
	    get_answers(E, List),
	    engine_destroy(E)).

get_answers(E, [H|T]) :-
	engine_get(E, H), !,
	get_answers(E, T).
get_answers(_, []).
