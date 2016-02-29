// Code for a "bitstring" (BS) agent

#import "global.h"
#import "BSagent.h"
#import <stdlib.h>
#import <math.h>
#import <string.h>
#import "World.h"
#import "random.h"
#import "error.h"
#import "util.h"

// Values in table of special bit names (negative, avoiding NULLBIT)
#define ENDLIST		-2
#define ALL		-3
#define SETPROB		-4
#define BADINPUT	-5
#define NOTFOUND	-6

static struct keytable specialbits[] = {
{"null", NULLBIT},
{"end", ENDLIST},
{".", ENDLIST},
{"all", ALL},
{"allbits", ALL},
{"p", SETPROB},
{"P", SETPROB},
{"???", BADINPUT},
{NULL,  NOTFOUND}
};

/* Local function prototypes */
static void CopyRule(struct rules *, struct rules *);
static void MakePool(struct rules *);
static int Tournament(struct rules *);
static void Crossover(struct rules *, int, int, int);
static void Mutate(int);
static void TransferRules(void);
static void Reversal(struct rules *);
static void Generalize(struct rules *);
static struct rules *GetMort(struct rules *);

// Local variables
static int class;
static int condbits;		/* Often copied from p->condbits */
static int condwords;		/* Often copied from p->condwords */
static int *bitlist;		/* Often copied from p->bitlist */
static unsigned int *myworld;	/* Often copied from p->myworld */
static struct BSparams *params;
static struct BSparams *pp;

// Working space, dynamically allocated
static struct rules	**reject;	/* GA temporary storage */
static struct rules	*newrule;	/* GA temporary storage */
static unsigned int *newconds;		/* GA temporary storage */
static int npoolmax = -1;		/* size of reject array */
static int nnewmax = -1;		/* size of newrule array */
static int ncondmax = -1;		/* size of newconds array */
static int *bits;			/* work array during startup */
static double *probs;			/* work array during startup */

// PRIVATE METHODS
@interface BSagent(Private)
- performGA;
@end


@implementation BSagent
+ initClass:(int)myclass
{
    class = myclass;	// save our class

// Make workspace for the bitlists
    bits = (int *)getmem(sizeof(int)*MAXCONDBITS);
    probs = (double *)getmem(sizeof(double)*MAXCONDBITS);

    return self;
}


