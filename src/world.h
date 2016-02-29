// The Santa Fe Stock Market -- Interface for World class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _World_h
#define _World_h

#include <objc/Object.h>

@interface World : Object
{
    double dividendscale;
    double saveddividend;
    double savedprice;
    int *pupdown;		/* array, dimension UPDOWNLOOKBACK */
    int *dupdown;		/* array, dimension UPDOWNLOOKBACK */
    double *divhistory;		/* array, dimension maxhistory */
    double *pricehistory;	/* array, dimension maxhistory */
    double *aweight;		/* array, dimension NMAS */
    double *bweight;		/* array, dimension NMAS */
    int phistory_top;
    int dhistory_top;
    int pupdown_top;
    int dupdown_top;
    int maxhistory;
}

// PUBLIC METHODS

+ (const char *)descriptionOfBit:(int)n;
+ (const char *)nameOfBit:(int)n;
+ (int)bitNumberOf:(const char *)name;
+ writeNamesToFile:(FILE *)fp;
- (int)initWithBaseline:(double)baseline;
- setPrice:(double)p;
- setDividend:(double)d;
- makeBitVector;
- (int)pricetrend:(int)n;
- check;

@end

#endif /* _World_h */
