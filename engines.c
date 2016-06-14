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

#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <pthread.h>
#include <SWI-Stream.h>
#include <SWI-Prolog.h>

#define COMPARE_AND_SWAP(ptr,o,n)	__sync_bool_compare_and_swap(ptr,o,n)


		 /*******************************
		 *	       SYMBOL		*
		 *******************************/

#define ENG_DESTROYED	0x0001

typedef struct engref
{ PL_engine_t    engine;		/* represented engine */
  atom_t         symbol;		/* associated symbol */
  qid_t	         query;			/* query of the engine */
  term_t         argv;			/* arguments */
  record_t	 package;		/* engine_post/2 */
  struct engref *next_free;		/* next in free list */
  int	         flags;			/* flags */
} engref;


		 /*******************************
		 *	     GC ENGINES		*
		 *******************************/

static engref *gced_engines = NULL;
static int     engine_gc_running = FALSE;

static void *
engine_gc_loop(void *closure)
{ for(;;)
  { engref *e;

    do
    { e = gced_engines;
    } while ( e && !COMPARE_AND_SWAP(&gced_engines, e, e->next_free) );

    if ( e )
    { PL_destroy_engine(e->engine);
      PL_free(e);
    } else
    { break;
    }
  }

  engine_gc_running = FALSE;
  return NULL;
}


static void
start_engine_gc_thread(void)
{ if ( !engine_gc_running )
  { pthread_attr_t attr;
    int rc;
    pthread_t thr;

    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    engine_gc_running = TRUE;
    rc = pthread_create(&thr, &attr, engine_gc_loop, NULL);
    pthread_attr_destroy(&attr);
    if ( rc != 0 )
      Sdprintf("Failed to start engine gc thread\n");
  }
}


static void
gc_engine(engref *er)
{ engref *h;

  do
  { h = gced_engines;
    er->next_free = h;
  } while( !COMPARE_AND_SWAP(&gced_engines, h, er) );

  start_engine_gc_thread();
}


		 /*******************************
		 *	 SYMBOL REFERENCES	*
		 *******************************/

static int
write_engine_ref(IOSTREAM *s, atom_t eref, int flags)
{ engref **refp = PL_blob_data(eref, NULL, NULL);
  engref *ref = *refp;
  (void)flags;

  Sfprintf(s, "<engine>(%p)", ref->engine);
  return TRUE;
}


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
GC an engine from the atom garbage collector.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

static int
release_engine_ref(atom_t aref)
{ engref **refp = PL_blob_data(aref, NULL, NULL);
  engref *ref   = *refp;
  PL_engine_t e;

  if ( (e=ref->engine) )
    gc_engine(ref);
  else
    PL_free(ref);

  return TRUE;
}


static int
save_engine(atom_t aref, IOSTREAM *fd)
{ engref **refp = PL_blob_data(aref, NULL, NULL);
  engref *ref   = *refp;
  (void)fd;

  return PL_warning("Cannot save reference to <engine>(%p)", ref->engine);
}


static atom_t
load_engine(IOSTREAM *fd)
{ (void)fd;

  return PL_new_atom("<saved-engine-ref>");
}


static PL_blob_t engine_blob =
{ PL_BLOB_MAGIC,
  PL_BLOB_UNIQUE,
  "engine",
  release_engine_ref,
  NULL,
  write_engine_ref,
  NULL,
  save_engine,
  load_engine
};


static int
unify_engine(term_t t, engref *er)
{ if ( er->symbol )
  { return PL_unify_atom(t, er->symbol);
  } else
  { return ( PL_unify_blob(t, &er, sizeof(er), &engine_blob) &&
	     PL_get_atom(t, &er->symbol)
	   );
  }
}


static int
get_engine(term_t t, engref **erp, int warn)
{ void *data;
  size_t len;
  PL_blob_t *type;

  if ( PL_get_blob(t, &data, &len, &type) && type == &engine_blob )
  { engref **erd = data;
    engref *er = *erd;

    if ( !(er->flags & ENG_DESTROYED) )
    { *erp = er;
      return TRUE;
    } else if ( warn )
    { PL_existence_error("engine", t);
    }
  }

  if ( warn )
    PL_type_error("engine", t);

  return FALSE;
}



		 /*******************************
		 *	      CREATE		*
		 *******************************/

static foreign_t
pl_engine_create(term_t ref, term_t template_and_goal, term_t options)
{ engref *er = PL_malloc(sizeof(*er));
  int rc;
  PL_engine_t me;
  static predicate_t pred = NULL;
  record_t r = PL_record(template_and_goal);
  term_t t;

  memset(er, 0, sizeof(*er));
  er->engine = PL_create_engine(NULL);
  rc = PL_set_engine(er->engine, &me);
  assert(rc == PL_ENGINE_SET);

  if ( !pred )
    pred = PL_predicate("call", 1, "system");

  if  ( (t = PL_new_term_ref()) &&
	(er->argv = PL_new_term_refs(2)) &&
	PL_recorded(r, t) &&
	PL_get_arg(1, t, er->argv+0) &&
	PL_get_arg(2, t, er->argv+1) )
  { er->query = PL_open_query(NULL,
			      PL_Q_CATCH_EXCEPTION|PL_Q_ALLOW_YIELD,
			      pred, er->argv+1);
    PL_set_engine(me, NULL);
  } else
  { assert(0);					/* TBD: copy exception */
  }

  PL_erase(r);

  return unify_engine(ref, er);
}