+ (void *)createType:(int)mytype :(const char *)filename
{
    int i, bit, nnulls;
    double currentprob;
    BOOL done;

// Allocate space for our parameters
    params = (struct BSparams *)getmem(sizeof(struct BSparams));
    params->class = class;	// not used, but useful in debugger
    params->type = mytype;	// not used, but useful in debugger

// Open parameter file for BSagents
    (void) OpenInputFile(filename, "BS agent parameters");

// Read in general parameters
    params->numrules = ReadInt("numrules",4,1000);
    params->bidsize = ReadDouble("bidsize",0.0,1000.0);
    params->taus = ReadDouble("taus",1.0,100000.0);
    params->maxrstrength = ReadDouble("maxrstrength",1.0,100000.0);
    params->minrstrength = ReadDouble("minrstrength",-100.0,1000.0);
    params->initrstrength = ReadDouble("initrstrength",params->minrstrength,
							params->maxrstrength);
    params->bitprob = ReadDouble("bitprob",0.0,1.0);

// Read in the list of bits, storing it in workspace for now
    nnulls = 0;
    currentprob = params->bitprob;
    for (i=0, done=NO; done==NO;) {
	bit = ReadBitname("bitnames",specialbits);
	switch (bit) {
	case ENDLIST:
	case ALL:
	    done = YES;
	    break;
	case NOTFOUND:
	    break;	// error recorded by ReadBitname()
	case BADINPUT:
	    abandonIfError("[BSagent +createType::]");
	    /*NOTREACHED*/
	case SETPROB:
	    currentprob = ReadDouble("p = prob", 0.0, 1.0);
	    break;
	default:	// NULLBIT too
	    if (i >= MAXCONDBITS) {
		saveError("bitnames: two many bits specified");
		abandonIfError("[BSagent +createType::]");
		/*NOTREACHED*/
	    }
	    bits[i] = bit;	// >= 0 (ordinary bit), or NULLBIT
	    probs[i++] = currentprob;
	    if (bit == NULLBIT) ++ nnulls;
	}
    }
    if (bit == ALL) {
	if (i != 0) {
	    saveError("bitnames: 'all' is only valid initially");
	    abandonIfError("[BSagent +createType::]");
	    /*NOTREACHED*/
	}
	params->condbits = nworldbits;
	if (params->condbits > MAXCONDBITS) {
	    saveError("bitnames: insufficient MAXCONDBITS for 'all'");
	    abandonIfError("[BSagent +createType::]");
	    /*NOTREACHED*/
	}
	for (i=0; i < params->condbits; i++) {
	    bits[i] = i;
	    probs[i] = currentprob;
	}
    }
    else if (i - nnulls < 1) {
	saveError("bitnames: no valid bits");
	abandonIfError("[BSagent +createType::]");
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

// Allocate space for our world bits, clear initially
    params->condwords = (params->condbits+15)/16;
    params->myworld = (unsigned int *)getmem(
				sizeof(unsigned int)*params->condwords);
    for (i=0; i<params->condwords; i++)
	params->myworld[i] = 0;

// Read in GA parameters
    params->gafrequency = ReadInt("gafrequency",1,MAXINT);
    params->firstgatime = ReadInt("firstgatime",0,MAXINT);
    params->poolfrac = ReadDouble("poolfrac",0.0,1.0);
    params->newfrac = ReadDouble("newfrac",1.0/params->numrules,
							params->poolfrac);
    params->pcrossover = ReadDouble("pcrossover",0.0,1.0);
    params->pmutation = ReadDouble("pmutation",0.0,1.0);
    params->preverse = ReadDouble("preverse",0.0,1.0);
    params->longtime = ReadInt("longtime",1,MAXINT);
    params->genfrac = ReadDouble("genfrac",0.0,1.0);
    abandonIfError("[BSagent +createType::]");

// Compute derived parameters
    params->tausnew = -expm1(-1.0/params->taus);
    params->tausdecay = 1.0 - params->tausnew;
    params->gaprob = 1.0/params->gafrequency;
    params->npool = (int)(params->numrules*params->poolfrac + 0.5);
    params->nnew = (int)(params->numrules*params->newfrac + 0.5);

// Record maxima needed for GA working space
    if (params->npool > npoolmax) npoolmax = params->npool;
    if (params->nnew > nnewmax) nnewmax = params->nnew;
    if (params->condwords > ncondmax) ncondmax = params->condwords;

// Miscellaneous initialization
    params->lastgatime = 1;

/* Note that, as well as returning it, the current value of "params" is
 * available as a static variable in this file.  initAgent: uses that. */
    return (void *)params;
}


+ writeParams:(void *)theParams ToFile:(FILE *)fp
{
    int i;
    char buf[32];
    double currentprob, *problist;
    struct BSparams *parm = (struct BSparams *)theParams;

    showint(fp, "numrules", parm->numrules);
    showdble(fp, "bidsize", parm->bidsize);
    showdble(fp, "taus", parm->taus);
    showdble(fp, "maxrstrength", parm->maxrstrength);
    showdble(fp, "minrstrength", parm->minrstrength);
    showdble(fp, "initrstrength", parm->initrstrength);
    showdble(fp, "bitprob", parm->bitprob);

    condbits = parm->condbits;
    bitlist = parm->bitlist;
    problist = parm->problist;
    currentprob = parm->bitprob;
    sprintf(buf, "-- %d condition bits --", condbits - parm->nnulls);
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

    showint(fp, "gafrequency", parm->gafrequency);
    showint(fp, "firstgatime", parm->firstgatime);
    sprintf(buf,"poolfrac (npool = %d)", parm->npool);
    showdble(fp, buf, parm->poolfrac);
    sprintf(buf,"newfrac (nnew = %d)", parm->nnew);
    showdble(fp, buf, parm->newfrac);
    showdble(fp, "pcrossover", parm->pcrossover);
    showdble(fp, "pmutation", parm->pmutation);
    showdble(fp, "preverse", parm->preverse);
    showint(fp, "longtime", parm->longtime);
    showdble(fp, "genfrac", parm->genfrac);

    return self;
}


+ didInitialize
{
    struct rules *rlptr, *toprlptr;
    unsigned int *conditions;

// Free working space we're done with
    free(probs);
    free(bits);

// Allocate working space for GA
    reject = (struct rules **)getmem(sizeof(struct rules *)*npoolmax);
    newrule = (struct rules *)getmem(sizeof(struct rules)*nnewmax);
    newconds = (unsigned int *)getmem(sizeof(unsigned int)*ncondmax*nnewmax);

// Tie up pointers for conditions
    toprlptr = newrule + nnewmax;
    conditions = newconds;
    for (rlptr = newrule; rlptr < toprlptr; rlptr++) {
	rlptr->conditions = conditions;
	conditions += ncondmax;
    }

    return self;
}


+ prepareForTrading:(void *)theParams
{
    int i, n;

    pp = (struct BSparams *)theParams;
    condwords = pp->condwords;
    condbits = pp->condbits;
    bitlist = pp->bitlist;
    myworld = pp->myworld;
    for (i = 0; i < condwords; i++)
	myworld[i] = 0;
    for (i=0; i < condbits; i++) {
	if ((n = bitlist[i]) >= 0)
	    myworld[WORD(i)] |= realworld[n] << SHIFT[i];
    }

    return self;
}


+ (int)lastgatime:(void *)theParams
{
    pp = (struct BSparams *)theParams;
    return pp->lastgatime;
}


- initAgent:(int)mytag
{
    struct rules *rlptr, *toprlptr;
    unsigned int *conditions, *cond;
    int	word, bit, specificity;
    double *problist;

// Initialize generic variables common to all agents, link into list
    [super initAgent:mytag];

// Initialize our instance variables
    p = params;		/* last parameter values set by +createAgent:: */
    avspecificity = 0.0;
    avstrength = p->initrstrength;
    chosenrule = NULL;
    activelist = NULL;
    gacount = 0;

// Extract some things for rapid use
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;
    problist = p->problist;

// Allocate memory for rules and their conditions
    rule = (struct rules *) getmem(sizeof(struct rules)*p->numrules);
    conditions = (unsigned int *) getmem(
				sizeof(unsigned int)*p->numrules*condwords);

// Iniitialize the rules
    toprlptr = rule + p->numrules;
    for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	rlptr->strength = p->initrstrength;
	rlptr->count = 0;
	rlptr->lastactive = 1;
	rlptr->specificity = 1;
	rlptr->next = NULL;
	rlptr->action = irand(2);	// Start with random actions

    /* Allocate space for this forecast' conditions out of total allocation */
	rlptr->conditions = conditions;
	conditions += condwords;

    /* Initialise all conditions to don't care */
	cond = rlptr->conditions;
	for (word = 0; word < condwords; word++)
	    cond[word] = 0;

    /* Add non-zero bits as specified by probabilities */
	for (bit = 0; bit < condbits; bit++) {
	    if (bitlist[bit] < 0)
		cond[WORD(bit)] |= MASK[bit];	/* Set spacing bits to 3 */
	    else if (drand() < problist[bit]){
		cond[WORD(bit)] |= (irand(2)+1) << SHIFT[bit];
		++rlptr->specificity;
	    }
	}
    }

/* Compute average specificity */
    specificity = 0;
    for (rlptr = rule; rlptr < toprlptr; rlptr++)
	specificity += rlptr->specificity;
    avspecificity = ((double) specificity)/p->numrules;

    return self;
}


