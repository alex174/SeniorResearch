// The Santa Fe Stock Market -- Interface for DUagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _DUagent_h
#define _DUagent_h

#include "agent.h"

// Parameters common to all agents in a DU type
struct DUparams {
    double bidsize;
    int class;
    int type;
    int keybit;
} ;


@interface DUagent : Agent
{
    struct DUparams *p;
}

// CLASS METHODS OVERRIDDEN FROM Agent CLASS
+ initClass:(int)thetype;
+ createType:(int)thetype from:(const char *)filename;
+ writeParamsToFile:(FILE *)fp forType:(int)thetype;

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)thetag type:(int)thetype;

// PUBLIC INSTANCE METHODS ADDED BY THIS CLASS
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;

@end

#endif /* _DUagent_h */
