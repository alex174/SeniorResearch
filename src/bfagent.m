// The Santa Fe Stock Market -- Implementation of BFagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// This is the most sophisticated (and most complicated) agent developed
// for the Santa Fe Stock Market.  It is the one described in the 1996
// SFI Working Paper, though that paper only describes a subset of the
// possible options.
//
// Each BF agent is endowed with "numrules" forecasting rules.  [Parameters
// like "numrules" are set in the parameter file for the agent type.]  These
// rules have two parts: conditions and forecasting parameters.  The
// conditions for each rule specify a required value (on or off) for zero
// or more of the "world bits" that reflect the current state of the market
// (see World.m).  A particular rule is only "active" in a given period if
// all its conditions are satisfied.  The forecasting parameters are used
// to make a prediction for p(t+1)+d(t+1) from a trial value ("trialprice")
// for p(t) and the most recent dividend d(t).  Currently these forecasts
// are given simply by:
//     forecast for p(t+1)+d(t+1)  =  a*(p(t)+d(t)) + b*d(t) +c
// where p(t) is the trialprice and a, b, and c are the forecasting parameters
// for the particular rule concerned.
//
// In a given period many rules may be active, thus giving many different
// forecasts.  An overall forecast for the agent is produced from these in
// one of three ways set by the "selectionmethod" parameter:
//  1. "average": The active rules' forecasts are averaged, weighted by
//     their strength.
//  2. "best": The forecast from the rule with the lowest current estimated
//     variance is used.
//  3. "roulette": One of the rules is selected at random with probability
//     proportional to its strength, and its forecast is used.
// The "strength" and "current estimated variance" of a rule are explained
// later.  These methods all exclude rules which have been active fewer than
// "mincount" times since their creation.  If there are no active rules at all,
// or no active rules after the mincount exclusion, then fallback methods are
// used to construct a forecast; see -prepareForTrading below for details.
// 
// The overall forecast and an estimate of its accuracy (variance) determines
// the desired holding for a given trialprice, and hence the demand, via a
// standard risk-aversion calculation.  This involves the risk-aversion
// parameter "lambda", the maximum bid parameter "maxbid", and the
// "individual" parameter which specifies how overall variances are determined.
// See -getDemandAndSlope:forPrice: below for details.
//
// Note that the overall forecast, as specified by effective a, b, and c
// parameters, is chosen once and for all for each period.  If the trialprice
// is iterated in multiple calls to -getDemandAndSlope:forPrice:, then the
// actual forecast varies linearly with slope a.  

// After an actual value for p(t+1)+d(t+1) is known, each previously active
// rule can be scored on the accuracy of its forecast.  A simple squared-error
// (actual - forecast)^2 is used, clipped above at "maxdev".  The "current
// estimated variance" v of each rule is formed as an exponentially-weighted
// moving average of these squared errors:
//        (new v)  =  A*(old v)  +  (1-A)*(squared error)
// with A = exp(-1/tauv) for a healing-time parameter "tauv".
//
// This "current estimated variance" v of each rule is also transformed
// into the rule's "strength"  (see below), using the relation:
//        strength  =  C - v - bitcost*specificity
// Here "bitcost" is a parameter and "specificity" is the number of conditions
// in the rule (the number of on/off condition bits).  C is a constant chosen
// to make the strength positive:
//        C = maxdev + bitcost*(maximum possible specificity)
// The delayed


// PUBLIC METHODS
// + initClass:(int)theclass
// + createType:(int)thetype from:(const char *)filename
// + writeParamsToFile:(FILE *)fp forType:(int)thetype
// + didInitialize
// + prepareTypeForTrading:(int)thetype
// + (int)lastgatimeForType:(int)thetype
// + (int)nrulesForType:(int)thetype
// + (int)nbitsForType:(int)thetype
// + (int)nonnullBitsForType:(int)thetype
// + (int)agentBitForWorldBit:(int)bit forType:(int)thetype
// + (int)worldBitForAgentBit:(int)bit forType:(int)thetype
// + printDetails:(const char *)detailtype to:(FILE *)fp forType:(int)thetype
// + (int)outputInt:(int)n forType:(int)thetype
// + (double)outputReal:(int)n forType:(int)thetype
// + (const char *)outputString:(int)n forType:(int)thetype
// - initAgent:(int)thetag type:(int)thetype
// - check
// - prepareForTrading
// - (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
// - updatePerformance
// - setEnabled:(BOOL)flag
// - (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum
// - (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
// - printDetails:(const char *)detailtype to:(FILE *)fp
// - (int)outputInt:(int)n
// - (double)outputReal:(int)n
// - free
// - copy
//	See Agent.m for descriptions.

// IMPORTS
#include "global.h"
#include "bfagent.h"
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "amanager.h"
#include "world.h"
#include "random.h"
#include "error.h"
#include "util.h"

// Typedefs and #defines for agents, parameters, rules, and strings.
// We try to localize many BF/BS differences here
typedef BFagent *Agptr;
typedef struct BFparams ParamsStruct;
typedef struct BFparams *Params;
typedef struct BF_rule RuleStruct;
typedef struct BF_rule *Rule;
#define BSorBF "BF"
#define NFIXED	1

// Keywords for the "individual" parameter
struct keytable individualkeys[] = {
    {"yes", 1},
    {"no", 0},
    {NULL, -1}
};

// Values in table of special bit names (negative, avoiding NULLBIT)
#define ENDLIST		-2
#define ALL		-3
#define SETPROB		-4
#define BADINPUT	-5
#define NOTFOUND	-6

// Maximum number of condition bits allowed.  If this is less than nworldbits
// then an attempt to use 'all' will be denied.  See also the constraint in
// -getDemandAndSlope:forPrice:.
#define MAXCONDBITS	80

// Special keywords recognized when looking for a bit name
static struct keytable specialbits[] = {
{"null", NULLBIT},
{"end", ENDLIST},
{ALLBITSNAME, ALL},
{"all", ALL},		// Historical synonym for ALLBITSNAME -- avoid
{"p", SETPROB},
{"P", SETPROB},
{"???", BADINPUT},
{NULL,  NOTFOUND}
};

// Definitions and key table for selection methods
#define SELECT_BEST	0
#define SELECT_ROULETTE	1
#define SELECT_AVERAGE	2
static struct keytable selectionkeys[] = {
    {"best", SELECT_BEST},
    {"roulette", SELECT_ROULETTE},
    {"average", SELECT_AVERAGE},
    {NULL, -1}
};

// Local function prototypes
static int strengthcompare(const void *a, const void *b);
static void copyRule(Rule, Rule);
static int tournament(Rule);
static BOOL crossover(Rule, int, int, int);
static BOOL mutate(int);
static void transferRules(Rule);
static void generalize(Rule);

// Local variables, shared by all instances
static int class;
static int condbits;		/* Often copied from p->condbits */
static int condwords;		/* Often copied from p->condwords */
static int *bitlist;		/* Often copied from p->bitlist */
static unsigned int *myworld;	/* Often copied from p->myworld */
static Params pp;
static double medianstrength;

// Working space, dynamically allocated, shared by all instances
static Rule *sorted;			/* GA temporary storage */
static Rule newrule;			/* GA temporary storage */
static unsigned int *newconds;		/* GA temporary storage */
static int nsortedmax = -1;		/* size of sorted array */
static int nnewmax = -1;		/* size of newrule array */
static int ncondmax = -1;		/* size of newconds array */
static int *bits;			/* work array during startup */
static double *probs;			/* work array during startup */


// PRIVATE METHODS
@interface BFagent(Private)
- fMoments:(double *)moment exclude:(int)exclude cumulative:(BOOL)cum;
- makeSorted;
- performGA;
@end


@implementation BFagent

+ initClass:(int)theclass
{
// Save our class
    class = theclass;

// Allocate space for the bitlists
    bits = (int *)getmem(sizeof(int)*MAXCONDBITS);
    probs = (double *)getmem(sizeof(double)*MAXCONDBITS);

    return self;
}