- free
{
    free(rule->conditions);
    free(rule);
    return [super free];
}


#ifdef NEXTSTEP
- copyFromZone:(NXZone *)zone
#else
- copy
#endif
{
    struct rules *rlptr, *toprlptr;
    unsigned int *conditions;
    BSagent *new;

// Allocate and copy instance variables
#ifdef NEXTSTEP
    new = (BSagent *)[super copyFromZone: zone];
#else
    new = (BSagent *)[super copy];
#endif
    new->activelist = NULL;	// invalid now

// Allocate and copy rules
    new->rule = (struct rules *) GETMEM(sizeof(struct rules)*p->numrules);
    (void) memcpy(new->rule, rule, sizeof(struct rules)*p->numrules);

// Allocate and copy condition bits for rules
    condwords = p->condwords;
    conditions = (unsigned int *)
			GETMEM(sizeof(unsigned int)*p->numrules*condwords);
    (void) memcpy(conditions, rule->conditions,
		sizeof(unsigned int)*p->numrules*condwords);

// Give rules pointers to their condition bits
    toprlptr = new->rule + p->numrules;
    for (rlptr = new->rule; rlptr < toprlptr; rlptr++) {
	rlptr->next = NULL;	// invalid now
	rlptr->conditions = conditions;
	conditions += condwords;
    }

    return new;
}


