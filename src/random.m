// Random number routines and support

// The random() generator is used for all random numbers.  It is set up to
// be able to generate two sequences, a normal one and an auxiliary one.
// The auxiliary one is used when a random numbers are temporarily needed
// for display purposes (e.g. sampling the dividend sequence) without
// upsetting the reproducibility of the main simulation.  saveRandom()
// and restoreRandom() respectively switch to and from the auxiliary
// sequence.

// If you want to use a different random number generator, you'll have
// to change:
//
// 1. The basic definitions at the top of random.h.
// 2. The way that the generator is initialized from "seed" in randset().
// 3. The way that saveRandom() and retoreRandom() work.
//
// The saveRandom() and retoreRandom() routines are only needed for the
// frontend, so you can disable them if you're only interested in batch
// work.  If you make them do nothing at all everything will still work
// except that runs with the frontend may not exactly reprodicible from
// the log file.

// FUNCTION CALLS
//
// int randset(int seed)
//	Initializes the random number generators using "seed".  If seed
//	is 0 a random seed based on the time is used.  In any cases the
//	value returned is the seed to use for an identical re-run.
//
// int irand(int n)
//	Generates a random integer in the range 0, 1, ..., n-1.  The
//	n possible outcomes have equal probability.  Implemented as a
//	macro in the random.h file.
//
// double drand(void)
//	Generates a random double, uniform in [0, 1).  Implemented as a
//	macro in the random.h file.
//
// double urand(void)
//	Generates a random double, uniform in [-1, 1].  Implemented as a
//	macro in the random.h file.
//
// double normal(void)
//	Generates a random double drawn from a normal distribution with
//	mean 0 and variance 1.
//
// char *randomName(char *buf)
//	Constructs a random 3-letter null-terminated name in a user-supplied
//	buffer "buf".  All three letters are lowercase.  The first letter is
//	not a vowel or x, the middle letter is always a vowel.  Returns "buf".
//
// void saveRandom(void)
//	Saves the current state and switches the generators to an alternative
//	random number sequence until restoreRandom() is called.
//
// void restoreRandom(void)
//	Restores the state saved by saveRandom(), so that the same sequence
//	will be produced as if the saveRandom() ... restoreRandom() calls
//	had never occurred.

#import "random.h"
#import <math.h>
#import <string.h>
#import <time.h>
#import <sys/types.h>

// Prototypes for random() etc
extern long random(void);
extern void srandom (int seed);
extern char *initstate (unsigned int seed, char *state, int n);
extern char *setstate (char *state);

// Storage for random()'s two states.
#define RANDOMBYTES	128
#define AUXRANDOMBYTES	32
static char randomstate[RANDOMBYTES];
static char auxrandomstate[AUXRANDOMBYTES];

// Storage for normal()'s state 
static int set = 0;
static double gset;
static int set_saved;
static double gset_saved;


/*------------------------------------------------------*/
/*	normal						*/
/*------------------------------------------------------*/
double normal(void)
/*
 * function normal - returns random variable n(0,1)
 *
 * This function converts uniform random numbers to normal 
 * random numbers.  The algorithm comes out of numerical
 * recipes.  Note that it may return slightly different values depending
 * on whether it is compiled with optimization, since floating point
 * registers have more precision than stored double's on some machines
 * (including m68k).
 */
{
    double v1, v2, fac, r;

    if (set) {
	set = 0;
	return gset;
    }
    else {
	do {
	    v1 = urand();
	    v2 = urand();
	    r = v1*v1 + v2*v2;
	} while (r >= 1.0);
	fac = sqrt(-2.0*log(r)/r);
	gset = v2*fac;
	set = 1;
	return v1*fac;
    }
}


/*------------------------------------------------------*/
/*	randomName					*/
/*------------------------------------------------------*/
char *randomName(char *buf)
/*
 * Makes a random 3-letter null-terminated name in buf.
 * The first letter is not a vowel or x, the middle letter
 * is always a vowel.
 */
{
    char *ptr = buf;
    do
	*ptr = 'a' + irand(26);
    while (strchr("aeioux",*ptr) != NULL);
    ++ptr;
    switch (irand(5)) {
    case 0: *ptr++ = 'a'; break;
    case 1: *ptr++ = 'e'; break;
    case 2: *ptr++ = 'i'; break;
    case 3: *ptr++ = 'o'; break;
    case 4: *ptr++ = 'u'; break;
    }
    *ptr++ = 'a' + irand(26);
    *ptr = '\0';
    return buf;
}


/*------------------------------------------------------*/
/*	randset						*/
/*------------------------------------------------------*/
int randset(int seed)
/*
 * Initializes both the generators using "seed".  If seed==0 a random
 * seed based on the time is used.  In both cases the values returned
 * is the seed to use for an identical re-run.
 */
{
    time_t time();
    time_t timenow = time((time_t *)0);

    if (seed == 0)
	seed = (int) (timenow&037777777);

// Initialize auxiliary sequence
    initstate((~seed)&MAXRAND, auxrandomstate, AUXRANDOMBYTES);

// Initialize main sequence, and leave that state selected
    initstate(seed&MAXRAND, randomstate, RANDOMBYTES);

    return (seed);
}


/*------------------------------------------------------*/
/*	saveRandom					*/
/*------------------------------------------------------*/
void saveRandom(void)
/*
 * Switches random() to its alternative sequence so that auxiliary
 * random numbers can be generated without interrupting the main
 * sequence.  Also saves normal()'s internal state to preserve
 * that function's main sequence too.
 */
{
    setstate(auxrandomstate);
    set_saved = set;
    gset_saved = gset;
    set = 0;
}


/*------------------------------------------------------*/
/*	restoreRandom					*/
/*------------------------------------------------------*/
void restoreRandom(void)
/*
 * Restores the main sequence after use of saveRandom().
 */
{
    setstate(randomstate);
    set = set_saved;
    gset = gset_saved;
}
