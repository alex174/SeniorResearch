// The Santa Fe Stock Market -- Interface for Specialist class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _Specialist_h
#define _Specialist_h

#include <objc/Object.h>

@class Agent;

// Note for frontend users: The SP_* values must match the tags of the
// Specialist popup list.  The order (here or in IB) doesn't matter; it's
// all in the tags, which are set in the IB inspector panel.

typedef enum {
	SP_ETA=0,
	SP_ADAPTIVEETA=1,
	SP_RE=2,
	SP_VCVAR=3,
	SP_SLOPE=4
} SpecialistType;

@interface Specialist : Object
{
    double maxprice;
    double minprice;
    double eta;
    double etaincrement;
    double etainitial;
    double etamax;
    double etamin;
    double ldelpmax;
    double minexcess;
    double rea;
    double reb;
    double cvar;
    double var;
    double bidfrac;
    double offerfrac;
    Agent **idlist;
    int nenabled;
    int maxiterations;
    int varcount;
    SpecialistType sptype;
}

- initFromFile:(const char *)paramfile;
- writeParamsToFile:(FILE *)fp;
- (double)performTrading;
- completeTrades;
- setParamFromString:(const char *)string;
- setEta:(double)eta;
- setEtaIncrement:(double)etaIncrement;
- (double)eta;
- (double)etaIncrement;
- setSpecialistType:(SpecialistType)stype;
- (SpecialistType)specialistType;
- (const char *)specialistTypeNameFor:(SpecialistType)type;


@end

#endif /* _Specialist_h */