- check
{
    register int bit, specificity;
    register unsigned int *cond;
    struct rules *rlptr;
    int rl;

/* Note that specificity is 1 more than the number of non-# bits */

    condbits = p->condbits;
    for (rl = 0; rl < p->numrules; rl++) {
	rlptr = rule + rl;
	cond = rlptr->conditions;
	specificity = 1 - p->nnulls;
	for (bit = 0; bit < condbits; bit++)
	    if ((cond[WORD(bit)]&MASK[bit]) != 0)
		specificity++;

	if (rlptr->specificity != specificity)
	    Message("*a: agent %2d %s specificity error: rule %2d,"
		    " actual %2d, stored %2d",
		    tag, [self shortname],rl,specificity,rlptr->specificity);
    }
    [super check];
    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
/*
 * Returns the agent's requested bid (if >0) or offer (if <0).
 * Sees which rules match the present conditions and selects one of them
 * with probability proportional to strength*selectivity.  The desired
 * position is then given by that rule's "action", and the bid or offer is
 * the diference between this desired position and the current position.
 * A linked list of all the rules matching the present conditions is saved
 * for later updates.
 */
{
    register struct rules	*rlptr, *toprlptr;
    register struct rules	**nextptr;
    unsigned int		real0, real1, real2, real3, real4;
    double			dummyslope, sum, x;

// First the genetic algorithm is run if due
    if (t >= p->firstgatime)
	if (drand() < p->gaprob)
	    [self performGA];

// Main inner loop over rules.  We set this up separately for each
// value of condwords, for speed.  It's ugly, but fast.  Don't mess with
// it!  Taking out rlptr->conditions will NOT make it faster!  The highest
// condwords allowed for here sets the maximum number of condition bits
// permitted (no matter how large MAXCONDBITS).
    nextptr = &activelist;	/* start of linked list */
    toprlptr = rule + p->numrules;
    sum = 0.0;
    nactive = 0;
    myworld = p->myworld;
    real0 = myworld[0];
    switch (p->condwords) {
    case 1:
	for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	    if (rlptr->conditions[0] & real0) continue;
	    if (rlptr->strength > 0) {
		++nactive;
		sum += rlptr->strength*rlptr->specificity;
	    }
	    rlptr->cumulative = sum;
	    *nextptr = rlptr;
	    nextptr = &rlptr->next;
	}
	break;
    case 2:
	real1 = myworld[1];
	for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	    if (rlptr->conditions[0] & real0) continue;
	    if (rlptr->conditions[1] & real1) continue;
	    if (rlptr->strength > 0) {
		++nactive;
		sum += rlptr->strength*rlptr->specificity;
	    }
	    rlptr->cumulative = sum;
	    *nextptr = rlptr;
	    nextptr = &rlptr->next;
	}
	break;
    case 3:
	real1 = myworld[1];
	real2 = myworld[2];
	for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	    if (rlptr->conditions[0] & real0) continue;
	    if (rlptr->conditions[1] & real1) continue;
	    if (rlptr->conditions[2] & real2) continue;
	    if (rlptr->strength > 0) {
		++nactive;
		sum += rlptr->strength*rlptr->specificity;
	    }
	    rlptr->cumulative = sum;
	    *nextptr = rlptr;
	    nextptr = &rlptr->next;
	}
	break;
    case 4:
	real1 = myworld[1];
	real2 = myworld[2];
	real3 = myworld[3];
	for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	    if (rlptr->conditions[0] & real0) continue;
	    if (rlptr->conditions[1] & real1) continue;
	    if (rlptr->conditions[2] & real2) continue;
	    if (rlptr->conditions[3] & real3) continue;
	    if (rlptr->strength > 0) {
		++nactive;
		sum += rlptr->strength*rlptr->specificity;
	    }
	    rlptr->cumulative = sum;
	    *nextptr = rlptr;
	    nextptr = &rlptr->next;
	}
	break;
    case 5:
	real1 = myworld[1];
	real2 = myworld[2];
	real3 = myworld[3];
	real4 = myworld[4];
	for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	    if (rlptr->conditions[0] & real0) continue;
	    if (rlptr->conditions[1] & real1) continue;
	    if (rlptr->conditions[2] & real2) continue;
	    if (rlptr->conditions[3] & real3) continue;
	    if (rlptr->conditions[4] & real4) continue;
	    if (rlptr->strength > 0) {
		++nactive;
		sum += rlptr->strength*rlptr->specificity;
	    }
	    rlptr->cumulative = sum;
	    *nextptr = rlptr;
	    nextptr = &rlptr->next;
	}
	break;