+ createType:(int)thetype from:(const char *)filename
{
    int i, bit, nnulls;
    double currentprob;
    Params params;
    BOOL done;
#define CREATEMETHOD "["BSorBF"agent +createType:from:]"
#define READINT(i,min,max)	params->i = readInt(#i,min,max)
#define READREAL(x,min,max)	params->x = readDouble(#x,min,max)
#define READKEY(i,key)		params->i = readKeyword(#i,key)

// Allocate space for our parameters, store in paramslist
    params = (Params)getmem(sizeof(ParamsStruct));
    paramslist[thetype] = (void *)params;

// Set predefined entries
    params->class = class;	// not used, but useful in debugger
    params->type = thetype;	// not used, but useful in debugger
    params->inversebitlist = NULL;	// Only allocated if needed
    params->lastgatime = 1;

// Open parameter file
    (void) openInputFile(filename, BSorBF"agent parameters");

// Read in general parameters
    READINT(numrules,4,1000);
    READREAL(tauv,1.0,100000.0);
    READREAL(lambda,0.0,100000.0);
    READREAL(maxbid,0.0,1000.0);
    READKEY(selectionmethod,selectionkeys);
    READINT(mincount,0,MAXINTGR);
    READREAL(subrange,0.0,1.0);
    READREAL(a_min,-1000.0,1000.0);
    READREAL(a_max,-1000.0,1000.0);
    READREAL(b_min,-1000.0,1000.0);
    READREAL(b_max,-1000.0,1000.0);
    READREAL(c_min,-1000.0,1000.0);
    READREAL(c_max,-1000.0,1000.0);
    READREAL(newrulevar,0.001,1000.0);
    READREAL(initvar,0.001,1000.0);
    READREAL(bitcost,0.0,1.0);
    READREAL(maxdev,0.001,1e6);
    READKEY(individual,individualkeys);
    READREAL(bitprob,0.0,1.0);

// Read in the list of bits, storing it in a work array for now
    nnulls = 0;
    currentprob = params->bitprob;
    for (i=0, done=NO; done==NO;) {
	bit = readBitname("bitnames",specialbits);
	switch (bit) {
	case ENDLIST:
	case ALL:
	    done = YES;
	    break;
	case NOTFOUND:
	    break;	// error recorded by readBitname()
	case BADINPUT:
	    abandonIfError(CREATEMETHOD);
	    /*NOTREACHED*/
	case SETPROB:
	    currentprob = readDouble("p = prob", 0.0, 1.0);
	    break;
	default:	// NULLBIT too
	    if (i >= MAXCONDBITS) {
		saveError("bitnames: too many bits specified");
		abandonIfError(CREATEMETHOD);
		/*NOTREACHED*/
	    }
	    bits[i] = bit;	// >= 0 (ordinary bit), or NULLBIT
	    probs[i++] = currentprob;
	    if (bit == NULLBIT) ++ nnulls;
	}
    }

// Deal with all bits or no bits
    if (bit == ALL) {
	if (i != 0) {
	    saveError("bitnames: 'all' is only valid initially");
	    abandonIfError(CREATEMETHOD);
	    /*NOTREACHED*/
	}
	params->condbits = nworldbits;
	if (params->condbits > MAXCONDBITS) {
	    saveError("bitnames: insufficient MAXCONDBITS for 'all'");
	    abandonIfError(CREATEMETHOD);
	    /*NOTREACHED*/
	}
	for (i=0; i < params->condbits; i++) {
	    bits[i] = i;
	    probs[i] = currentprob;
	}
    }
    else if (i - nnulls < 1) {
	saveError("bitnames: no valid bits");
	abandonIfError(CREATEMETHOD);
	/*NOTREACHED*/
    }
    else
	params->condbits = i;
    params->nnulls = nnulls;

// Allocate permanent space for bit and probability lists, and copy them there
    params->bitlist = (int *)getmem(sizeof(int)*params->condbits);
    params->problist = (double *)getmem(sizeof(double)*params->condbits);
    for (i=0; i < params->condbits; i++) {
	params->bitlist[i] = bits[i];
	params->problist[i] = probs[i];
    }

// Set up or enlargen the bit-packing tables if necessary
    [Agent makebittables:params->condbits];

// Allocate space for our world bits, clear initially
    params->condwords = (params->condbits+15)/16;
    params->myworld = (unsigned int *)getmem(
				sizeof(unsigned int)*params->condwords);
    for (i=0; i<params->condwords; i++)
	params->myworld[i] = 0;

// Read in GA parameters
    READINT(gainterval,1,MAXINTGR);
    READINT(firstgatime,0,MAXINTGR);
    READREAL(newfrac,1.0/params->numrules,1.0);
    READREAL(pcrossover,0.0,1.0);
    READREAL(plinear,0.0,1.0);
    READREAL(prandom,0.0,1.0-params->plinear);
    READREAL(pmutation,0.0,1.0);
    READREAL(plong,0.0,1.0);
    READREAL(pshort,0.0,1.0-params->plong);
    READREAL(nhood,0.0,1.0);
    READINT(longtime,1,MAXINTGR);
    READREAL(genfrac,0.0,1.0);

// Quit if there were errors
    abandonIfError(CREATEMETHOD);

// Compute derived parameters
    params->gaprob = 1.0/params->gainterval;
    params->nnew = (int)(params->numrules*params->newfrac + 0.5);
    params->a_range = params->a_max - params->a_min;
    params->b_range = params->b_max - params->b_min;
    params->c_range = params->c_max - params->c_min;

// Record maxima needed for GA working space
    if (params->numrules > nsortedmax) nsortedmax = params->numrules;
    if (params->nnew > nnewmax) nnewmax = params->nnew;
    if (params->condwords > ncondmax) ncondmax = params->condwords;

    return self;
}


+ writeParamsToFile:(FILE *)fp forType:(int)thetype
{
    int i;
    char buf[32];
    double currentprob, *problist;
    Params params = (Params)paramslist[thetype];
#define SHOWINT(i)	showint(fp,#i,params->i)
#define SHOWREAL(x)	showdble(fp,#x,params->x)

// Write out general parameters
    SHOWINT(numrules);
    SHOWREAL(tauv);
    SHOWREAL(lambda);
    SHOWREAL(maxbid);
    showstrng(fp, "selectionmethod", findkeyword(params->selectionmethod,
				    selectionkeys, "selection method"));
    SHOWINT(mincount);
    SHOWREAL(subrange);
    SHOWREAL(a_min);
    SHOWREAL(a_max);
    SHOWREAL(b_min);
    SHOWREAL(b_max);
    SHOWREAL(c_min);
    SHOWREAL(c_max);
    SHOWREAL(newrulevar);
    SHOWREAL(initvar);
    SHOWREAL(bitcost);
    SHOWREAL(maxdev);
    showstrng(fp, "individual", findkeyword(params->individual,
				individualkeys, "individual"));
    SHOWREAL(bitprob);

// Write out list of bits
    condbits = params->condbits;
    bitlist = params->bitlist;
    problist = params->problist;
    currentprob = params->bitprob;
    sprintf(buf, "-- %d condition bits --", condbits - params->nnulls);
    showstrng(fp, buf, "");
    for (i=0; i<condbits; i++) {
	if (problist[i] != currentprob) {
	    currentprob = problist[i];
	    sprintf(buf,"p %.4f",currentprob);
	    showbarestrng(fp, "(new bitprob for following bits)", buf);
	}
	showstrng(fp, [World descriptionOfBit:bitlist[i]],
			[World nameOfBit:bitlist[i]]);
    }
    showstrng(fp,"(end of bit list)","end");

// Write out GA parameters
    SHOWINT(gainterval);
    SHOWINT(firstgatime);
    sprintf(buf, "newfrac (nnew = %d)", params->nnew);
    showdble(fp, buf, params->newfrac);
    SHOWREAL(pcrossover);
    SHOWREAL(plinear);
    SHOWREAL(prandom);
    SHOWREAL(pmutation);
    SHOWREAL(plong);
    SHOWREAL(pshort);
    SHOWREAL(nhood);
    SHOWINT(longtime);
    SHOWREAL(genfrac);

    return self;
}


+ didInitialize
{
    Rule rptr, newtop;
    unsigned int *conditions;

// Free working space we're done with
    free(probs);
    free(bits);

// Allocate working space for GA
    sorted = (Rule *)getmem(sizeof(Rule)*nsortedmax);
    newrule = (Rule)getmem(sizeof(RuleStruct)*nnewmax);
    newconds = (unsigned int *)getmem(sizeof(unsigned int)*ncondmax*nnewmax);

// Tie up pointers for conditions
    newtop = newrule + nnewmax;
    conditions = newconds;
    for (rptr = newrule; rptr < newtop; rptr++) {
	rptr->conditions = conditions;
	conditions += ncondmax;
    }

    return self;
}


