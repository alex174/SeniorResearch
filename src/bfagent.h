// The Santa Fe Stock Market -- Interface for BFagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _BFagent_h
#define _BFagent_h

#include "agent.h"

// Structure for list of individual forecasts
struct BF_rule {
    double forecast;		// this forecast of return
    double oldforecast;		// previous forecast
    double variance;		// variance of forecast
    double strength;		// strength = F(variance, specfactor)
    double cumulative;		// cumulative strength for roulette selection
    double a;			// (price + dividend) coefficient
    double b;			// dividend coefficient
    double c;			// constant term
    double specfactor;		// specificity factor
    struct BF_rule *next;	// list of active rules
    struct BF_rule *oldnext;	// list of active rules from previous period
    unsigned int *conditions;	// array of condition words
    int lastactive;		// time of last match on rule
    int lastused;		// last time rule used
    int birth;			// date of birth
    int specificity;		// number of non-don't-care bits in conditions
    int count;			// number of times used
};

// Parameters/variables common to all agents in a BF type
struct BFparams {
    int class;
    int type;
    int numrules;
    int selectionmethod;
    int mincount;
    int condwords;
    int condbits;
    int gainterval;
    int firstgatime;
    int longtime;	// unused time before generalize()
    int nnew;		// derived: number of new rules
    int nnulls;
    int lastgatime;
    int individual;
    double tauv;
    double lambda;
    double maxbid;
    double subrange;	// fraction of min-max range for initial random values
    double a_min,a_max;	// min and max for p+d coef
    double b_min,b_max;	// min and max for div coef
    double c_min,c_max;	// min and max for constant term
    double a_range,b_range,c_range;	// derived: max - min
    double newrulevar;	// variance assigned to a new forecaster
    double initvar;	// variance of overall forecast for t<200
    double bitcost;	// penalty parameter for specificity
    double maxdev;	// max deviation of a forecast in variance estimation
    double plinear;	// linear combination "crossover" prob.
    double prandom;	// random from each parent crossover prob.
    double plong;	// long jump prob.
    double pshort;	// short (neighborhood) jump prob.
    double nhood;	// size of neighborhood.
    double newfrac;	// fraction of rules replaced
    double pcrossover;	// probability of running crossover() at all.
    double pmutation;	// per bit mutation prob.
    double genfrac;	// fraction of 0/1 bits to generalize
    double gaprob;	// derived: 1/gainterval
    double bitprob;
    int *bitlist;		// dynamic array, length condbits
    int *inversebitlist;	// dynamic array, length nworldbits, or NULL
    double *problist;		// dynamic array, length condbits
    unsigned int *myworld;	// dynamic array, length condwords
};


@interface BFagent : Agent
{
@public
    double avspecificity;
    double avstrength;
    double medstrength;
    double forecast;
    double oldforecast;
    double global_mean;
    double variance;
    double pdcoeff;
    double offset;
    double divisor;
    struct BF_rule *rule;	// array of size numrules
    struct BF_rule *rptrtop;	// top of rule array (rule + p->numrules)
    struct BF_rule *activelist;
    struct BF_rule *oldactivelist; 	// previous active list
    struct BF_rule *chosenrule;
    struct BFparams *p;
    int nactive;
}

// CLASS METHODS OVERRIDDEN FROM Agent CLASS
+ initClass:(int)theclass;
+ createType:(int)thetype from:(const char *)filename;
+ writeParamsToFile:(FILE *)fp forType:(int)thetype;
+ didInitialize;
+ prepareTypeForTrading:(int)thetype;
+ (int)lastgatimeForType:(int)thetype;
+ (int)nrulesForType:(int)thetype;
+ (int)nbitsForType:(int)thetype;
+ (int)nonnullBitsForType:(int)thetype;
+ (int)agentBitForWorldBit:(int)bit forType:(int)thetype;
+ (int)worldBitForAgentBit:(int)bit forType:(int)thetype;
+ printDetails:(const char *)detailtype to:(FILE *)fp forType:(int)thetype;
+ (int)outputInt:(int)n forType:(int)thetype;
+ (double)outputReal:(int)n forType:(int)thetype;
+ (const char *)outputString:(int)n forType:(int)thetype;

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)thetag type:(int)thetype;
- check;
- prepareForTrading;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice;
- updatePerformance;
- setEnabled:(BOOL)flag;
- (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum;
- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
- printDetails:(const char *)detailtype to:(FILE *)fp;
- (int)outputInt:(int)n;
- (double)outputReal:(int)n;

// INSTANCE METHODS OVERRIDDEN FROM Object CLASS
- free;
- copy;

@end

#endif /* _BFagent_h */