#if MAXCONDBITS > 5*16
#error Too many condition bits (MAXCONDBITS)
#endif
    }
    *nextptr = NULL;	/* end of linked list */

    if (nactive == 0) {	/* no rules with strength>0 match */
	chosenrule = NULL;
	demand = 0.0;
	return demand;
    }

// roulette wheel selection
    else {
	x = drand() * sum;
	for (rlptr=activelist; rlptr!=NULL; rlptr=rlptr->next)
	    if (rlptr->cumulative > x) break;
	if (!rlptr) {
	    Message("*** ball jumped out of roulette wheel");
	    rlptr = activelist;
	}
	chosenrule = rlptr;
	demand = (rlptr->action? p->bidsize: -p->bidsize);
	return [super constrainDemand:&dummyslope:trialprice];
    }
}


- updatePerformance
/*
 * Updates all the active rules (those that matched the market conditions,
 * and were saved on the linked list) according to the profit or loss this
 * period.
 */
{
    register struct rules *rlptr;
    double temp, incr, tausdecay, maxs, mins;

// Precompute things for speed
    tausdecay = p->tausdecay;
    maxs = p->maxrstrength;
    mins = p->minrstrength;
    incr = p->tausnew*(profitperunit - oldprice*intrate);

// Update strengths of all the rules that were activated
    for (rlptr = activelist; rlptr != NULL; rlptr = rlptr->next) {
	temp = tausdecay*rlptr->strength + (rlptr->action? incr: -incr);
	rlptr->strength = (temp>maxs? maxs: (temp<mins? mins: temp));
	++rlptr->count;
	rlptr->lastactive = t;
    }

    return self;
}


- enabledStatus:(BOOL)flag
{
    if (!flag) {	/* cleanup for display when disabled */
	nactive = 0;
	activelist = NULL;
	chosenrule = NULL;
    }
    return self;
}


- (int)nbits
{
    return p->condbits;
}


- (int)nrules
{
    return p->numrules;
}


- (int)lastgatime
{
    return lastgatime;
}


- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
{
    struct rules *rlptr, *toprlptr;
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

    toprlptr = rule + p->numrules;
    for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	agntcond = rlptr->conditions;
	for (i = 0; i < condbits; i++)
	    count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
    }
    return condbits;
}


