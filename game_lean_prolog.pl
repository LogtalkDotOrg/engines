:- use_module(engines).

		 /*******************************
		 *     LEAN PROLOG EMULATION	*
		 *******************************/

% This emulation makes the relation between lean Prolog and the
% current engine API explicit.  See
% https://github.com/JanWielemaker/engines/issues/2

new_engine(Template, Goal, Engine) :- engine_create(Template, Goal, Engine).
return(Term) :-	engine_return(Term).
from_engine(Term) :- engine_fetch(Term).
to_engine(Engine, Term) :- engine_post(Engine, Term).

get(Engine, Answer) :-
	(   catch(engine_get(Engine, Answer0), E, true)
	->  (   var(E)
	    ->  Answer = the(Answer0)
	    ;   Answer = exception(E)
	    )
	;   Answer = no
	).

		 /*******************************
		 *	      THE GAME		*
		 *******************************/

% The game is by Paulo Moura.

explain :-
	writeln('Scissors cuts Paper'),
	writeln('Paper covers Rock'),
	writeln('Rock crushes Lizard'),
	writeln('Lizard poisons Spock'),
	writeln('Spock smashes Scissors'),
	writeln('Scissors decapitates Lizard'),
	writeln('Lizard eats Paper'),
	writeln('Paper disproves Spock'),
	writeln('Spock vaporizes Rock'),
	writeln('(and as it always has) Rock crushes Scissors').

play :-
	% in the sitcom, the game is first played between
	% Sheldon and Raj: create an engine for each one
	new_engine(done, loop(sheldon), Sheldon),
	new_engine(done, loop(raj), Raj),
	play_move(Sheldon, Raj),
	% wait for both engines to terminate before stopping them
	get(Sheldon, the(done)),
	get(Raj, the(done)).

% each engine runs this loop predicate until
%  there is a winning or loosing move
loop(Me) :-
	select_move(Me, Move),
	% return the selected move to the object,
	% which acts as the game arbiter
	return(Move),
	% react to the move outcome
	from_engine(Result),
	handle_result(Result, Me).

handle_result(win, Me) :-
	writeln(Me:'I win! I''m the best!').
handle_result(loose, Me) :-
	writeln(Me:'Penny distracted me! It''s Penny''s fault!').
handle_result(draw, Me) :-
	loop(Me).

% arbiter predicate that collects engine moves, compares them,
% communicate the move outcome to the engines, and decides if
% the game continues
play_move(Sheldon, Raj) :-
	get(Sheldon, the(SheldonMove)),
	get(Raj, the(RajMove)),
	decide_move(SheldonMove, RajMove, SheldonResult, RajResult),
	to_engine(Sheldon, SheldonResult),
	to_engine(Raj, RajResult),
	(	SheldonResult == draw ->
		play_move(Sheldon, Raj)
	;	true
	).

% when selecting and printing the move, we could also
% have called the threaded_engine_self/1 predicate
% instead of passing the name of the engine
select_move(Me, Move) :-
	random(1, 6, N),
	move(N, Move),
	writeln(Me:Move).

move(1, scissors).
move(2, rock).
move(3, paper).
move(4, lizard).
move(5, spock).

% compare the moves and decide the outcome for each player
decide_move(Move1, Move2, Result1, Result2) :-
	(	final_move(Move1, Move2, Result1, Result2) ->
		true
	;	final_move(Move2, Move1, Result2, Result1) ->
		true
	;	Result1 = draw,
		Result2 = draw
	).

% Scissors cuts Paper
final_move(scissors, paper, win, loose).
% Paper covers Rock
final_move(paper, rock, win, loose).
% Rock crushes Lizard
final_move(rock, lizard, win, loose).
% Lizard poisons Spock
final_move(lizard, spock, win, loose).
% Spock smashes Scissors
final_move(spock, scissors, win, loose).
% Scissors decapitates Lizard
final_move(scissors, lizard, win, loose).
% Lizard eats Paper
final_move(lizard, paper, win, loose).
% Paper disproves Spock
final_move(paper, spock, win, loose).
% Spock vaporizes Rock
final_move(spock, rock, win, loose).
% (and as it always has) Rock crushes Scissors
final_move(rock, scissors, win, loose).