+ prepareTypeForTrading:(int)thetype
/*
 * Called at the start of each trading period for each agent type.
 */
{
    int i, n;
    Params params;

// Make a "myworld" string of bits extracted from the full "realworld"
// bitstring.
    params = (Params)paramslist[thetype];
    condwords = params->condwords;
    condbits = params->condbits;
    bitlist = params->bitlist;
    myworld = params->myworld;
    for (i = 0; i < condwords; i++)
	myworld[i] = 0;
    for (i=0; i < condbits; i++) {
	if ((n = bitlist[i]) >= 0)			// Ignore nulls
	    myworld[WORD(i)] |= realworld[n] << SHIFT[i];
    }

    return self;
}


+ (int)lastgatimeForType:(int)thetype
{
    return ((Params)paramslist[thetype])->lastgatime;
}


+ (int)nrulesForType:(int)thetype
{
    return ((Params)paramslist[thetype])->numrules;
}


+ (int)nbitsForType:(int)thetype
{
    return ((Params)paramslist[thetype])->condbits;
}


+ (int)nonnullBitsForType:(int)thetype
{
    Params params = (Params)paramslist[thetype];
    return params->condbits - params->nnulls;
}


+ (int)agentBitForWorldBit:(int)bit forType:(int)thetype
/*
 * This translates world bit numbers to agent bit numbers by setting up
 * an inverse translation table.  It's only needed if there are output
 * specifications requesting data on agent bit usage.
 */
{
    int i;
    int *inversebitlist;
    Params params;

    if (bit < 0 || bit >= nworldbits)
	[self error:"illegal bit %d in +agentBitForWorldBit::forType", bit];

    params = (Params)paramslist[thetype];

// Make inverse translation table on first request
    if (!params->inversebitlist) {
	inversebitlist = (int *)getmem(sizeof(int)*nworldbits);
	for (i=0; i<nworldbits; i++) inversebitlist[i] = -1;
	bitlist = params->bitlist;
	for (i=0; i<params->condbits; i++)
	    if (bitlist[i] >= 0) inversebitlist[bitlist[i]] = i;
	params->inversebitlist = inversebitlist;
    }

    return params->inversebitlist[bit];
}


+ (int)worldBitForAgentBit:(int)bit forType:(int)thetype
{
    Params params = (Params)paramslist[thetype];

    if (bit < 0 || bit >= params->condbits)
	[self error:"illegal bit %d in +worldBitForAgentBit:forType:", bit];
    return params->bitlist[bit];
}


+ printDetails:(const char *)detailtype to:(FILE *)fp forType:(int)thetype
/*
 * This is used for an output detail specification at the type level only.
 * E.g., TYPE BF1 detail(spec) END
 * Current options "spec" are:
 * 1. moments
 *	Prints out the mean and variance of the a, b, and c forecasting
 *      parameters, and of the rule's variances, in the order mean(a),
 *      var(a), mean(b), ..., var(variance).  All of these values are
 *	averaged over all agents in this type.  The values for a, b, or c
 *      are omitted if the parameter is not in use; e.g., mean(b) and var(b)
 *	would be omitted if b_min = b_max in the parameter file.
 * 2. momentsN
 *	N is an integer, e.g., "moments20".  Same as "moments" except that
 *	the weakest N rules (by "strength") are omitted from the means
 *	and variances.
 */
{
    Agptr agid;
    char *ptr;
    int i;
    double moment[8];
    int which[8];
    int exclude = 0;
    int counttype = 1;
    Params params = (Params)paramslist[thetype];

    if (strcmp(detailtype, "gainterval") == EQ) {
	fprintf(fp, "%d ", params->gainterval);
	return self;
    }

// The specification must start with "moments"
    if (strncmp(detailtype, "moments", 7) != EQ)
	return [super printDetails:detailtype to:fp forType:thetype];

// Deal with "momentsN"
    if (detailtype[7] != EOS) {
	exclude = (int)strtol(detailtype+7, &ptr, 10);
	if (*ptr != EOS || exclude < 0)
	    exclude = 0;
    }

// Compute the moments, summed over all agents in this type
    agid = (Agptr)[agentManager firstAgentInType:thetype];
    if (!agid) return self;
    [agid fMoments:moment exclude:exclude cumulative:NO];
    for (agid = (Agptr)agid->next; agid != NULL; agid = (Agptr)agid->next) {
	[agid fMoments:moment exclude:exclude cumulative:YES];
	counttype++;
    }

// Normalize
    for (i=0; i<8; i++) {
	moment[i] /= (double)counttype;
	which[i] = 1;
    }
    
// Arrange to omit any unused parameters
    if (params->a_min == params->a_max) which[1] = which[0] = 0;
    if (params->b_min == params->b_max) which[3] = which[2] = 0;
    if (params->c_min == params->c_max) which[5] = which[4] = 0;

// Print out the values
    for (i=0; i<8; i++)
	if (which[i]) fprintf(fp,"%f ",moment[i]);
    putc('\n', fp);

    return self;
}


+ (int)outputInt:(int)n forType:(int)thetype
{
    int val;
    Params params = (Params)paramslist[thetype];

    switch(n) {
    case 20: val = params->mincount;	break;
    case 21: val = params->gainterval;	break;
    case 22: val = params->firstgatime;	break;
    case 23: val = params->longtime;	break;
    default: val = 0;
    	[self error:"Invalid outputInt code %d", n];
    }
    return val;
}


+ (double)outputReal:(int)n forType:(int)thetype
{
    double val;
    Params params = (Params)paramslist[thetype];

    switch(n) {
    case 41: val = params->tauv;	break;
    case 42: val = params->lambda;	break;
    case 43: val = params->maxbid;	break;
    case 44: val = params->subrange;	break;
    case 45: val = params->a_min;	break;
    case 46: val = params->a_max;	break;
    case 47: val = params->b_min;	break;
    case 48: val = params->b_max;	break;
    case 49: val = params->c_min;	break;
    case 50: val = params->c_max;	break;
    case 51: val = params->newrulevar;	break;
    case 52: val = params->initvar;	break;
    case 53: val = params->bitcost;	break;
    case 54: val = params->maxdev;	break;
    case 55: val = params->bitprob;	break;
    case 56: val = params->newfrac;	break;
    case 57: val = params->pcrossover;	break;
    case 58: val = params->plinear;	break;
    case 59: val = params->prandom;	break;
    case 60: val = params->pmutation;	break;
    case 61: val = params->plong;	break;
    case 62: val = params->pshort;	break;
    case 63: val = params->nhood;	break;
    case 64: val = params->genfrac;	break;
    default: val = 0.0;
    	[self error:"Invalid outputReal code %d", n];
    }
    return val;
}


+ (const char *)outputString:(int)n forType:(int)thetype
{
    const char *val;
    Params params = (Params)paramslist[thetype];

    switch(n) {
    case 11: val = findkeyword(params->selectionmethod, selectionkeys,
					"selection method"); break;
    case 12: val = findkeyword(params->individual, individualkeys,
					"individual");	break;
    default: val = "?";
    	[self error:"Invalid outputString code %d", n];
    }
    return val;
}


