/*  Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (c)  2016, VU University Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(engines,
	  [ engine_create/3,		% -Ref, ?Template, :Goal
	    engine_create/4,		% -Ref, ?Template, :Goal, +Options
	    engine_get/2,		% +Ref, -Term
	    engine_put/3,		% +Ref, +Terms, -Reply
	    engine_return/1,		% +Term
	    engine_read/1,		% -Term
	    engine_destroy/1,		% +Ref
	    current_engine/1		% ?Ref
	  ]).
:- load_foreign_library(engines).

:- meta_predicate
	engine_create(-, ?, 0),
	engine_create(-, ?, 0, +).

/** <module> Engine prototype

@tbd	Allow engines to produce and consume terms.
*/

%%	engine_create(-Engine, ?Template, :Goal) is det.
%%	engine_create(-Engine, ?Template, :Goal, +Options) is det.
%
%	Create a new engine, prepared to run  Goal and return answers as
%	instances of Template. Goal is not started.

engine_create(Engine, Template, Goal) :-
	'$engine_create'(Engine, Template+Goal, []).
engine_create(Engine, Template, Goal, Options) :-
	'$engine_create'(Engine, Template+Goal, Options).

%%	engine_get(+Engine, -Term) is semidet.
%
%	Switch control to Engine and if engine produces a result, switch
%	control  back  and  unify   the    instance   of  Template  from
%	engine_create/3,4 with Term. Repeatedly  calling engine_get/2 on
%	Engine retrieves new instances of  Template by backtracking over
%	Goal. Fails of Goal has no  more   solutions.  If Goal raises an
%	exception the exception is re-raised by this predicate.

%%	engine_put(+Engine, +Terms, -Reply) is semidet.
%
%	Same as engine_get/2,  but  make  terms   from  the  list  Terms
%	available for engine_read/1 when called from within Engine.

%%	engine_destroy(+Engine) is det.
%
%	Destroy Engine. Eventually, engine  destruction   will  also  be
%	subject to symbol garbage collection.

%%	engine_return(+Term) is det.
%
%	Make engine_get/2 return with the given term.

engine_return(Term) :-
	engine_yield(Term, 2).

%%	engine_read(-Term) is det.
%
%	Read the next term  from  the   list  of  terms provided through
%	engine_put/3.  Returns  `end_of_file`  of  the    term  list  is
%	exhausted.

engine_read(Term) :-
	engine_yield(Term, 3).

engine_yield(_Term, _Code) :-
	'$yield'.				% maps to I_YIELD

'$yield'.					% fool xref

%%	current_engine(?E)
%
%	True if E is a currently know engine.

current_engine(E) :-
	current_blob(E, engine).
