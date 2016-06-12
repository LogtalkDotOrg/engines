# Paul Tarau style _interactors_ for SWI-Prolog

This repo builds on the SWI-Prolog  engine API to realise _interactors_.
An interactor is a Prolog engine  with,   like  a thread, its own stack.
Unlike a thread however, it is not   associated with an operating system
thread.

This library allows for creating an  engine   from  Prolog  and ask this
engine to perform some action.  The   action  is  performed by temporary
associating the calling thread with the engine   and  to make it perform
the action. After completion control is returned to the calling thread.

Interactors allow for implementing  coroutines.  As   no  OS  thread  is
involved, interactors require less resources and   are better suited for
e.g., large agent simulations.

__This is a temporary repository__ interactors   will most likely end up
in the core.