- initAgent:(int)thetag type:(int)thetype
{
    Rule rptr;
    unsigned int *conditions, *cond;
    int	word, bit, specificity;
    double *problist;
    double abase, bbase, cbase, asubrange, bsubrange, csubrange;
    double newrulevar, bitcost;

// Initialize generic variables common to all agents
    [super initAgent:thetag type:thetype];

// Initialize our instance variables
    p = paramslist[thetype];
    activelist = NULL;
    oldactivelist = NULL;
    variance = p->initvar;
    global_mean = price + dividend;
    forecast = oldforecast = global_mean;
    avstrength = medstrength = 0.0;

// Extract some things for rapid use here
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;
    problist = p->problist;
    newrulevar = p->newrulevar;
    bitcost = p->bitcost;

// Allocate memory for rules and their conditions
    rule = (Rule) getmem(sizeof(RuleStruct)*p->numrules);
    rptrtop = rule + p->numrules;
    conditions = (unsigned int *) getmem(
				sizeof(unsigned int)*p->numrules*condwords);

// Iniitialize the rules
    for (rptr = rule; rptr < rptrtop; rptr++) {
	rptr->forecast = 0.0;
	rptr->oldforecast = global_mean;
	rptr->variance = newrulevar;
	rptr->strength =  0.0;
	rptr->birth = 1;
	rptr->lastused = 1;
	rptr->lastactive = 1;
	rptr->specificity = 0;
	rptr->count = 0;
	rptr->next = NULL;
	rptr->oldnext = NULL;

    // Allocate space for this rule's conditions out of total allocation
	rptr->conditions = conditions;
	conditions += condwords;

    // Initialise all conditions to don't care
	cond = rptr->conditions;
	for (word = 0; word < condwords; word++)
	    cond[word] = 0;

    // Add non-zero bits as specified by probabilities
	if (rptr >= rule+NFIXED) {	// protect first NFIXED rules
	    for (bit = 0; bit < condbits; bit++) {
		if (bitlist[bit] < 0)
		    cond[WORD(bit)] |= MASK[bit];	// Set null bits to 3
		else if (drand(rng) < problist[bit]){
		    cond[WORD(bit)] |= (irand(rng,2)+1) << SHIFT[bit];
		    ++rptr->specificity;
		}
	    }
	}
	rptr->specfactor = (condbits - p->nnulls - rptr->specificity)*bitcost;
    }

// Compute average specificity
    specificity = 0;
    for (rptr = rule; rptr < rptrtop; rptr++)
	specificity += rptr->specificity;
    avspecificity = ((double) specificity)/p->numrules;

// Set the forecasting parameters for each forecast to random values in a
// fraction "subrange" of their range, centered at the midpoint.  For
// subrange=1 this is the whole range (min to max).  For subrange=0.5,
// values lie between 1/4 and 3/4 of this range.  subrange=0 gives
// homogeneous agents, with values at the middle of their min-max range.
    abase = p->a_min + 0.5*(1.-p->subrange)*(p->a_range);
    bbase = p->b_min + 0.5*(1.-p->subrange)*p->b_range;
    cbase = p->c_min + 0.5*(1.-p->subrange)*(p->c_range);
    asubrange = p->subrange*p->a_range;
    bsubrange = p->subrange*p->b_range;
    csubrange = p->subrange*p->c_range;
    for (rptr = rule; rptr < rptrtop; rptr++) {
	rptr->a = abase + drand(rng)*asubrange;
	rptr->b = bbase + drand(rng)*bsubrange;
	rptr->c = cbase + drand(rng)*csubrange;
    }

    return self;
}


- check
{
    int bit, specificity, r;
    unsigned int *cond;
    Rule rptr;

// Specificity should be equal to the number of non-# bits
    condbits = p->condbits;
    for (r = 0; r < p->numrules; r++) {
	rptr = rule + r;
	cond = rptr->conditions;
	specificity = - p->nnulls;
	for (bit = 0; bit < condbits; bit++)
	    if ((cond[WORD(bit)]&MASK[bit]) != 0)
		specificity++;

	if (rptr->specificity != specificity)
	    message("*a: agent %2d %s specificity error: rule %2d,"
		    " actual %2d, stored %2d",
		    tag, [self shortname],r,specificity,rptr->specificity);
    }
    [super check];
    return self;
}


