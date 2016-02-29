// The Santa Fe Stock Market -- Implementation of BSagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

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
// - initAgent:(int)thetag type:(int)thetype
// - check
// - (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
// - updatePerformance
// - setEnabled:(BOOL)flag
// - (int (*)[4])countBit:(int)bit cumulative:(BOOL)cum
// - (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
// - free
// - copy
//	See Agent.m for descriptions.

// IMPORTS
#include "global.h"
#include "bsagent.h"
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
typedef BSagent *Agptr;
typedef struct BSparams ParamsStruct;
typedef struct BSparams *Params;
typedef struct BS_rule RuleStruct;
typedef struct BS_rule *Rule;
#define BSorBF "BS"
#define NFIXED	2

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
static struct keytable selectionkeys[] = {
    {"best", SELECT_BEST},
    {"roulette", SELECT_ROULETTE},
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
static void reversal(Rule);

// Local variables, shared by all instances
static int class;
static int condbits;		/* Often copied from p->condbits */
static int condwords;		/* Often copied from p->condwords */
static int *bitlist;		/* Often copied from p->bitlist */
static unsigned int *myworld;	/* Often copied from p->myworld */
static Params pp;

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
@interface BSagent(Private)
- makeSorted;
- performGA;
@end


@implementation BSagent
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
    params->numrules = readInt("numrules",4,1000);
    params->bidsize = readDouble("bidsize",0.0,1000.0);
    params->selectionmethod = readKeyword("selectionmethod",selectionkeys);
    params->mincount = readInt("mincount",0,MAXINTGR);
    params->taus = readDouble("taus",1.0,100000.0);
    params->maxrstrength = readDouble("maxrstrength",1.0,100000.0);
    params->minrstrength = readDouble("minrstrength",-100.0,1000.0);
    params->initrstrength = readDouble("initrstrength",params->minrstrength,
							params->maxrstrength);
    params->bitprob = readDouble("bitprob",0.0,1.0);

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
    params->gainterval = readInt("gainterval",1,MAXINTGR);
    params->firstgatime = readInt("firstgatime",0,MAXINTGR);
    params->newfrac = readDouble("newfrac",1.0/params->numrules,1.0);
    params->pcrossover = readDouble("pcrossover",0.0,1.0);
    params->pmutation = readDouble("pmutation",0.0,1.0);
    params->preverse = readDouble("preverse",0.0,1.0);
    params->longtime = readInt("longtime",1,MAXINTGR);
    params->genfrac = readDouble("genfrac",0.0,1.0);

// Quit if there were errors
    abandonIfError(CREATEMETHOD);

// Compute derived parameters
    params->tausnew = -expm1(-1.0/params->taus);
    params->tausdecay = 1.0 - params->tausnew;
    params->gaprob = 1.0/params->gainterval;
    params->nnew = (int)(params->numrules*params->newfrac + 0.5);

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

// Write out general parameters
    showint(fp, "numrules", params->numrules);
    showdble(fp, "bidsize", params->bidsize);
    showstrng(fp, "selectionmethod", findkeyword(params->selectionmethod,
				    selectionkeys, "selection method"));
    showint(fp, "mincount", params->mincount);
    showdble(fp, "taus", params->taus);
    showdble(fp, "maxrstrength", params->maxrstrength);
    showdble(fp, "minrstrength", params->minrstrength);
    showdble(fp, "initrstrength", params->initrstrength);
    showdble(fp, "bitprob", params->bitprob);

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
    showint(fp, "gainterval", params->gainterval);
    showint(fp, "firstgatime", params->firstgatime);
    sprintf(buf,"newfrac (nnew = %d)", params->nnew);
    showdble(fp, buf, params->newfrac);
    showdble(fp, "pcrossover", params->pcrossover);
    showdble(fp, "pmutation", params->pmutation);
    showdble(fp, "preverse", params->preverse);
    showint(fp, "longtime", params->longtime);
    showdble(fp, "genfrac", params->genfrac);

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


- initAgent:(int)thetag type:(int)thetype
{
    Rule rptr;
    unsigned int *conditions, *cond;
    int	word, bit, specificity;
    double *problist;

// Initialize generic variables common to all agents
    [super initAgent:thetag type:thetype];

// Initialize our instance variables
    p = paramslist[thetype];
    activelist = NULL;
    oldactivelist = NULL;
    chosenrule = NULL;
    avstrength = p->initrstrength;
    medstrength = 0.0;

// Extract some things for rapid use here
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;
    problist = p->problist;

// Allocate memory for rules and their conditions
    rule = (Rule) getmem(sizeof(RuleStruct)*p->numrules);
    rptrtop = rule + p->numrules;
    conditions = (unsigned int *) getmem(
				sizeof(unsigned int)*p->numrules*condwords);

// Iniitialize the rules
    for (rptr = rule; rptr < rptrtop; rptr++) {
	rptr->strength = p->initrstrength;
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
	
    // Set action bit -- randomly except for 1st two
    if (rptr == rule) 		rptr->action = 0;
    else if (rptr == rule+1)	rptr->action = 1;
    else 			rptr->action = irand(rng,2);

    }

// Compute average specificity
    specificity = 0;
    for (rptr = rule; rptr < rptrtop; rptr++)
	specificity += rptr->specificity;
    avspecificity = ((double) specificity)/p->numrules;

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
 * Set up a new active list for this agent's rules.
 * Sees which rules match the present conditions and selects one of them
 * with probability proportional to strength*selectivity.
 *
 * The active list of all the rules matching the present conditions is saved
 * for later updates.
 */
{
    Rule rptr, *nextptr;
    unsigned int real0, real1, real2, real3, real4;
    int mincount;
    double sum, x, maxval;

// First the genetic algorithm is run if due
    if (t >= p->firstgatime && drand(rng) < p->gaprob) {
	[self performGA];
	activelist = NULL;	// previous rules get ignored after GA
    }

// Preserve previous active list
    oldactivelist = activelist;
    for (rptr = activelist; rptr!=NULL; rptr = rptr->next) {
	    rptr->oldnext = rptr->next;
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
// choose one of these in one of two ways:
//  1. (selectionmethod SELECT_BEST): Select the rule with the highest fitness.
//  2. (selectionmethod SELECT_ROULETTE): Select one of the rules at random
//     with probability proportional to fitness.
// Here "fitness" is defined as (specificity + 1)*strength.
// Both these methods exclude rules which have been active fewer than
// "mincount" times since their creation, or that don't have positive
// strength.  If there are no active rules remaining after this exclusion
// (or no active rules at all) then the demand will be 0.

    chosenrule = NULL;
    mincount = p->mincount;

// Method 1 (SELECT_BEST) -- use rule with highest fitness
    if (p->selectionmethod == SELECT_BEST) {
	maxval = -1e50;
	for (rptr=activelist; rptr!=NULL; rptr=rptr->next) {
	    if (++rptr->count >= mincount) {
		x = (rptr->specificity + 1)*rptr->strength;
		if (x > maxval) {
		    maxval = x;
		    chosenrule = rptr;
		}
	    }
	}
	if (chosenrule->strength <= 0.0) 
	    chosenrule = NULL;
    }

// Method 2 (SELECT_ROULETTE) -- select one proportionally to fitness
    else if (p->selectionmethod == SELECT_ROULETTE) {
	sum = 0.0;
	for (rptr=activelist; rptr!=NULL; rptr=rptr->next) {
	    if (++rptr->count >= mincount && rptr->strength > 0)
		sum += (rptr->specificity + 1)*rptr->strength;
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

    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
/*
 * Returns the agent's requested bid (if >0) or offer (if <0).
 * Uses the rule chosen by -prepareForTrading.
 * The desired
 * position is then given by that rule's "action", and the bid or offer is
 * the diference between this desired position and the current position.
 */
{
    if (chosenrule)
    	demand = (chosenrule->action? p->bidsize: -p->bidsize);
    else
	demand = 0.0;
    *slope = 0.0;
    return [super constrainDemand:slope:trialprice];
}


- updatePerformance
/*
 * Updates all the active rules (those that matched the market conditions,
 * and were saved on the linked list) according to the profit or loss this
 * period.
 * The timing is awkward beause the buy/sell and update stages for each
 * period overlap in time:
 *  t-1                t                   t+1
 * |------------------|-------------------|-------------------|
 *       d      p            d      p           d      p
 *          b1------------------------>u1          b3----------
 * --------------->u0           b2-----------------------> u2
 * This shows a time line, the relative places that price (p) and dividend
 * (d) are set in each period, where the buy/sell decisions are made (b0-b3),
 * and where the rules are updated (u0-u3).
 */
{
    Rule rptr;
    double temp, incr, tausdecay, maxs, mins;

// The first buy/sell choices are at t=1, updated here at t=2.
    if (t <= 1)
	return self;

// Precompute things for speed
    tausdecay = p->tausdecay;
    maxs = p->maxrstrength;
    mins = p->minrstrength;
    incr = p->tausnew*(profitperunit - oldprice*intrate);

// Update strengths of all the rules that were activated
    for (rptr = oldactivelist; rptr != NULL; rptr = rptr->oldnext) {
	temp = tausdecay*rptr->strength + (rptr->action? incr: -incr);
	rptr->strength = (temp>maxs? maxs: (temp<mins? mins: temp));
    }

    return self;
}


- setEnabled:(BOOL)flag
{
    [super setEnabled:flag];

    if (!enabled) {	// cleanup for display when disabled
	chosenrule = NULL;
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
//  4. reversal() looks through all the rules and switches the Buy/Sell
//     action with probability preverse for any that are close to minimum
//     strength.  If they did that badly, maybe the opposite will do well!
//
//  5. generalize() looks for rules that haven't been triggered for
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
//   preverse	-- prob of reversing action on weak rule


/*------------------------------------------------------*/
/*	GA						*/
/*------------------------------------------------------*/
- performGA
{
    Rule rptr, nr;
    int r, specificity, new, parent1, parent2;
    BOOL changed;

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

// Make instance variables visible to GA routines
    pp = p;
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;

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
		nr->birth = nr->lastused = nr->lastactive = t;
		nr->next = nr->oldnext = NULL;
	    }

	} while (!changed);
    }

// Replace the nnew weakest old rules by the new ones
    transferRules(rule);

// Reverse the buy/sell action of weak rules with probability preverse 
    reversal(rule);

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
 * The action bit is similarly chosen randomly from one parent or the other.
 */
{
    int bit, word, specificity;
    unsigned int *cond1, *cond2, *newcond;
    Rule nr = newrule + new;

// Uniform crossover of condition bits
    newcond = nr->conditions;
    cond1 = rule[parent1].conditions;
    cond2 = rule[parent2].conditions;
    for (word = 0; word <condwords; word++)
	newcond[word] = 0;
    for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (irand(rng,2)?cond1:cond2)[WORD(bit)]&MASK[bit];

// Choose action randomly from the parents
    nr->action = (irand(rng,2)? rule[parent1].action:rule[parent2].action);

// Set rest of variables (besides lastactive -- see TransferRules)
    nr->strength = pp->initrstrength;
    nr->count = 0;	// call it new in any case

//  Find specificity
    specificity = - pp->nnulls;
    for (bit = 0; bit < condbits; bit++)
	if ((nr->conditions[WORD(bit)]&MASK[bit]) != 0)
	    specificity++;
    nr->specificity = specificity;

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
 * The action bit is flipped with probability pmutation.
 *
 * Returns YES if it actually changed anything, otherwise NO.
 */
{
    int bit;
    Rule nr = newrule + new;
    unsigned int *cond, *cond0;
    BOOL changed = NO;

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
	if (drand(rng) < pp->pmutation) {
	    nr->action = 1 - nr->action;
	    changed = YES;
	}
    }

    if (changed) {
	nr->strength = pp->initrstrength;
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
/*	reversal					*/
/*------------------------------------------------------*/
static void reversal(Rule rule)
{
    Rule rptr, topptr;
    double prev;

    prev = pp->preverse;
    topptr = rule + pp->numrules;
    for (rptr = rule+NFIXED; rptr < topptr; rptr++)	// Skip 1st NFIXED
	if (rptr->strength < pp->minrstrength + 0.5 && drand(rng) < prev) {
	    rptr->action = 1 - rptr->action;
	    rptr->strength = pp->initrstrength;
	    rptr->count = 0;
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
		rptr->strength = pp->initrstrength;
		rptr->birth = rptr->lastused = rptr->lastactive = t;
	    }
	}
    }
}

@end
