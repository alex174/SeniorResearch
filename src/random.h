// The Santa Fe Stock Market -- Interface for Random class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _Random_h
#define _Random_h

#include <objc/Object.h>

// MACROS
#define RANDTABLEN	64	// Must be power of 2
#define MAXRAND		2147483645
#define RANDFACT	(1.0/(MAXRAND+1.0))
#define URANDFACT	(2.0/MAXRAND)
#define irand(r,x)	((int)(((double)[r slgmrand])*RANDFACT*(double)(x)))
#define drand(r)	(((double)[r slgmrand])*RANDFACT)
#define urand(r)	(((double)[r slgmrand])*URANDFACT-1.0)

@interface Random : Object
{
    double saved;
    long table[RANDTABLEN];
    long state;
    BOOL havesaved;
}

- initWithSeed:(long *)seed;
- (long)rngstate;
- (long)slgmrand;
- (double) normal;
- (char *)randomName:(char *)buf;

@end

#endif /* _Random_h */