- prepareForTrading
/*
 * Set up a new active list for this agent's rules, and compute the
 * coefficients pdcoeff and offset in the equation
 *	forecast = pdcoeff*(trialprice+dividend) + offset
 *
 * The active list of all the rules matching the present conditions is saved
 * for later updates.
 */
{
    Rule rptr, *nextptr;
    unsigned int real0, real1, real2, real3, real4;
    int mincount, count;
    double weight, forecastvar, a, b, c, sum, sumv, x, minval;
    BOOL done;

// First the genetic algorithm is run if due
    if (t >= p->firstgatime && drand(rng) < p->gaprob) {
	[self performGA];
	activelist = NULL;	// previous rules get ignored after GA
    }

// Preserve previous forecast and active list
    oldforecast = forecast;
    oldactivelist = activelist;
    for (rptr = activelist; rptr!=NULL; rptr = rptr->next) {
	    rptr->oldnext = rptr->next;
	    rptr->oldforecast = rptr->forecast;
    }

// Main inner loop over rules.  We set this up separately for each
// value of condwords, for speed.  It's ugly, but fast.  Don't mess with
// it!  Taking out rptr->conditions will NOT make it faster!  The highest
// condwords allowed for here sets the maximum number of condition bits
// permitted (no matter how large MAXCONDBITS).
    nextptr = &activelist;	/* start of linked list */
    myworld = p->myworld;
    nactive = 0;
    real0 = myworld[0];
    switch (p->condwords) {
    case 1:
	for (rptr = rule; rptr < rptrtop; rptr++) {
	    if (rptr->conditions[0] & real0) continue;
	    *nextptr = rptr;
	    nextptr = &rptr->next;
	    rptr->lastactive = t;
	    ++nactive;
	}
	break;
    case 2:
	real1 = myworld[1];
	for (rptr = rule; rptr < rptrtop; rptr++) {
	    if (rptr->conditions[0] & real0) continue;
	    if (rptr->conditions[1] & real1) continue;
	    *nextptr = rptr;
	    nextptr = &rptr->next;
	    rptr->lastactive = t;
	    ++nactive;
	}
	break;
    case 3:
	real1 = myworld[1];
	real2 = myworld[2];
	for (rptr = rule; rptr < rptrtop; rptr++) {
	    if (rptr->conditions[0] & real0) continue;
	    if (rptr->conditions[1] & real1) continue;
	    if (rptr->conditions[2] & real2) continue;
	    *nextptr = rptr;
	    nextptr = &rptr->next;
	    rptr->lastactive = t;
	    ++nactive;
	}
	break;
    case 4:
	real1 = myworld[1];
	real2 = myworld[2];
	real3 = myworld[3];
	for (rptr = rule; rptr < rptrtop; rptr++) {
	    if (rptr->conditions[0] & real0) continue;
	    if (rptr->conditions[1] & real1) continue;
	    if (rptr->conditions[2] & real2) continue;
	    if (rptr->conditions[3] & real3) continue;
	    *nextptr = rptr;
	    nextptr = &rptr->next;
	    rptr->lastactive = t;
	    ++nactive;
	}
	break;
    case 5:
	real1 = myworld[1];
	real2 = myworld[2];
	real3 = myworld[3];
	real4 = myworld[4];
	for (rptr = rule; rptr < rptrtop; rptr++) {
	    if (rptr->conditions[0] & real0) continue;
	    if (rptr->conditions[1] & real1) continue;
	    if (rptr->conditions[2] & real2) continue;
	    if (rptr->conditions[3] & real3) continue;
	    if (rptr->conditions[4] & real4) continue;
	    *nextptr = rptr;
	    nextptr = &rptr->next;
	    rptr->lastactive = t;
	    ++nactive;
	}
	break;
#if MAXCONDBITS > 5*16
#error Too many condition bits (MAXCONDBITS)
#endif
    }
    *nextptr = NULL;	// end of linked list

// Now we have a list of "active" rules that match the current bits.  We
// normally construct a single forecast from these in one of four ways:
//  1. If the active list is empty, average over the forecasts of ALL
//     rules, weighted by "strength".
//  2. (selectionmethod SELECT_AVERAGE): Average over all the active rules'
//     forecasts, weighted by "strength".
//  3. (selectionmethod SELECT_BEST): Select the rule with the lowest current
//     variance and use its forecast.
//  4. (selectionmethod SELECT_ROULETTE): Select one of the rules at random
//     with probability proportional to "strength", and use its forecast.
// All of these methods exclude rules which have been active fewer than
// "mincount" times since their creation.  If there are no active rules
// remaining after this exclusion, a fifth method is used:
//  5. Forecast "global_mean", independent of trialprice.

    chosenrule = NULL;
    forecastvar = variance;
    done = NO;
    mincount = p->mincount;

// Method 1 -- weighted average over all rules if none are active
    if (activelist == NULL) {
	a = 0.0;
	b = 0.0;
	c = 0.0;
	sum = 0.0;
	for (rptr = rule; rptr < rptrtop; rptr++)
	    if (rptr->count >= mincount) {
		sum += weight = rptr->strength;
		a += rptr->a*weight;
		b += rptr->b*weight;
		c += rptr->c*weight;
	    }
	if (sum > 0.0) {
	    pdcoeff = a/sum;
	    offset = (b*dividend + c)/sum;
	    done = YES;
	}
    }

// Method 2 (SELECT_AVERAGE) -- weighted average over active rules 
    else if (p->selectionmethod == SELECT_AVERAGE) {
	a = 0.0;
	b = 0.0;
	c = 0.0;
	sumv = 0.0;
	sum = 0.0;
	count = 0;
	for (rptr=activelist; rptr!=NULL; rptr=rptr->next) {
	    if (++rptr->count >= mincount) {
		++count;
		sum += weight = rptr->strength;
		a += rptr->a*weight;
		b += rptr->b*weight;
		c += rptr->c*weight;
		sumv += rptr->variance;
	    }
	}
	if (sum > 0.0) {
	    pdcoeff = a/sum;
	    offset = (b*dividend + c)/sum;
	    if (p->individual) forecastvar = sumv/((double)count);
	    done = YES;
	}
    }

// Method 3 (SELECT_BEST) -- use rule with lowest variance
    else if (p->selectionmethod == SELECT_BEST) {
	minval = 1e50;
	for (rptr=activelist; rptr!=NULL; rptr=rptr->next) {
	    if (++rptr->count >= mincount) {
		if (rptr->variance < minval) {
		    minval = rptr->variance;
		    chosenrule = rptr;
		}
	    }
	}
    }

// Method 4 (SELECT_ROULETTE) -- select one proportionally to strength
    else if (p->selectionmethod == SELECT_ROULETTE) {
	sum = 0.0;
	for (rptr=activelist; rptr!=NULL; rptr=rptr->next) {
	    if (++rptr->count >= mincount)
		sum += rptr->strength;
	    rptr->cumulative = sum;
	}
	if (sum > 0.0) {
	    x = drand(rng) * sum;
	    for (rptr=activelist; rptr!=NULL; rptr=rptr->next)
		if (rptr->cumulative > x) break;
	    if (!rptr)
		message("*** ball jumped out of roulette wheel");
	    chosenrule = rptr;
	}
    }

// Methods 3 and 4, continued -- use the chosen rule to make the forecast
    if (chosenrule) {
	pdcoeff = chosenrule->a;
	offset = chosenrule->b*dividend + chosenrule->c;
	if (p->individual) forecastvar = chosenrule->variance;
	chosenrule->lastused = t;
	done = YES;
    }

// Method 5 -- use global_mean if no rules to use
    if (!done) {
	pdcoeff = 0.0;
	offset = global_mean;
    }

// Set the divisor for the risk aversion calculation
    divisor = p->lambda*forecastvar;

    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
/*
 * Returns the agent's requested bid (if >0) or offer (if <0).
 * Uses linear forecast constructed by -prepareForTrading.  The actual
 * forecast is given by
 *    forecast = pdcoeff*(trialprice+dividend) + offset
 * where pdcoeff and offset are set by -prepareForTrading.
 */
{
    forecast = (trialprice + dividend)*pdcoeff + offset;

// A risk aversion computation now gives a target holding, and its
// derivative ("slope") with respect to price.  The slope is calculated
// as the linear approximated response of a change in price on the traders'
// demand at time t, based on the change in the forecast according to the
// currently active linear rule.
    if (forecast >= 0.0) {
	demand = -((trialprice*intratep1 - forecast)/divisor + position);
	*slope = (pdcoeff-intratep1)/divisor;
    }
    else {
	forecast = 0.0;
	demand = -(trialprice*intratep1/divisor + position);
	*slope = -intratep1/divisor;
    }

// Clip bid or offer at "maxbid".  This is done to avoid problems when
// the variance of the forecast becomes very small, thought it's not clear
// that this is the best solution.
    if (demand > p->maxbid) {
	demand = p->maxbid;
	*slope = 0.0;
    }
    else if (demand < -p->maxbid) {
	demand = -p->maxbid;
	*slope = 0.0;
    }

// Return the demand and slope after checking budget constraints
    return [super constrainDemand:slope:trialprice];
}


- updatePerformance
/*
 * Updates the variance and strength of all the predictors.  Also computes
 * all the forecasts for the current period -- only the "chosen" one is
 * already correct.
 * The timing is awkward beause the forecast and update stages for each
 * period overlap in time:
 *  t-1                t                   t+1
 * |------------------|-------------------|-------------------|
 *       d      p            d      p           d      p
 *          f1------------------------>u1          f3----------
 * --------------->u0           f2-----------------------> u2
 * This shows a time line, the relative places that price (p) and dividend
 * (d) are set in each period, where the forecasts are chosen (f0-f3), and
 * where the forecasts are updated (u0-u3).
 */
{
    Rule rptr;
    double pd, deviation, ftarget, a, b, c, av, bv, maxdev;

// Construct actual forecasts for later updates.  "price" is now the
// actual trade price (the last trialprice).
    pd = price + dividend;
    for (rptr=activelist; rptr!=NULL; rptr=rptr->next)
	rptr->forecast = rptr->a*pd + rptr->b*dividend + rptr->c;

// Now update all the rules that were active in the previous period,
// since now we know how they performed.

// Precompute/extract things for speed
    a = 1.0/p->tauv;
    b = 1.0 - a;
    maxdev = p->maxdev;
// special rates for variance
// We often want this to be different from tauv
// PARAM:  100. should be a parameter  BL
    av = 1.0/p->tauv;
    bv = 1.0-av;

// Update global mean (p+d) and our variance
    ftarget = price + dividend;
    deviation = ftarget - oldforecast;
    if (fabs(deviation) > maxdev) deviation = maxdev;
    global_mean = b*global_mean + a*ftarget;
    // Use default for initial variances - for stability at startup
    if (t < p->tauv)
	variance = p->initvar;
    else
	variance = bv*variance + av*deviation*deviation;

// The first predictions are at t=1, updated here at t=2.
    if (t <= 1)
	return self;

// Update all the forecasters that were activated.
    for (rptr=oldactivelist; rptr!=NULL; rptr=rptr->oldnext) {
	deviation = ftarget - rptr->oldforecast;
	deviation *= deviation;
	if (deviation > maxdev) deviation = maxdev;
  	if (rptr->count > p->tauv)
	    rptr->variance = b*rptr->variance + a*deviation;
	else {
	    c = 1.0/rptr->count;
	    rptr->variance = (1.0 - c)*rptr->variance + c*deviation;
	}
	rptr->strength = p->maxdev - rptr->variance + rptr->specfactor;
    }

// NOTE: On exit, rptr->forecast is only guaranteed to be valid for
// forcasters which matched.  The inspector has to calculate the rest
// itself if it wants to show them all.
    return self;
}


- setEnabled:(BOOL)flag
{
    [super setEnabled:flag];

    if (!enabled) {	// cleanup for display when disabled
	forecast = 0.0;
	nactive = 0;
	activelist = NULL;
    }
    return self;
}


- (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum
{
    Rule rptr;
    static int count[4];

    if (bit < 0 || bit >= p->condbits)
	[self error:"illegal bit %d in countBit", bit];

    if (!cum)
	count[0] = count[1] = count[2] = count[3] = 0;

    for (rptr = rule; rptr < rptrtop; rptr++)
	count[(int)((rptr->conditions[WORD(bit)]>>SHIFT[bit])&3)]++;

    return &count;
}


- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
{
    Rule rptr;
    unsigned int *agntcond;
    int i;
    static int *count[4];	// Dynamically allocated 2-d array
    static int countsize = -1;	// Current size/4 of count[]
    static int prevsize = -1;

    condbits = p->condbits;

    if (cum && condbits != prevsize)
	[self error:"illegal cumulation %d != %d", condbits, prevsize];
    prevsize = condbits;

// For efficiency the static array can grow but never shrink
    if (condbits > countsize) {
	if (countsize > 0) free(count[0]);
	count[0] = (int *)getmem(sizeof(int)*4*condbits);
	count[1] = count[0] + condbits;
	count[2] = count[1] + condbits;
	count[3] = count[2] + condbits;
	countsize = condbits;
    }
    (*countptr)[0] = count[0];
    (*countptr)[1] = count[1];
    (*countptr)[2] = count[2];
    (*countptr)[3] = count[3];

    if (!cum)
	for(i=0;i<condbits;i++)
	    count[0][i] = count[1][i] = count[2][i] = count[3][i] = 0;

    for (rptr = rule; rptr < rptrtop; rptr++) {
	agntcond = rptr->conditions;
	for (i = 0; i < condbits; i++)
	    count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
    }
    return condbits;
}


- printDetails:(const char *)detailtype to:(FILE *)fp
/*
 *  This method prints out selected details on the bf agent
 */
{
    Rule rptr;
    int i;
    int *count[4];

    if (strcmp(detailtype, "gainterval") == EQ) {
	fprintf(fp, "%d ", p->gainterval);
	return self;
    }

    if (strcmp(detailtype, "stats") != EQ)
	return [super printDetails:detailtype to:fp];

    fprintf(fp, "-- details(%s) for %s --\n", detailtype, [self fullname]);

    fprintf(fp, "%g %g %g %g %g %g %g %g %g %g %d %d\n",
        profit, wealth, fitness, position, cash, avspecificity, avstrength,
        medstrength, global_mean, variance, lastgatime, gacount);

    fprintf(fp,"%d rules:\n",p->numrules);
    for (rptr = rule; rptr < rptrtop; rptr++) {
	fprintf(fp,"%2d %g %g %g %g %g %d %d %d %d %d ", rptr-rule,
	rptr->strength,rptr->variance,rptr->a,rptr->c,rptr->specfactor,
	rptr->specificity,rptr->count,rptr->lastactive,
	rptr->lastused,rptr->birth);
	for (i=0; i<condbits; i++)
	    fprintf(fp,"%d", (rptr->conditions[WORD(i)] >> SHIFT[i])&3);
	fprintf(fp,"\n");
    }

/*
    fprintf(fp,"%g %g %g %g %g %g %g %d\n", pdcoeff, offset, divisor, forecast,
        global_mean, variance,
        oldforecast, nactive);
*/

    condbits = [self bitDistribution:&count cumulative:NO];

/*  these print formats are tuned to some of my analysis programs - please
 *  don't change BL
 */
/*

    for (rptr = rule; rptr < rptrtop; rptr++) {
	fprintf(fp,"%f %f %d ",rptr->variance,rptr->strength,rptr->count);
	for (i=0; i<condbits; i++)
	    fprintf(fp,"%d ", (rptr->conditions[WORD(i)] >> SHIFT[i])&3);
	fprintf(fp,"\n");
    }
*/
/*
    fprintf(fp,"%d %f %f %d %f %f %f\n",
    nactive,avspecificity,variance,gacount,forecast,position,demand);

    for(i=0;i<condbits;i++)
	fprintf(fp,"%d ",count[1][i]+count[2][i]);
    fprintf(fp,"\n");

    sum1 = sum2 = 0;
    for(i=0;i<3;i++)
	pmtt2[i] = pm2tt2[i] = pmtt[i] = pm2tt[i] = pm[i] = pm2[i] = 0;
*/
/*
    for (rptr = rule; rptr < rptrtop; rptr++) {
	fprintf(fp,"%8.3f %8.3f %8.3f %8.3f %8.3f %2d %6d %6d %6d %6d\n",
	rptr->strength,rptr->variance,rptr->a,rptr->c,
	rptr->variance,rptr->specificity,rptr->count,rptr->lastactive,
	rptr->lastused,rptr->birth);
    }
*/
/*  get first and second moments for forecast parameters for
    both unconditional and rules using technical bit specified. */
/*
    for (rptr = rule; rptr < rptrtop; rptr++) {
    	pm[0] += rptr->c;
    	pm[1] += rptr->a;
	pm[2] += rptr->b;
    	pm2[0] += rptr->c*rptr->c;
    	pm2[1] += rptr->a*rptr->a;
	pm2[2] += rptr->b*rptr->b;
    }
    for (rptr = rule; rptr < rptrtop; rptr++) {
	if(((rptr->conditions[WORD(TTRULE)] >> SHIFT[TTRULE])&3) == 1) {
	    pmtt[0] += rptr->c;
	    pmtt[1] += rptr->a;
	    pmtt[2] += rptr->b;
	    pmtt2[0] += rptr->c*rptr->c;
	    pmtt2[1] += rptr->a*rptr->a;
	    pmtt2[2] += rptr->b*rptr->b;
	    sum1 += rptr->count;
	}
	if(((rptr->conditions[WORD(TTRULE)] >> SHIFT[TTRULE])&3) == 2) {
	    pm2tt[0] += rptr->c;
	    pm2tt[1] += rptr->a;
	    pm2tt[2] += rptr->b;
	    pm2tt2[0] += rptr->c*rptr->c;
	    pm2tt2[1] += rptr->a*rptr->a;
	    pm2tt2[2] += rptr->b*rptr->b;
	    sum2 += rptr->count;
	}
    }
 */
/*
    if((pmtt[0]==0) && (count[1][TTRULE]+count[2][TTRULE]!=0)) {
	for (rptr = rule; rptr < rptrtop; rptr++) {
	    for(i=0; i<condbits; i++)
		fprintf(fp,"%d ",(rptr->conditions[WORD(i)]>>SHIFT[i])&3);
	    fprintf(fp,"\n");
	}
    }

*/
/*
    for(i=0;i<3;i++) {
	pm[i] /=  ((double)p->numrules);
	pm2[i] = pm2[i]/((double)p->numrules);
	fprintf(fp,"%f %f %f ",pm[i],pmtt[i],pm2tt[i]);
	fprintf(fp,"%f %f %f ",pm2[i],pmtt2[i],pm2tt2[i]);
    }

    fprintf(fp,"%d %d\n",count[1][TTRULE],count[2][TTRULE]);
*/
    return self;
}


// Conditional moment calculations:
//  Find means and variances of a, b, c, and variance parameters
//  across all rules conditional on being above dud threshold.
//  This makes the moments correspond to "selected" rules.
//  This can be changed in many ways.
//  8 moments calculated and hard coded at the moment which is kind of messy

- fMoments:(double *)moment exclude:(int)exclude cumulative:(BOOL)cum
{
    Rule rptr;
    int i;
    double twt, wt, dudstrength;
    double mt[8];

    condbits = p->condbits;

    if (exclude > 0 && exclude < p->numrules) {
	[self makeSorted];
	dudstrength = sorted[exclude-1]->strength;
    }
    else
	dudstrength = -1e20;

    if (!cum)
	for(i=0;i<8;i++)
	    moment[i] = 0;

    for(i=0;i<8;i++)
	    mt[i] = 0;

    twt = 0;
    for (rptr = rule; rptr < rptrtop; rptr++) {
	if(rptr->strength >= dudstrength)
	    twt += wt = 1;
	else
	    wt = 0;
	mt[0] += wt*rptr->a;
	mt[2] += wt*rptr->b;
	mt[4] += wt*rptr->c;
	mt[6] += wt*rptr->variance;
    }
    if (twt!=0)
    for (i=0;i<8;i+=2)
	mt[i] /= twt;
    else
    for (i=0;i<8;i+=2)
	mt[i] = 0;


    twt = 0;
    for (rptr = rule; rptr < rptrtop; rptr++) {
	if(rptr->strength >= dudstrength)
	    twt += wt = 1;
	else
	    wt = 0;
	mt[1] += wt*fabs(rptr->a-mt[0]);
	mt[3] += wt*fabs(rptr->b-mt[2]);
	mt[5] += wt*fabs(rptr->c-mt[4]);
	mt[7] += wt*fabs(rptr->variance-mt[6]);
    }
    if (twt!=0)
    for (i=1;i<8;i+=2)
	mt[i] /= twt;
    else
    for (i=1;i<8;i+=2)
	mt[i] = 0;


    for(i=0;i<8;i+=1)
	moment[i] += mt[i];

    return self;
}


- (int)outputInt:(int)n
{
    int val;

    switch(n) {
    case 24: val = nactive;	break;
    default: val = 0;
    	[self error:"Invalid outputInt code %d", n];
    }
    return val;
}


- (double)outputReal:(int)n
{
    double val;

    switch(n) {
    case 65: val = forecast;	break;
    case 66: val = variance;	break;
    default: val = 0.0;
    	[self error:"Invalid outputReal code %d", n];
    }
    return val;
}


- free
{
    free(rule->conditions);
    free(rule);
    return [super free];
}


- copy
{
    Rule rptr;
    unsigned int *conditions;
    Agptr new;

// Allocate and copy instance variables
    new = (Agptr)[super copy];
    new->activelist = NULL;	// invalid now

// Allocate and copy rules
    new->rule = (Rule) getmem(sizeof(RuleStruct)*p->numrules);
    (void) memcpy(new->rule, rule, sizeof(RuleStruct)*p->numrules);
    new->rptrtop = new->rule + p->numrules;

// Allocate and copy condition bits for rules
    condwords = p->condwords;
    conditions = (unsigned int *)
			getmem(sizeof(unsigned int)*p->numrules*condwords);
    (void) memcpy(conditions, rule->conditions,
		sizeof(unsigned int)*p->numrules*condwords);

// Give rules pointers to their condition bits
    for (rptr = new->rule; rptr < new->rptrtop; rptr++) {
	rptr->next = NULL;	// invalid now
	rptr->oldnext = NULL;	// invalid now
	rptr->conditions = conditions;
	conditions += condwords;
    }

    return new;
}


- makeSorted
/*
 * Makes a list of rules sorted in increasing order of strength
 */
{
    int r;

    for (r=0; r < p->numrules; r++)
	 sorted[r] = rule+r;
    qsort(sorted, p->numrules, sizeof(Rule), strengthcompare);

    return self;
}


int strengthcompare(const void *a, const void *b)
/*
 * Comparison routine for -makeSorted
 */
{
    double diff;

    diff = (*(Rule *)a)->strength - (*(Rule *)b)->strength;
    return (diff>0.0? 1: (diff==0.0? 0: -1));
}


// Genetic algorithm
//
//  1. Sort the rules by strength, so we can replace the weakest.
//
//  2. "nnew" new rules are created in newrules[], using tournament
//     selection, crossover, and mutation.  "Tournament selection"
//     means picking two candidates purely at random and then choosing
//     the one with the higher strength.  See the crossover() and
//     mutate() routines for more details about how they work.
//
//  3. transferRules() replaces the nnew weakest old rules with the
//     nnew new ones.
//
//  4. generalize() looks for rules that haven't been triggered for
//     "longtime" and generalizes them by changing a randomly chosen
//     fraction "genfrac" of 0/1 bits to "don't care".  It does this
//     independently of strength to all rules in the population.
//
// Parameter list:
//
//   nnew	-- number of new rules produced
//		   specified as a fraction of numrules by "newfrac"
//   pmutation	-- per bit mutation prob.
//   longtime	-- generalize if rule unused for this length of time
//   genfrac	-- fraction of 0/1 bits to make don't-care when generalising
//   pcrossover	-- probability of running crossover() at all.
//   plinear	-- linear-combination crossover prob.
//   prandom	-- random-from-each-parent crossover prob.
//   plong	-- long jump prob.
//   pshort	-- short (neighborhood) jump prob.
//   nhood	-- size of neighborhood.


/*------------------------------------------------------*/
/*	GA						*/
/*------------------------------------------------------*/
- performGA
{
    Rule rptr, nr;
    int r, specificity, new, parent1, parent2;
    BOOL changed;
    double w, ava, avb, avc, sumw;
    double bitcost;
    double meanv, madv;

    ++gacount;
    p->lastgatime = lastgatime = t;

// Sort the rules by strength
    [self makeSorted];

// Extract the median strength
    medstrength = sorted[p->numrules/2]->strength;

// Compute average strength
    avstrength = 0.0;
    for (r=0; r < p->numrules; r++)
    	avstrength += rule[r].strength;
    avstrength /= ((double)p->numrules);

    fitness = avstrength;

// Set rule 0 (always all don't care) to inverse variance weight
// of the forecast parameters.  A somewhat Bayesian way for selecting
// the params for the unconditional forecast.  Remember, rule 0 is imune to
// all mutations and crossovers.  It is the default rule.
    ava = avb = avc = sumw = 0.0;
    for (r=0; r < p->numrules; r++) {
	if (rule[r].count > 0) {
	    w = 1.0/rule[r].variance;
	    sumw += w;
	    ava += rule[r].a * w;
	    avb += rule[r].b * w;
	    avc += rule[r].c * w;
	}
    }
    if (sumw != 0) {
	rule[0].a = ava/sumw;
	rule[0].b = avb/sumw;
	rule[0].c = avc/sumw;
    }

//  Find mean absolute deviation of variance
    meanv = madv = 0.0;
    for (r=0; r < p->numrules; r++)
	meanv += rule[r].variance;
    meanv /= ((double)p->numrules);
    for (r=0; r < p->numrules; r++)
	madv += fabs(rule[r].variance - meanv);
    madv /= ((double)p->numrules);

// Make instance variables visible to GA routines
    pp = p;
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;
    bitcost = p->bitcost;
    medianstrength = medstrength;

// Loop to construct nnew new rules
    for (new = 0; new < p->nnew; new++) {
	changed = NO;

    // Loop used to force diversity
	do {

	// Pick first parent using tournament selection
	    parent1 = tournament(rule);

	// Either pick second parent and do crossover, or copy and mutate
	    if (drand(rng) < p->pcrossover) {
		do
		    parent2 = tournament(rule);
		while (parent2 == parent1) ;
		changed = crossover(rule, new, parent1, parent2);
	    }
	    else {
		copyRule(&newrule[new],&rule[parent1]);
		changed = mutate(new);
	    }

	// Initialize new rule
	    if (changed) {
		nr = newrule + new;
		nr->variance = p->maxdev-nr->strength+nr->specfactor;
// If variance unreasonably low - move to reasonable level
		if (nr->variance<(rule[0].variance-madv)) {
		    nr->variance = rule[0].variance-madv;
		    nr->strength = p->maxdev - (rule[0].variance - madv) +
							    nr->specfactor;
		}
//  If new rule variance is negative, move to median strength
		if (nr->variance <= 0) {
		    nr->variance = p->maxdev - medianstrength + nr->specfactor;
		    nr->strength = medianstrength;
		}

// Initialize variables for new rule
		nr->forecast = 0.0;
		nr->oldforecast = global_mean;
		nr->count = 0;
		nr->birth = nr->lastused = nr->lastactive = t;
		nr->next = nr->oldnext = NULL;
	    }

	} while (!changed);
    }

// Replace the nnew weakest old rules by the new ones
    transferRules(rule);

// Generalize any rules that haven't been used for a long time
    generalize(rule);

// Compute average specificity
    specificity = 0;
    for (r = 0; r < p->numrules; r++) {
	rptr = rule + r;
	specificity += rptr->specificity;
    }
    avspecificity = ((double) specificity)/p->numrules;

    return self;
}


/*------------------------------------------------------*/
/*	copyRule					*/
/*------------------------------------------------------*/
static void copyRule(Rule to, Rule from)
{
    unsigned int *conditions;
    int i;

    conditions = to->conditions;	// save pointer to conditions
    *to = *from;			// copy whole rule structure
    to->conditions = conditions;	// restore pointer to conditions
    for (i=0; i<condwords; i++)
	conditions[i] = from->conditions[i];	// copy actual conditions
}


/*------------------------------------------------------*/
/*	tournament					*/
/*------------------------------------------------------*/
static int tournament(Rule rule)
/*
 * Tournament selection selects best of two rules.
 * Also, checks to make sure that the rule is active (has been matched).
 */
{
    int candidate1=0;
    int candidate2=0;
    int i;

    for (i=0; i < pp->numrules; i++) {
	candidate1 = irand(rng,pp->numrules);
	if (rule[candidate1].count > 0) break;
    }

    for (i=0; i < pp->numrules; i++) {
	candidate2 = irand(rng,pp->numrules);
	if (rule[candidate2].count > 0 && candidate2 != candidate1) break;
    }

    if (rule[candidate1].strength > rule[candidate2].strength)
	return candidate1;
    else
	return candidate2;
}


/*------------------------------------------------------*/
/*	crossover					*/
/*------------------------------------------------------*/
static BOOL crossover(Rule rule, int new, int parent1, int parent2)
/*
 * On the condition bits, crossover() uses uniform crossover -- each
 * bit is chosen randomly from one parent or the other.
 * For the real-valued forecasting parameters, crossover() does
 * one of three things:
 * 1. Choose a linear combination of the parents' parameters,
 *    weighted by strength.
 * 2. Choose each parameter randomly from each parent.
 * 3. Choose one of the parents' parameters (all from one or all
 *    from the other).
 * Method 1 is chosen with probability plinear, method 2 with
 * probability prandom, method 3 with probability 1-plinear-prandom.
 */
{
    int bit, word, specificity;
    unsigned int *cond1, *cond2, *newcond;
    Rule nr = newrule + new;
    double weight1, weight2, choice;
    int parent;

// Uniform crossover of condition bits
    newcond = nr->conditions;
    cond1 = rule[parent1].conditions;
    cond2 = rule[parent2].conditions;
    for (word = 0; word <condwords; word++)
	newcond[word] = 0;
    for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (irand(rng,2)?cond1:cond2)[WORD(bit)]&MASK[bit];

// Select one crossover method for the a, b, c forecasting parameters
    choice = drand(rng);
    if (choice < pp->plinear) {

    /* Crossover method 1 -- linear combination */
	if (rule[parent1].variance > 0 && rule[parent2].variance > 0)
	    weight1 = rule[parent2].variance /
			(rule[parent1].variance + rule[parent2].variance);
	else
	    weight1 = 0.5;
	weight2 = 1.0-weight1;
	nr->a = weight1*rule[parent1].a + weight2*rule[parent2].a;
	nr->b = weight1*rule[parent1].b + weight2*rule[parent2].b;
	nr->c = weight1*rule[parent1].c + weight2*rule[parent2].c;
    }

    else if (choice < pp->plinear + pp->prandom) {

    /* Crossover method 2 -- randomly from each parent */
	nr->a = rule[(irand(rng,2)? parent1: parent2)].a;
	nr->b = rule[(irand(rng,2)? parent1: parent2)].b;
	nr->c = rule[(irand(rng,2)? parent1: parent2)].c;
    }

    else {

    /* Crossover method 3 -- all from one parent */
	parent = (irand(rng,2)? parent1: parent2);
	nr->a = rule[parent].a;
	nr->b = rule[parent].b;
	nr->c = rule[parent].c;
    }

//  Set up rule description variables
    nr->count = 0;	// call it new in any case

//  Find specificity
    specificity = - pp->nnulls;
    for (bit = 0; bit < condbits; bit++)
	if ((nr->conditions[WORD(bit)]&MASK[bit]) != 0)
	    specificity++;
    nr->specificity = specificity;
    nr->specfactor = (condbits - pp->nnulls - specificity)*pp->bitcost;

//  Set initial strength.  If parents inactive, set to median, if active
//    set to avg of parents
    if (( ((t-rule[parent1].lastactive)>pp->longtime) ||
	((t-rule[parent2].lastactive)>pp->longtime) ) ||
		((rule[parent1].count*rule[parent2].count)==0))
	nr->strength = medianstrength;
    else
	nr->strength = 0.5*(rule[parent1].strength+rule[parent2].strength);

    return YES;	// Always report changed
}


/*------------------------------------------------------*/
/*	mutate						*/
/*------------------------------------------------------*/
static BOOL mutate(int new)
/*
 * For the condition bits, mutate() looks at each bit with
 * probability pmutation.  If chosen, a bit is changed as follows:
 *    0  ->  * with probability 2/3, 1 with probability 1/3
 *    1  ->  * with probability 2/3, 0 with probability 1/3
 *    *  ->  0 with probability 1/3, 1 with probability 1/3,
 *           unchanged with probability 1/3
 * This maintains specificity on average.
 *
 * For the forecasting parameters, mutate() may do one of two things,
 * independently for each parameter.
 * 1. "Long jump": the parameter is chosen randomly from its min-max
 *    range.
 * 2. "Short jump": the parameter is chosen randomly from a uniform
 *    distribution from oldvalue-nhood*range to oldvalue+nhood*range,
 *    where range = max-min.  Values outside the min-max range are
 *    mapped to the endpoint.
 * Method 1 is used with probability plong, method 2 is used with
 * probability pshort, and the parameter is left unchanged with
 * probability 1-plong-pshort.
 *
 * Returns YES if it actually changed anything, otherwise NO.
 */
{
    int bit;
    Rule nr = newrule + new;
    unsigned int *cond, *cond0;
    BOOL changed = NO;
    BOOL bitchanged;
    double choice, temp;

    if (pp->pmutation > 0) {
	cond0 = nr->conditions;
	for (bit = 0; bit < condbits; bit++) {
	    if (bitlist[bit] < 0) continue;	// Ignore nulls
	    if (drand(rng) < pp->pmutation) {
		cond = cond0 + WORD(bit);
		if (*cond & MASK[bit]) {
		    if (irand(rng,3) > 0) {
			*cond &= NMASK[bit];
			nr->specificity--;
		    }
		    else
			*cond ^= MASK[bit];
		    changed = YES;
		}
		else if (irand(rng,3) > 0) {
		    *cond |= (irand(rng,2)+1) << SHIFT[bit];
		    nr->specificity++;
		    changed = YES;
		}
	    }
	}
	nr->specfactor = (condbits - pp->nnulls - nr->specificity)*pp->bitcost;
    }

    bitchanged = changed;

// Mutate the a coefficient
    choice = drand(rng);
    if (choice < pp->plong) {
	/* long jump = uniform distribution between min and max */
	nr->a =  pp->a_min + pp->a_range*drand(rng);
	if (pp->a_range != 0.0) changed = YES;
    }
    else if (choice < pp->plong + pp->pshort) {
	/* short jump  = uniform within fraction nhood of range */
	temp = nr->a + pp->a_range*pp->nhood*urand(rng);
	nr->a = (temp > pp->a_max? pp->a_max:
		    (temp < pp->a_min? pp->a_min: temp));
	if (pp->a_range != 0.0) changed = YES;
    }
    /* else leave alone */

// Mutate the b coefficient
    choice = drand(rng);
    if (choice < pp->plong) {
	/* long jump = uniform distribution between min and max */
	nr->b =  pp->b_min + pp->b_range*drand(rng);
	if (pp->b_range != 0.0) changed = YES;
    }
    else if (choice < pp->plong + pp->pshort) {
	/* short jump  = uniform within fraction nhood of range */
	temp = nr->b + pp->b_range*pp->nhood*urand(rng);
	nr->b = (temp > pp->b_max? pp->b_max:
		    (temp < pp->b_min? pp->b_min: temp));
	if (pp->b_range != 0.0) changed = YES;
    }
    /* else leave alone */

// Mutate the c coefficient
    choice = drand(rng);
    if (choice < pp->plong) {
	/* long jump = uniform distribution between min and max */
	nr->c =  pp->c_min + pp->c_range*drand(rng);
	if (pp->c_range != 0.0) changed = YES;
    }
    else if (choice < pp->plong + pp->pshort) {
	/* short jump  = uniform within fraction nhood of range */
	temp = nr->c + pp->c_range*pp->nhood*urand(rng);
	nr->c = (temp > pp->c_max? pp->c_max:
		    (temp < pp->c_min? pp->c_min: temp));
	if (pp->c_range != 0.0) changed = YES;
    }
    /* else leave alone */

// Reset strength if rule inactive or if bitchanged
    if (changed) {
	if (nr->count == 0 || (t-nr->lastactive) > pp->longtime || bitchanged)
	    nr->strength = medianstrength;
	nr->count = 0;
    }

    return changed;
}


/*------------------------------------------------------*/
/*	transferRules					*/
/*------------------------------------------------------*/
static void transferRules(Rule rule)
{
    Rule rptr, nr;
    int new, nnew, j;

// Replace the weakest nnew old rules by the new ones
    nnew = pp->nnew;
    j = 0;
    for (new = 0; new < nnew; new++) {
	nr = newrule + new;
	while ((rptr = sorted[j++]) < rule+NFIXED) ; // Skip 1st NFIXED
	copyRule(rptr, nr);
    }
}


/*------------------------------------------------------*/
/*	generalize					*/
/*------------------------------------------------------*/
static void generalize(Rule rule)
/*
 * Each forecast that hasn't be used for longtime is generalized by
 * turning a fraction genfrac of the 0/1 bits to don't-cares.
 */
{
    Rule rptr;
    int r, bit, j;
    double medvar;
    BOOL changed;

    for (r = NFIXED; r < pp->numrules; r++) {	// Skip 1st NFIXED
	rptr = rule + r;
	if (t - rptr->lastactive > pp->longtime) {
	    changed = NO;
	    j = (int)ceil(rptr->specificity*pp->genfrac);
	    for (;j>0;) {
		bit = irand(rng,condbits);
		if (bitlist[bit] < 0) continue;		// Ignore nulls
		if ((rptr->conditions[WORD(bit)]&MASK[bit])) {
		    rptr->conditions[WORD(bit)] &= NMASK[bit];
		    --rptr->specificity;
		    changed = YES;
		    j--;
		}
	    }
	    if (changed) {
		rptr->count = 0;
		rptr->lastactive = t;
		rptr->specfactor = (condbits - pp->nnulls - rptr->specificity)*
								pp->bitcost;
		medvar = pp->maxdev-medianstrength+rptr->specfactor;
		if (medvar >= 0.0)
			rptr->variance = medvar;
		rptr->strength = medianstrength;
	    }
	}
    }
}

@end
