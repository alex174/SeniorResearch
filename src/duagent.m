// The Santa Fe Stock Market -- Implementation of DUagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This is a very simple "dumb" agent, mainly intended as a demonstration
// of the minimal ingredients.  It simply tries to buy or sell "bidsize"
// shares, depending on the value of one particular world bit, "keybit".
// Since this doesn't depend on the price, this agent is really dumb and
// may destabilize a market.

#include "global.h"
#include "duagent.h"
#include "world.h"
#include "util.h"
#include "error.h"

// Local variables
static int class;


@implementation DUagent

+ initClass:(int)theclass
{
    class = theclass;	// save our class
    return self;
}


+ createType:(int)thetype from:(const char *)filename
{
    struct DUparams *params;

// Allocate space for our parameters, store in paramslist
    params = (struct DUparams *)getmem(sizeof(struct DUparams));
    paramslist[thetype] = (void *)params;

// Set predefined entries
    params->class = class;	// not used, but useful in debugger
    params->type = thetype;	// not used, but useful in debugger
   
// Open parameter file
    (void) openInputFile(filename, "DU agent parameters");

// Read in the parameters
    params->bidsize = readDouble("bidsize",-100.0,100.0);
    params->keybit = readBitname("keybit",NULL);
    abandonIfError("[DUagent +createType:from:]");

    return self;
}


+ writeParamsToFile:(FILE *)fp forType:(int)thetype
{
    struct DUparams *parm = (struct DUparams *)paramslist[thetype];;
    
    showdble(fp, "bidsize", parm->bidsize);
    showstrng(fp, "keybit", [World nameOfBit:parm->keybit]);
    return self;
}


- initAgent:(int)thetag type:(int)thetype;
{

// Initialize generic variables common to all agents
    [super initAgent:thetag type:thetype];

// Initialize our own instance variables
    p = paramslist[thetype];
    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
/*
 * Returns either +bidsize or -bidsize (unless limited by budget contraints).
 * Slope is 0, since demand is independent of trialprice..
 */
{
    demand = (realworld[p->keybit] == 1? p->bidsize: -p->bidsize);
    *slope = 0.0;
    return [super constrainDemand:slope:trialprice];
}


@end