- (const char *)descriptionOfBit:(int)bit
{
    if (bit < 0 || bit > p->condbits)
	return "(Invalid condition bit)";
    else
	return [World descriptionOfBit:p->bitlist[bit]];
}


// Genetic algorithm
//  1. MakePool() makes a list in reject[] of the "npool" weakest rules.
//
//  2. "nnew" new rules are created in newrules[], using tournament
//     selection, crossover, and mutation.  "Tournament selection"
//     means picking two candidates purely at random and then choosing
//     the one with the higher strength.  See the Crossover() and
//     Mutate() routines for more details about how they work.
//
//  3. The nnew new rules replace nnew of the npool weakest old ones found in
//     step 1.  GetMort() is called for each of the nnew new rules and
//     selects one to replace out of the remainder of the original npool weak
//     ones.  It pays no attention to strength, but looks at similarity of
//     the bitstrings -- rather like tournament selection, we pick two
//     candidates at random and choose the one with the MORE similar
//     bitstring to be replaced.  This maintains more diversity.
//
//  4. Reversal() looks through all the rules and switches the Buy/Sell
//     action with probability preverse for any that are close to minimum
//     strength.  If they did that badly, maybe the opposite will do well!
//
//  5. Generalize() looks for rules that haven't been triggered for
//     "longtime" and generalizes them by changing a randomly chosen
//     fraction "genfrac" of 0/1 bits to "don't care".  It does this
//     independently of strength to all rules in the population.
//
// Parameter list:
//
//   npool	-- size of pool of weakest rules for possible relacement;
//		   specified as a fraction of numrules by "poolfrac"
//   nnew	-- number of new rules produced
//		   specified as a fraction of numrules by "newfrac"
//   pcrossover -- probability of running Crossover() at all.
//   pmutation  -- per bit mutation prob.
//   preverse   -- prob of reversing action on weak rule
//   longtime	-- generalize if rule unused for this length of time
//   genfrac	-- fraction of 0/1 bits to make don't-care when generalising

/*------------------------------------------------------*/
/*	GA						*/
/*------------------------------------------------------*/
- performGA
{
    register struct rules *rlptr;
    register int rl;
    int specificity, new, parent1, parent2;

    ++gacount;
    p->lastgatime = lastgatime = t;

/* Make instance variable visible to GA routines */
    pp = p;
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;

    MakePool(rule);

    avstrength = 0;
    for (rl=0; rl < p->numrules; rl++)
    	avstrength += rule[rl].strength;
    avstrength /= ((double)p->numrules);

    for (new = 0; new < p->nnew; new++) {
	parent1 = Tournament(rule);
	if (drand() < p->pcrossover) {
	    do
		parent2 = Tournament(rule);
	    while (parent2 == parent1) ;
	    Crossover(rule, new, parent1, parent2);
	}
	else
	    CopyRule(&newrule[new],&rule[parent1]);

	Mutate(new);
    }
    TransferRules();
    Reversal(rule);
    Generalize(rule);

/* Compute average specificity */
    specificity = 0;
    for (rl = 0; rl < p->numrules; rl++) {
	rlptr = rule + rl;
	specificity += rlptr->specificity;
    }
    avspecificity = ((double) specificity)/p->numrules;
    return self;
}


/*------------------------------------------------------*/
/*	CopyRule					*/
/*------------------------------------------------------*/
static void CopyRule(struct rules *to, struct rules *from)
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
/*	MakePool					*/
/*------------------------------------------------------*/
static void MakePool(struct rules *rule)
{
    register int	j;
    register int	top;
    register struct rules *rlptr, *toprlptr;

// Dumb bubble sort
    toprlptr = rule + pp->npool;
    top = -1;
    for (rlptr = rule; rlptr < toprlptr; rlptr++) {
	for (j = top; j >= 0 && rlptr->strength < reject[j]->strength; j--)
	    reject[j+1] = reject[j];
	reject[j+1] = rlptr;
	top++;
    }
    toprlptr = rule + pp->numrules;
    for (; rlptr < toprlptr; rlptr++) {
	if (rlptr->strength < reject[top]->strength) {
	    for (j = top-1; j>=0 && rlptr->strength < reject[j]->strength; j--)
		reject[j+1] = reject[j];
	    reject[j+1] = rlptr;
	}
    }

/* Note that reject[npool-1]->strength gives the "dud threshold" */

}


