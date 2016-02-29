// The Santa Fe Stock Market -- Interface for Dividend class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _Dividend_h
#define _Dividend_h

#include <objc/Object.h>

// Note for frontend users: The DIV_* values must match the tags of the
// Dividend Inspector radio buttons.  The order (here or in IB) doesn't
// matter; it's all in the tags, which are set in the IB inspector panel.

// You can add DIV_* types; see comments on dtypekeys[] in the .m file.

typedef enum {
	DIV_AR1=0,
	DIV_MARKOV=1,
	DIV_WHITE=2,
	DIV_IID=3,
	DIV_SQUARE=4,
	DIV_TRIANGLE=5,
	DIV_SINE=6
} DivType; 

// Codes for scheduled parameter setting using EV_SET_DIVIDEND_PARAM events.
// New types can be added to the end of this list; make corresponding changes
// in Dividend.m and DivInspector.m.

typedef enum {
	DPARAM_UNKNOWN=0,
	DPARAM_DIVTYPE,
	DPARAM_PERIOD,
	DPARAM_SHOCKTIME,
	DPARAM_AMPLITUDE,
	DPARAM_ASYMMETRY,
	DPARAM_SHOCKSIZE	
} DparamType; 


@interface Dividend : Object
{
// RANDOM NUMBER GENERATOR
    id drng;
    long dseed;
// PARAMETERS
    DivType divtype;  	// type of stochastic process
    int period;
    int shocktime;
    double baseline;
    double mindividend;
    double maxdividend;
    double amplitude;
    double asymmetry;
    double shocksize;
    double rho;
    double gauss;
    BOOL rhospecified;
// DERIVED PARAMETERS
    int marktime;
    int spacetime;
    double upprob;
    double deviation;
    double shockdecay;
// STATE VARIABLES
    int time;
    double dvdnd;
    double shock;
    BOOL needsSetDerivedParams;
}

// PUBLIC METHODS

- initFromFile:(const char *)paramfile;
- writeParamsToFile:(FILE *)fp;
- (double)mean;
- (double)sd;
- (const char *)addnlInfo;
- (double)dividend;
- (double)baseline;
- addShock;
- resetShock;
- (const char *)divParamNameFor:(DparamType)paramtype;
- (const char *)divTypeNameFor:(DivType)type;

// METHODS TO SET PARAMETERS

- setParamFromString:(const char *)string;
- setDivType:(DivType)type;
- (double)setAmplitude:(double)theAmplitude;
- (int)setPeriod:(int)thePeriod;
- (double)setAsymmetry:(double)theAsymmetry;
- (double)setShocksize:(double)theShocksize;
- (int)setShocktime:(int)theShocktime;
- setRNG:rng;

// METHODS TO ACCESS PARAMETERS ETC

- (DivType)divType;
- (int)period;
- (int)shocktime;
- (double)amplitude;
- (double)asymmetry;
- (double)shocksize;
- (long)seed;
- rng;

@end

#endif /* _Dividend_h */
