// The Santa Fe Stock Market -- Interface for BSagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _BSagent_h
#define _BSagent_h

#include "agent.h"

// Structure for list of individual rules
struct BS_rule {
    double strength;		// strength based on profit moving average
    double cumulative;		// cumulative strength for roulette wheel
    struct BS_rule *next;	// list of active rules
    struct BS_rule *oldnext;	// list of active rules from previous period
    int action;			// 0 for sell, 1 for buy
    unsigned int *conditions;	// array of condition words
    int lastactive;		// time of last match on rule
    int lastused;		// last time rule used
    int birth;			// date of birth
    int specificity;		// number of non-don't-care bits in conditions
    int count;			// number of times used
};

// Parameters/variables common to all agents in a BS type
struct BSparams {
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
    double bidsize;
    double maxrstrength;
    double minrstrength;
    double initrstrength;
    double taus;
    double tausdecay;
    double tausnew;
    double preverse;	// weak rule reversal prob.
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

@interface BSagent : Agent
{
@public
    double avspecificity;
    double avstrength;
    double medstrength;
    struct BS_rule *rule;       // array of size numrules
    struct BS_rule *rptrtop;    // top of rule array (rule + p->numrules)
    struct BS_rule *activelist;
    struct BS_rule *oldactivelist;      // previous active list
    struct BS_rule *chosenrule;
    struct BSparams *p;
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

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)thetag type:(int)thetype;
- check;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice;
- updatePerformance;
- setEnabled:(BOOL)flag;
- (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum;
- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;

// INSTANCE METHODS OVERRIDDEN FROM Object CLASS
- free;
- copy;

@end

#endif /* _BSagent_h */