/*------------------------------------------------------*/
/*	Tournament					*/
/*------------------------------------------------------*/
static int Tournament(struct rules *rule)
{
    int	candidate1 = irand(pp->numrules);
    int	candidate2;

    do
	candidate2 = irand(pp->numrules);
    while (candidate2 == candidate1);

    if (rule[candidate1].strength > rule[candidate2].strength)
	return candidate1;
    else
	return candidate2;
}


/*------------------------------------------------------*/
/*	Crossover					*/
/*------------------------------------------------------*/
static void Crossover(struct rules *rule, int new, int parent1, int parent2)
/*
 * On the condition bits, Crossover() uses uniform crossover -- each
 * bit is chosen randomly from one parent or the other.
 * The action bit is similarly chosen randomly from one parent or the other.
 */
{
    register int bit;
    unsigned int *cond1, *cond2, *newcond;
    struct rules *nr = newrule + new;
    int	word, specificity;

/* Uniform crossover of condition bits */
    newcond = nr->conditions;
    cond1 = rule[parent1].conditions;
    cond2 = rule[parent2].conditions;
    for (word = 0; word <condwords; word++)
	newcond[word] = 0;
    for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (irand(2)?cond1:cond2)[WORD(bit)]&MASK[bit];

/* Choose action randomly from the parents */
    nr->action = (irand(2)? rule[parent1].action:rule[parent2].action);

/* Set rest of variables (besides lastactive -- see TransferFcasts) */
    nr->strength = pp->initrstrength;
    nr->count = 0;	// call it new in any case
    specificity = 1 - pp->nnulls;
    for (bit = 0; bit < condbits; bit++)
	if ((nr->conditions[WORD(bit)]&MASK[bit]) != 0)
	    specificity++;

    nr->specificity = specificity;
}


/*------------------------------------------------------*/
/*	Mutate						*/
/*------------------------------------------------------*/
static void Mutate(int new)
/*
 * For the condition bits, Mutate() looks at each bit with
 * probability pmutation.  If chosen, a bit is changed as follows:
 *    0  ->  * with probability 2/3, 1 with probability 1/3
 *    1  ->  * with probability 2/3, 0 with probability 1/3
 *    *  ->  0 with probability 1/3, 1 with probability 1/3,
 *           unchanged with probability 1/3
 * This maintains specificity on average.
 *
 * The action bit is flipped with probability pmutation.
 */
{
    register int bit;
    register struct rules *nr = newrule + new;
    unsigned int *cond, *cond0;
    BOOL changed = NO;

    if (pp->pmutation > 0) {
	cond0 = nr->conditions;
	for (bit = 0; bit < condbits; bit++) {
	    if (bitlist[bit] < 0) continue;
	    if (drand() < pp->pmutation) {
		cond = cond0 + WORD(bit);
		if (*cond & MASK[bit]) {
		    if (irand(3) > 0) {
			*cond &= NMASK[bit];
			nr->specificity--;
		    }
		    else
			*cond ^= MASK[bit];
		    changed = YES;
		}
		else if (irand(3) > 0) {
		    *cond |= (irand(2)+1) << SHIFT[bit];
		    nr->specificity++;
		    changed = YES;
		}
	    }
	}
	if (drand() < pp->pmutation) {
	    nr->action = 1 - nr->action;
	    changed = YES;
	}
    }
    if (changed) {
	nr->strength = pp->initrstrength;
	nr->count = 0;
    }
}


