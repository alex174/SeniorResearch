// The Santa Fe Stock Market -- Interface for FFagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _FFagent_h
#define _FFagent_h

#include "agent.h"

#define NMETHODS	8

// Structure for list of individual forecasts
struct FF_rule {
    double forecast;		// this forecast of return
    double oldforecast;		// previous forecast
    double dfdp;		// d(forecast)/d(price)
    double variance;		// variance of this forecast
    double strength;		// strength = F(variance)
    double cumstrength;		// work space for roulette wheel
    int count;			// number of times used
};


// Parameters/variables common to all agents in a FF type
struct FFparams {
    int class;
    int type;
    int numrules;
    int selectionmethod;
    double tauv;
    double lambda;
    double maxbid;
    double fcastmin;
    double fcastmax;
    double beta;
    double maxdev;
    double tauvnew;
    double a1;
    double a2;
} ;


@interface FFagent : Agent
{
@public
    struct FF_rule *rule;	// array of size p->numrules
    struct FF_rule *rptrtop;	// top of rule array (rule + p->numrules)
    struct FF_rule *chosen;	// pointer to chosen one
    struct FFparams *p;		// pointer to our parameters
    int method[NMETHODS];	// forecasting method for each rule
    int usedby[NMETHODS];	// rule number using each method, or -1
}

// CLASS METHODS OVERRIDDEN FROM Agent CLASS
+ initClass:(int)theclass;
+ createType:(int)thetype from:(const char *)filename;
+ writeParamsToFile:(FILE *)fp forType:(int)thetype;
+ (int)nrulesForType:(int)thetype;

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)thetag type:(int)thetype;
- prepareForTrading;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;
- updatePerformance;

// INSTANCE METHODS OVERRIDDEN FROM Object CLASS
- free;
- copy;

// ADDITIONAL METHODS ADDED BY THIS CLASS
+ (const char *)descriptionOfMethod:(int)n;
- makeForecast:(struct FF_rule *)rptr forPrice:(double)trialprice;

@end

#endif /* _FFagent_h */
