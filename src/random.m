// The Santa Fe Stock Market -- Implementation of Random class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This module supplies several random number functions, all based on an
// underlying shuffled linear congruential generator.  Any number of
// separate instances may be used, each seeded separately.
//
// Different instancess are used for the dividend process and the main
// simulation, so that different agents may be compared against the same
// dividend stream.  A third instance is used by the dividend inspector
// in the frontend.

// PUBLIC METHODS
//
// - initWithSeed:(long *)seed
//	Initializes a new instance of Random with the seed pointed to by
//	"seed".  If the seed is 0 (i.e., *seed == 0), it is reset to a
//	random seed based on the time, the pid, and the instance number.
//
// - (long)rngstate
//	Returns a long integer representing the current state of the
//	generator.  Restarting with the returned values as seed will
//	continue the previous sequence after a transient period.
//
// - (long)slgmrand
//	Underlying "Shuffled Lewis-Goodman-Miller" generator used for all
//	other methods and functions.  The underlying generator is Park and
//	Miller's "Minimal Standard Generator", with Schrage's 64-bit
//	multiplication trick.  The Bays-Durham shuffle then removes the
//	remaining serial correlation.  Returns a long in [0, MAXRAND].
//	Period is MAXRAND+1 (besides initial transients).
//
// - (double)normal
//	Generates a random double drawn from a normal distribution with
//	mean 0 and variance 1.  Note that the last few bits of the
//	values may vary between architectures, or even with the compiler
//	optimization level on a given architecture.
//
// - (char *)randomName:(char *)buf
//	Constructs a random 3-letter null-terminated name in a user-supplied
//	buffer "buf".  All three letters are lowercase.  The first letter is
//	not a vowel or x, the middle letter is always a vowel.  Returns "buf".
//
// MACROS
//
// The following three macros are the work-horses.  They are defined in
// the .h file to generate -slgmrand messages and then to scale the
// result appropriately.  In all cases "instance" must be an existing
// instance of this Random class, appropriately initialized.  This approach
// (instead of -drand methods etc) is used for efficiency.
//
// int irand(id instance, int n)
//	Generates a random integer in the range 0, 1, ..., n-1.  The
//	n possible outcomes have equal probability.
//
// double drand(id instance)
//	Generates a random double, uniform in [0, 1).
//
// double urand(id instance)
//	Generates a random double, uniform in [-1, 1].

// IMPORTS
#include "random.h"
#include <stdlib.h>
#include <unistd.h>
#include <math.h>
#include <string.h>
#include <time.h>

// The actual generator, defined as a macro so it can be inlined easily.
// The first argument is the state, the second is a temporary, both long.
#define GENERATOR(s,t)	t = s/127773;\
			s = (s - t*127773)*16807 - t*2836;\
			if (s < 0) s += 2147483647;

// Instance counter -- used to vary a time-based seed by instance
static int nstreams = 0;

@implementation Random

/*------------------------------------------------------*/
/*	initWithSeed					*/
/*------------------------------------------------------*/
- initWithSeed:(long *)seed
/*
 * Initializes a new instance using *seed.
 */
{
    time_t time(), timenow;
    long temp;
    int i;

// Create a random seed if necessary
    if (*seed <= 0) {
	timenow = time((time_t *)0);
	*seed = (long)(timenow&0377777777) + nstreams*12345678 +
                ((long)getpid())*4321;
    }

// Initialize the instance
    havesaved = NO;
    state = *seed;

// Initialize the shuffle table, using the Lewis--Goodman-Miller generator
    for (i = 0; i < RANDTABLEN; i++) {
	GENERATOR(state,temp)
	table[i] = state-1;	// [0, 2^31-3]
    }

// Increment the instance count
    ++nstreams;

// Return the instance
    return self;
}


/*------------------------------------------------------*/
/*	rngstate					*/
/*------------------------------------------------------*/
- (long)rngstate
{
    return state;
}


/*------------------------------------------------------*/
/*	slgmrand					*/
/*------------------------------------------------------*/
- (long)slgmrand
/*
 * Shuffled Lewis-Goodman-Miller generator.  Returns a long in [0, MAXRAND].
 */
{
    int j;
    long temp;

// Get a new draw
    GENERATOR(state,temp)

// Select a slot (0...RANDTABLEN-1) by masking lower bits
    j = state&(RANDTABLEN-1);	// Assumes power of two

// Swap the table entry with the new draw
    temp = table[j];
    table[j] = state;

    return temp-1;
}


/*------------------------------------------------------*/
/*	normal						*/
/*------------------------------------------------------*/
- (double)normal
/*
 * function normal - returns random variable n(0,1)
 *
 * This function converts uniform random numbers to normal
 * random numbers using the standard Box-Muller algorithm.
 * Note that it may return slightly different values depending
 * on whether it is compiled with optimization, since floating point
 * registers have more precision than stored double's on some machines.
 */
{
    double x, y, r2, scale;

    if (havesaved) {
	havesaved = NO;
	return saved;
    }
    else {
	havesaved = YES;
	do {
	    x = urand(self);
	    y = urand(self);
	    r2 = x*x + y*y;
	} while (r2 >= 1.0);
	scale = sqrt(-2.0*log(r2)/r2);
	saved = y*scale;
	return x*scale;
    }
}


/*------------------------------------------------------*/
/*	randomName					*/
/*------------------------------------------------------*/
- (char *)randomName:(char *)buf
/*
 * Makes a random 3-letter null-terminated name in buf.
 * The first letter is not a vowel or x, the middle letter
 * is always a vowel.
 */
{
    char *ptr = buf;
    do
	*ptr = 'a' + irand(self,26);
    while (strchr("aeioux",*ptr) != NULL);
    ++ptr;
    switch (irand(self,5)) {
    case 0: *ptr++ = 'a'; break;
    case 1: *ptr++ = 'e'; break;
    case 2: *ptr++ = 'i'; break;
    case 3: *ptr++ = 'o'; break;
    case 4: *ptr++ = 'u'; break;
    }
    *ptr++ = 'a' + irand(self,26);
    *ptr = '\0';
    return buf;
}

@end
