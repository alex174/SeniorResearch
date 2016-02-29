// The Santa Fe Stock Market -- Interface for Agent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _Agent_h
#define _Agent_h

#include <objc/Object.h>

// Macros for use by agent classes
#define WORD(bit)	(bit>>4)

// Global variables for all agents
extern void **paramslist;
extern int *SHIFT;
extern unsigned int *MASK;
extern unsigned int *NMASK;

@interface Agent : Object
{
@public
    double demand;	// bid or -offer
    double profit;	// exp-weighted moving average
    double wealth;	// total agent wealth
    double fitness;	// fitness for use in evolution
    double position;	// total shares of stock
    double cash;	// total agent cash
    Agent *next;	// next agent of same type
    int nameidx;	// index of name of this agent in nameTree
    int tag;		// agent number (index into AgentManager's alist[])
    int lastgatime;	// last time the GA was run, or MININTGR if none
    int gacount;	// number of times the GA has run, or 0 if none
    short int type;	// this agent's type index
    BOOL enabled;	// is agent enabled?
    BOOL selected;	// is agent selected? (for frontend)
}

// CLASS METHODS FOR INITIALIZATION
+ setnumtypes:(int)ntypes;
+ makebittables:(int)nbits;

// CLASS METHODS FOR OVERRIDING BY SUBCLASSES
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
+ printDetails:(const char *)string to:(FILE *)fp forClass:(int)class;
+ printDetails:(const char *)string to:(FILE *)fp forType:(int)thetype;
+ (int)outputInt:(int)n forClass:(int)class;
+ (double)outputReal:(int)n forClass:(int)class;
+ (const char *)outputString:(int)n forClass:(int)class;
+ (int)outputInt:(int)n forType:(int)thetype;
+ (double)outputReal:(int)n forType:(int)thetype;
+ (const char *)outputString:(int)n forType:(int)thetype;

// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN
- init;		// dummy, to catch misuse (use initAgent:type:)
- (const char *)shortname;
- (const char *)fullname;
- creditEarningsAndPayTaxes;
- (double)constrainDemand:(double *)slope :(double)trialprice;
- (int *(*)[4])bitDistribution;

// PUBLIC INSTANCE METHODS, OFTEN OVERRIDDEN BY SUBCLASSES
- initAgent:(int)thetag type:(int)thetype;
- check;
- prepareForTrading;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;
- updatePerformance;
- setEnabled:(BOOL)flag;
- (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum;
- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
- printDetails:(const char *)detailtype to:(FILE *)fp;
- (int)outputInt:(int)n;
- (double)outputReal:(int)n;
- (const char *)outputString:(int)n;

@end

#endif /* _Agent_h */