/*------------------------------------------------------*/
/*	TransferRules					*/
/*------------------------------------------------------*/
static void TransferRules()
{
    register struct rules *rlptr, *nr;
    register int new;
    int nnew;

    nnew = pp->nnew;
    for (new = 0; new < nnew; new++) {
	nr = newrule + new;
	rlptr = GetMort(nr);

    // Copy the whole structure and conditions, and reset lastactive
	CopyRule(rlptr, nr);
	rlptr->lastactive = t;
    }
}

/*------------------------------------------------------*/
/*	GetMort						*/
/*------------------------------------------------------*/
static struct rules *GetMort(struct rules *nr)
/* GetMort() selects one of the npool weak old rules to replace
 * with a newly generated rule.  It pays no attention to strength,
 * but looks at similarity of the condition bits -- like tournament
 * selection, we pick two candidates at random and choose the one
 * with the MORE similar bitstring to be replaced.  This maintains
 * more diversity.
 */
{
    register int bit, temp1, temp2, different1, different2;
    struct rules *rlptr;
    unsigned int *cond1, *cond2, *newcond;
    int npool, r1, r2, word, bitmax;

    npool = pp->npool;

    r1 = irand(npool);
    while (reject[r1] == NULL)
	r1 = irand(npool);
    r2 = irand(npool);
    while (r1 == r2 || reject[r2] == NULL)
	r2 = irand(npool);

    cond1 = reject[r1]->conditions;
    cond2 = reject[r2]->conditions;
    newcond = nr->conditions;
    different1 = 0;
    different2 = 0;
    bitmax = 16;
    for (word = 0; word < condwords; word++) {
	temp1 = cond1[word] ^ newcond[word];
	temp2 = cond2[word] ^ newcond[word];
	if (word == condwords-1)
	    bitmax = ((condbits-1)&15) + 1;
	for (bit = 0; bit < bitmax; temp1 >>= 2, temp2 >>= 2, bit++) {
	    if (temp1 & 3)
		different1++;
	    if (temp2 & 3)
		different2++;
	}
    }
    if (reject[r1]->action != nr->action)
	different1++;
    if (reject[r2]->action != nr->action)
	different2++;

    if (different1 < different2) {
	rlptr = reject[r1];
	reject[r1] = NULL;
    }
    else {
	rlptr = reject[r2];
	reject[r2] = NULL;
    }
    return rlptr;
}


/*------------------------------------------------------*/
/*	Reversal					*/
/*------------------------------------------------------*/
static void Reversal(struct rules *rule)
{
    register struct rules *rlptr, *toprlptr;
    double prev;

    prev = pp->preverse;
    toprlptr = rule + pp->numrules;
    for (rlptr = rule; rlptr < toprlptr; rlptr++)
	if (rlptr->strength < pp->minrstrength + 0.5 && drand() < prev) {
	    rlptr->action = 1 - rlptr->action;
	    rlptr->strength = pp->initrstrength;
	    rlptr->count = 0;
	}
}

/*------------------------------------------------------*/
/*	Generalize					*/
/*------------------------------------------------------*/
static void Generalize(struct rules *rule)
/*
 * Each forecast that hasn't be used for longtime is generalized by
 * turning a fraction genfrac of the 0/1 bits to don't-cares.
 */
{
    register struct rules *rlptr;
    register int rl;
    int	bit, j;

    for (rl = 0; rl < pp->numrules; rl++) {
	rlptr = rule + rl;
	if (t - rlptr->lastactive > pp->longtime) {
	    j = (int)ceil((rlptr->specificity-1)*pp->genfrac);
	    for (;j>0;) {
		bit = irand(condbits);
		if (bitlist[bit] < 0) continue;
		if ((rlptr->conditions[WORD(bit)]&MASK[bit])) {
		    rlptr->conditions[WORD(bit)] &= NMASK[bit];
		    --rlptr->specificity;
		    rlptr->strength = pp->initrstrength;
		    rlptr->count = 0;
		    rlptr->lastactive = t;
		    j--;
		}
	    }
	}
    }
}

@end