static foreign_t
pl_engine_post_get(term_t ref, term_t package, term_t term)
{ engref *er;

  if ( get_engine(ref, &er, TRUE) )
  { PL_engine_t me;

    if ( package && er->package )
      return PL_permission_error("post_to", "engine", package);

    switch( PL_set_engine(er->engine, &me) )
    { case PL_ENGINE_SET:
      { term_t t;
	int rc;

      again:
	if ( (rc=PL_next_solution(er->query)) )
	{ record_t r;

	  switch(rc)
	  { case TRUE:
	      r = PL_record(er->argv+0);
	      break;
	    case 2:
	      r = PL_record(PL_yielded(er->query));
	      break;
	    case 3:
	      if ( package )
	      { term_t t;

		PL_set_engine(me, NULL);
		r = PL_record(package);
		PL_set_engine(er->engine, NULL);
		rc = ( (t = PL_new_term_ref()) &&
		       PL_recorded(r, t) &&
		       PL_unify(t, PL_yielded(er->query)) );
		PL_erase(r);
		package = 0;		/* term was collected */
		goto again;
	      } else if ( er->package )
	      { PL_set_engine(er->engine, NULL);
		rc = ( (t = PL_new_term_ref()) &&
		       PL_recorded(er->package, t) &&
		       PL_unify(t, PL_yielded(er->query)) );
		PL_erase(er->package);
		er->package = 0;
		goto again;
	      } else
	      {				/* TBD: better error */
		PL_existence_error("engine_term", PL_yielded(er->query));
		goto again;
	      }
	    default:
	    { term_t ex = PL_new_term_ref();

	      return ( PL_put_integer(ex, rc) &&
		       PL_domain_error("engine_yield_code", ex) );
	    }
	  }

	  PL_set_engine(me, NULL);
	  t = PL_new_term_ref();
	  rc = ( PL_recorded(r, t) && PL_unify(term, t) );
	  PL_erase(r);

	  return rc;
	} else if ( (t = PL_exception(er->query)) )
	{ record_t r = PL_record(t);
	  int rc;

	  PL_close_query(er->query);
	  er->query = 0;
	  PL_set_engine(me, NULL);

	  rc = ( PL_recorded(r, t) && PL_raise_exception(t) );
	  PL_erase(r);

	  return rc;
	} else
	{ PL_close_query(er->query);
	  er->query = 0;
	  PL_set_engine(me, NULL);
	  return FALSE;
	}
      }
      case PL_ENGINE_INUSE:
	return PL_permission_error("resume", "engine", ref);
      case PL_ENGINE_INVAL:
	return PL_existence_error("engine", ref);
      default:
	assert(0);
    }
  }

  return FALSE;
}


static foreign_t
pl_engine_get(term_t ref, term_t term)
{ return pl_engine_post_get(ref, 0, term);
}


static foreign_t
pl_engine_post3(term_t ref, term_t package, term_t term)
{ return pl_engine_post_get(ref, package, term);
}


static foreign_t
pl_engine_post2(term_t ref, term_t package)
{ engref *er;

  if ( get_engine(ref, &er, TRUE) )
  { if ( er->package )
      return PL_permission_error("post_to", "engine", package);
    if ( (er->package = PL_record(package)) )
      return TRUE;
  }

  return FALSE;
}


static foreign_t
pl_engine_destroy(term_t ref)
{ engref *er;

  if ( get_engine(ref, &er, TRUE) )
  { if ( er->query )
    { PL_engine_t me;

      PL_set_engine(er->engine, &me);
      PL_close_query(er->query);
      PL_set_engine(me, NULL);
      er->query = 0;
    }
    if ( er->engine )
    { PL_destroy_engine(er->engine);
      er->engine = NULL;
    }
    er->flags |= ENG_DESTROYED;

    return TRUE;
  }

  return FALSE;
}


static foreign_t
pl_engine_exists(term_t ref)
{ engref *er;

  return get_engine(ref, &er, FALSE);
}


install_t
install_engines(void)
{ PL_register_foreign("$engine_create", 3, pl_engine_create,  0);
  PL_register_foreign("engine_get",     2, pl_engine_get,     0);
  PL_register_foreign("engine_post",    2, pl_engine_post2,   0);
  PL_register_foreign("engine_post",    3, pl_engine_post3,   0);
  PL_register_foreign("engine_destroy", 1, pl_engine_destroy, 0);
  PL_register_foreign("$engine_exists", 1, pl_engine_exists,  0);
}
