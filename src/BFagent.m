// Code for a "bitstring forecaster" (BF) agent


#include "global.h"
#include "BFagent.h"
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include "World.h"
#include "random.h"
#include "error.h"
#include "util.h"


// Type of forecasting.  WEIGHTED forecasting is untested in its present form.
#define WEIGHTED 0

#define MAXRULE 500  // Max rules for temp in GA runs and median calc

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
static void CopyRule(struct BF_fcast *, struct BF_fcast *);
static void MakePool(struct BF_fcast *);
static int Tournament(struct BF_fcast *);
static void Crossover(struct BF_fcast *, int, int, int);
static BOOL Mutate(int, BOOL);
static void TransferFcasts(void);
static void Generalize(struct BF_fcast *);
static struct BF_fcast *GetMort(struct BF_fcast *);

// Local variables, shared by all instances
static int class;
static int condbits;		/* Often copied from p->condbits */
static int condwords;		/* Often copied from p->condwords */
static int *bitlist;		/* Often copied from p->bitlist */
static unsigned int *myworld;	/* Often copied from p->myworld */
static struct BFparams *params;
static struct BFparams *pp;
static double lmedstrength,lavstrength,lminstrength; /* working variable for GA */
static double lthreshstrength;
static double stda,stdb,stdc,meana,meanb,meanc,meane;


// Working space, dynamically allocated, shared by all instances
static struct BF_fcast	**reject;	/* GA temporary storage */
static struct BF_fcast	*newfcast;	/* GA temporary storage */
static unsigned int *newconds;		/* GA temporary storage */
static int npoolmax = -1;		/* size of reject array */
static int nnewmax = -1;		/* size of newfcast array */
static int ncondmax = -1;		/* size of newconds array */
static int *bits;			/* work array during startup */
static double *probs;			/* work array during startup */


// PRIVATE METHODS
@interface BFagent(Private)
- performGA;
@end


@implementation BFagent

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
    params = (struct BFparams *)getmem(sizeof(struct BFparams));
    params->class = class;	// not used, but useful in debugger
    params->type = mytype;	// not used, but useful in debugger

// Open parameter file for BFagents
    (void) OpenInputFile(filename, "BF agent parameters");

// Read in general parameters
    params->numfcasts = ReadInt("numfcasts",4,1000);
    params->tauv = ReadDouble("tauv",1.0,100000.0);
    params->lambda = ReadDouble("lambda",0.0,100000.0);
    params->maxbid = ReadDouble("maxbid",0.0,1000.0);
    params->mincount = ReadInt("mincount",0,MAXINT);
    params->subrange = ReadDouble("subrange",0.0,1.0);
    params->a_min = ReadDouble("a_min",-1000.0,1000.0);
    params->a_max = ReadDouble("a_max",-1000.0,1000.0);
    params->b_min = ReadDouble("b_min",-1000.0,1000.0);
    params->b_max = ReadDouble("b_max",-1000.0,1000.0);
    params->c_min = ReadDouble("c_min",-1000.0,1000.0);
    params->c_max = ReadDouble("c_max",-1000.0,1000.0);
    params->newfcastvar = ReadDouble("newfcastvar",0.001,1000.0);
    params->initvar = ReadDouble("initvar",0.001,1000.0);
    params->bitcost = ReadDouble("bitcost",-1.0,1.0);
    params->maxdev = ReadDouble("maxdev",0.001,1e6);
    params->individual = ReadKeyword("individual",individualkeys);
    params->bitprob = ReadDouble("bitprob",0.0,1.0);

// Read in the list of bits, storing it in a work array for now
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
	    abandonIfError("[BFagent +createType::]");
	    /*NOTREACHED*/
	case SETPROB:
	    currentprob = ReadDouble("p = prob", 0.0, 1.0);
	    break;
	default:	// NULLBIT too
	    if (i >= MAXCONDBITS) {
		saveError("bitnames: too many bits specified");
		abandonIfError("[BFagent +createType::]");
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
	    abandonIfError("[BFagent +createType::]");
	    /*NOTREACHED*/
	}
	params->condbits = nworldbits;
	if (params->condbits > MAXCONDBITS) {
	    saveError("bitnames: insufficient MAXCONDBITS for 'all'");
	    abandonIfError("[BFagent +createType::]");
	    /*NOTREACHED*/
	}
	for (i=0; i < params->condbits; i++) {
	    bits[i] = i;
	    probs[i] = currentprob;
	}
    }
    else if (i - nnulls < 1) {
	saveError("bitnames: no valid bits");
	abandonIfError("[BFagent +createType::]");
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

// Check bitcost isn't too negative
    if (1.0+params->bitcost*(params->condbits-params->nnulls) <= 0.0)
	saveError("bitcost*#bits <= -1.0");

// Read in GA parameters
    params->gafrequency = ReadInt("gafrequency",1,MAXINT);
    params->firstgatime = ReadInt("firstgatime",0,MAXINT);
    params->poolfrac = ReadDouble("poolfrac",0.0,1.0);
    params->newfrac = ReadDouble("newfrac",1.0/params->numfcasts,
							params->poolfrac);
    params->pcrossover = ReadDouble("pcrossover",0.0,1.0);
    params->plinear = ReadDouble("plinear",0.0,1.0);
    params->prandom = ReadDouble("prandom",0.0,1.0-params->plinear);
    params->pmutation = ReadDouble("pmutation",0.0,1.0);
    params->plong = ReadDouble("plong",0.0,1.0);
    params->pshort = ReadDouble("pshort",0.0,1.0-params->plong);
    params->nhood = ReadDouble("nhood",0.0,1.0);
    params->longtime = ReadInt("longtime",1,MAXINT);
    params->genfrac = ReadDouble("genfrac",0.0,1.0);

    abandonIfError("[BFagent +createType::]");

// Compute derived parameters
    params->gaprob = 1.0/params->gafrequency;

    params->a_range = params->a_max - params->a_min;
    params->b_range = params->b_max - params->b_min;
    params->c_range = params->c_max - params->c_min;

    params->npool = (int)(params->numfcasts*params->poolfrac + 0.5);
    params->nnew = (int)(params->numfcasts*params->newfrac + 0.5);

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
    struct BFparams *parm = (struct BFparams *)theParams;

    showint(fp, "numfcasts", parm->numfcasts);
    showdble(fp, "tauv", parm->tauv);
    showdble(fp, "lambda", parm->lambda);
    showdble(fp, "maxbid", parm->maxbid);
    showint(fp, "mincount", parm->mincount);
    showdble(fp, "subrange", parm->subrange);
    showdble(fp,"a_min",parm->a_min);
    showdble(fp,"a_max",parm->a_max);
    showdble(fp,"b_min",parm->b_min);
    showdble(fp,"b_max",parm->b_max);
    showdble(fp,"c_min",parm->c_min);
    showdble(fp,"c_max",parm->c_max);
    showdble(fp,"newfcastvar",parm->newfcastvar);
    showdble(fp,"initvar",parm->initvar);
    showdble(fp,"bitcost",parm->bitcost);
    showdble(fp,"maxdev",parm->maxdev);
    showstrng(fp, "individual", (parm->individual? "yes" : "no"));
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
    showdble(fp, "plinear", parm->plinear);
    showdble(fp, "prandom", parm->prandom);
    showdble(fp, "pmutation", parm->pmutation);
    showdble(fp, "plong", parm->plong);
    showdble(fp, "pshort", parm->pshort);
    showdble(fp, "nhood", parm->nhood);
    showint(fp, "longtime", parm->longtime);
    showdble(fp, "genfrac", parm->genfrac);

    return self;
}


+ didInitialize
{
    struct BF_fcast *fptr, *topfptr;
    unsigned int *conditions;

// Free working space we're done with
    free(probs);
    free(bits);

// Allocate working space for GA
    reject = (struct BF_fcast **)getmem(sizeof(struct BF_fcast *)*npoolmax);
    newfcast = (struct BF_fcast *)getmem(sizeof(struct BF_fcast)*nnewmax);
    newconds = (unsigned int *)getmem(sizeof(unsigned int)*ncondmax*nnewmax);

// Tie up pointers for conditions
    topfptr = newfcast + nnewmax;
    conditions = newconds;
    for (fptr = newfcast; fptr < topfptr; fptr++) {
	fptr->conditions = conditions;
	conditions += ncondmax;
    }

    return self;
}


+ prepareForTrading:(void *)theParams
/*
 * Called at the start of each trading period for each agent type.
 * "theParams" defines the type within this class.
 */
{
    int i, n;

// Make a "myworld" string of bits extracted from the full "realworld"
// bitstring.
    pp = (struct BFparams *)theParams;
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
    pp = (struct BFparams *)theParams;
    return pp->lastgatime;
}


- initAgent:(int)mytag
{
    struct BF_fcast *fptr, *topfptr;
    unsigned int *conditions, *cond;
    int	word, bit, specificity;
    double *problist;
    double abase, bbase, cbase, asubrange, bsubrange, csubrange;
    double newfcastvar, bitcost;
    double dn;

// Initialize generic variables common to all agents, link into list
    [super initAgent:mytag];

// Initialize our instance variables
    p = params;		/* last parameter values set by +createAgent:: */
    avspecificity = 0.0;
    lactivelist = activelist = NULL;
    gacount = 0;

    variance = p->initvar;
    global_mean = price + dividend;
    forecast = lforecast = global_mean;

// Extract some things for rapid use (is this worth it?)
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;
    problist = p->problist;
    newfcastvar = p->newfcastvar;
    bitcost = p->bitcost;

// Allocate memory for forecasts and their conditions
    fcast = (struct BF_fcast *) getmem(sizeof(struct BF_fcast)*p->numfcasts);
    conditions = (unsigned int *) getmem(
				sizeof(unsigned int)*p->numfcasts*condwords);

// Iniitialize the forecasts
    dn = p->numfcasts;
    topfptr = fcast + p->numfcasts;
    for (fptr = fcast; fptr < topfptr; fptr++) {
	fptr->forecast = 0.0;
        fptr->lforecast = global_mean;
	fptr->errct = fptr->count = 0;
	fptr->birth = fptr->lastused = fptr->lastactive = 1;
	fptr->specificity = 0;
	fptr->next = fptr->lnext = NULL;

    /* Allocate space for this forecast's conditions out of total allocation */
	fptr->conditions = conditions;
	conditions += condwords;

    /* Initialise all conditions to don't care */
	cond = fptr->conditions;
	for (word = 0; word < condwords; word++)
	    cond[word] = 0;

    /* Add non-zero bits as specified by probabilities */
	if(fptr!=fcast) /* protect rule 0 */
	for (bit = 0; bit < condbits; bit++) {
	    if (bitlist[bit] < 0)
		cond[WORD(bit)] |= MASK[bit];	/* Set spacing bits to 3 */
	    else if (drand() < problist[bit]){
		cond[WORD(bit)] |= (irand(2)+1) << SHIFT[bit];
		++fptr->specificity;
	    }
	}
//	fptr->specfactor = 1.0/(1.0 + bitcost*fptr->specificity);
	fptr->specfactor = (condbits - fptr->specificity)*bitcost;
	fptr->actvar = fptr->variance = newfcastvar;
        fptr->error = 0;
        fptr->strength =  0;
        fptr->active = 0;
    }
    minstrength = avstrength = medstrength = 0;

/* Compute average specificity */
    specificity = 0;
    for (fptr = fcast; fptr < topfptr; fptr++)
	specificity += fptr->specificity;
    avspecificity = ((double) specificity)/p->numfcasts;

/* Set the forecasting parameters for each fcast to random values in a
 * fraction "subrange" of their range, centered at the midpoint.  For
 * subrange=1 this is the whole range (min to max).  For subrange=0.5,
 * values lie between 1/4 and 3/4 of this range.  subrange=0 gives
 * homogeneous agents, with values at the middle of their min-max range. 
 */
    abase = p->a_min + 0.5*(1.-p->subrange)*(p->a_range);
    bbase = p->b_min + 0.5*(1.-p->subrange)*p->b_range;
    cbase = p->c_min + 0.5*(1.-p->subrange)*(p->c_range);
    asubrange = p->subrange*p->a_range;
    bsubrange = p->subrange*p->b_range;
    csubrange = p->subrange*p->c_range;
    for (fptr = fcast; fptr < topfptr; fptr++) {
	fptr->a = abase + drand()*asubrange;
	fptr->b = bbase + drand()*bsubrange;
	fptr->c = cbase + drand()*csubrange;
    }

//  find summary stats on forecast params - used in mutations
    meana = meanb = meanc = stda = stdb = stdc = 0;
    for(fptr = fcast; fptr<topfptr; fptr++) {
        meana += fptr->a;
        meanb += fptr->b;
        meanc += fptr->c;
        stda  += fptr->a*fptr->a;
        stdb  += fptr->b*fptr->b;
        stdc  += fptr->c*fptr->c;
    }
    meana /= dn;
    meanb /= dn;
    meanc /= dn;
    meane = 0;
    if(stda>0)
    stda = sqrt(stda/dn - meana*meana);
    if(stdb>0)
    stdb = sqrt(stdb/dn - meanb*meanb);
    if(stdc>0)
    stdc = sqrt(stdc/dn - meanc*meanc);

    return self;
}


- free
{
    free(fcast->conditions);
    free(fcast);
    return [super free];
}


#ifdef NEXTSTEP
- copyFromZone:(NXZone *)zone
#else
- copy
#endif
{
    struct BF_fcast *fptr, *topfptr;
    unsigned int *conditions;
    BFagent *new;

// Allocate and copy instance variables
#ifdef NEXTSTEP
    new = (BFagent *)[super copyFromZone: zone];
#else
    new = (BFagent *)[super copy];
#endif
    new->activelist = NULL;	// invalid now

// Allocate and copy forecasters
    new->fcast = (struct BF_fcast *)
				GETMEM(sizeof(struct BF_fcast)*p->numfcasts);
    (void) memcpy(new->fcast, fcast, sizeof(struct BF_fcast)*p->numfcasts);

// Allocate and copy condition bits for forecasters
    condwords = p->condwords;
    conditions = (unsigned int *)
			GETMEM(sizeof(unsigned int)*p->numfcasts*condwords);
    (void) memcpy(conditions, fcast->conditions,
		sizeof(unsigned int)*p->numfcasts*condwords);

// Give forecasters pointers to their condition bits
    topfptr = new->fcast + p->numfcasts;
    for (fptr = new->fcast; fptr < topfptr; fptr++) {
	fptr->next = NULL;	// invalid now
	fptr->conditions = conditions;
	conditions += condwords;
    }

    return new;
}


- check
{
    register int bit, specificity;
    register unsigned int *cond;
    struct BF_fcast *fptr;
    int f;

/* Specificity should be equal to the number of non-# bits */

    condbits = p->condbits;
    for (f = 0; f < p->numfcasts; f++) {
	fptr = fcast + f;
	cond = fptr->conditions;
	specificity = -p->nnulls;
	for (bit = 0; bit < condbits; bit++)
	    if ((cond[WORD(bit)]&MASK[bit]) != 0)
		specificity++;

	if (fptr->specificity != specificity)
	    Message("*a: agent %2d %s specificity error: fcast %2d,"
		    " actual %2d, stored %2d",
		    tag, [self shortname],f,specificity,fptr->specificity);
    }
    [super check];
    return self;
}


- prepareForTrading
/*
 * Set up a new active list for this agent's forecasts, and compute the
 * coefficients pdcoeff and offset in the equation
 *	forecast = pdcoeff*(trialprice+dividend) + offset
 *
 * The active list of all the fcasts matching the present conditions is saved
 * for later updates.
 */
{
    register struct BF_fcast *fptr, *topfptr, **nextptr;
    unsigned int real0, real1, real2, real3, real4;
    double weight, countsum, forecastvar;
    int mincount;
    //    int jn;
#if  WEIGHTED == 1    
    static double a, b, c, sum, sumv;
#else
    struct BF_fcast *bestfptr;
    double maxstrength;
    double minvar;
#endif

    topfptr = fcast + p->numfcasts;
   
// First the genetic algorithm is run if due
    if (t >= p->firstgatime && drand() < p->gaprob && (t<25000000)) {
	[self performGA]; 
	// Clear linked list for active rules
	lactivelist = activelist = NULL;
    }	    

    lforecast = forecast;
// Preserve last active list
    lactivelist = activelist;
    for (fptr = activelist; fptr!=NULL; fptr = fptr->next) {
	    fptr->lnext = fptr->next;
	    fptr->lforecast = fptr->forecast;
    }

// Main inner loop over forecasters.  We set this up separately for each
// value of condwords, for speed.  It's ugly, but fast.  Don't mess with
// it!  Taking out fptr->conditions will NOT make it faster!  The highest
// condwords allowed for here sets the maximum number of condition bits
// permitted (no matter how large MAXCONDBITS).
    nextptr = &activelist;	/* start of linked list */
    myworld = p->myworld;

/*
    myworld[WORD(16)] |= irand(2) << SHIFT[16];
*/


    real0 = myworld[0];
    switch (p->condwords) {
    case 1:
	for (fptr = fcast; fptr < topfptr; fptr++) {
	    if (fptr->conditions[0] & real0) continue;
	    *nextptr = fptr;
	    nextptr = &fptr->next;
	}
	break;
    case 2:
	real1 = myworld[1];
	for (fptr = fcast; fptr < topfptr; fptr++) {
	    if (fptr->conditions[0] & real0) continue;
	    if (fptr->conditions[1] & real1) continue;
	    *nextptr = fptr;
	    nextptr = &fptr->next;
	}
	break;
    case 3:
	real1 = myworld[1];
	real2 = myworld[2];
	for (fptr = fcast; fptr < topfptr; fptr++) {
	    if (fptr->conditions[0] & real0) continue;
	    if (fptr->conditions[1] & real1) continue;
	    if (fptr->conditions[2] & real2) continue;
	    *nextptr = fptr;
	    nextptr = &fptr->next;
	}
	break;
    case 4:
	real1 = myworld[1];
	real2 = myworld[2];
	real3 = myworld[3];
	for (fptr = fcast; fptr < topfptr; fptr++) {
	    if (fptr->conditions[0] & real0) continue;
	    if (fptr->conditions[1] & real1) continue;
	    if (fptr->conditions[2] & real2) continue;
	    if (fptr->conditions[3] & real3) continue;
	    *nextptr = fptr;
	    nextptr = &fptr->next;
	}
	break;
    case 5:
	real1 = myworld[1];
	real2 = myworld[2];
	real3 = myworld[3];
	real4 = myworld[4];
	for (fptr = fcast; fptr < topfptr; fptr++) {
	    if (fptr->conditions[0] & real0) continue;
	    if (fptr->conditions[1] & real1) continue;
	    if (fptr->conditions[2] & real2) continue;
	    if (fptr->conditions[3] & real3) continue;
	    if (fptr->conditions[4] & real4) continue;
	    *nextptr = fptr;
	    nextptr = &fptr->next;
	}
	break;
#if MAXCONDBITS > 5*16
#error Too many condition bits (MAXCONDBITS)
#endif
    }
    *nextptr = NULL;	/* end of linked list */

#if WEIGHTED == 1
// Construct weighted-average forecast
// The individual forecasts are:  p + d = a(p+d) + b(d) + c
// We often lock b at 0 by setting b_min = b_max = 0.

    a = 0.0;
    b = 0.0;
    c = 0.0;
    sumv = 0.0;
    sum = 0.0;
    nactive = 0;
    mincount = p->mincount;
    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) {
	fptr->lastactive = t;
	if (++fptr->count >= mincount) {
	    ++nactive;
	    a += fptr->strength*fptr->a;
	    b += fptr->strength*fptr->b;
	    c += fptr->strength*fptr->c;
	    sum += fptr->strength;
	    sumv += fptr->variance;
	}
    }
    if (nactive) {
	pdcoeff = a/sum;
	offset = (b/sum)*dividend + (c/sum);
	forecastvar = (p->individual? sumv/((double)nactive) :variance);
    }
#else
// Now go through the list and find best forecast
/*
    maxstrength = -1e50;
    bestfptr = NULL;
    nactive = 0;
    mincount = p->mincount;
    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) {
	fptr->lastactive = t;
	if (++fptr->count >= mincount) {
	    ++nactive;
	    if (fptr->strength > maxstrength) {
		maxstrength = fptr->strength;
		bestfptr = fptr;
	    }
	}
    }
*/

/* test block */
    maxstrength = -1e50;
    minvar = 1e50;
    bestfptr = NULL;
    nactive = 0;
    mincount = p->mincount;
    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) {
	fptr->lastactive = t;
	if (++fptr->count >= mincount) {
	    ++nactive;
/*
            if(fptr->count == mincount)
                   fptr->variance = fptr->actvar;
*/
	    if (fptr->actvar < minvar) {
		minvar = fptr->actvar;
		bestfptr = fptr;
	    }
	}
    }

/*
    jn = irand(nactive+1);
    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) {
	jn--;
	if(jn==0)  {
		bestfptr = fptr;
		break;
	}
    }
		
*/
	
/* -- end test --- */

    if (nactive) {
	pdcoeff = bestfptr->a;
	offset = bestfptr->b*dividend + bestfptr->c;
	forecastvar = (p->individual? bestfptr->variance :variance);
        bestfptr->lastused = t;
    }
#endif
    else {
	// No forecast!!
	// Use weighted (by count) average of all rules
	countsum = 0.0;
	pdcoeff = 0.0;
	offset = 0.0;
	mincount = p->mincount;
	for (fptr = fcast; fptr < topfptr; fptr++)
	    if (fptr->count >= mincount) {
		countsum += weight = (double)fptr->strength;
		offset += (fptr->b*dividend + fptr->c)*weight;
		pdcoeff += fptr->a*weight;
	    }
	if (countsum > 0.0) {
	    offset /= countsum;
	    pdcoeff /= countsum;
	}
	else
	    offset = global_mean;
	forecastvar = variance;
    }
    divisor = p->lambda*forecastvar;
    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
/*
 * Returns the agent's requested bid (if >0) or offer (if <0) using
 * best (or mean) linear forecast chosen by -prepareForTrading.
 */
{

// The actual forecast is given by
//       forecast = pdcoeff*(trialprice+dividend) + offset
// where pdcoeff and offset are set by -prepareForTrading.
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
	demand = - (trialprice*intratep1/divisor + position);
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
    
    [super constrainDemand:slope:trialprice];
    return demand;
}


- updatePerformance
{
    register struct BF_fcast *fptr;
    double pd, deviation, ftarget, tauv, a, b, c, av, bv, maxdev,maxdevsq;
    double ae,be;

   p = params;

// Construct actual forecasts for later updates.  "price" is now the
// actual trade price (the last trialprice).
#if WEIGHTED == 0
    pd = price + dividend;
//    pd = 0;
    for (fptr=activelist; fptr!=NULL; fptr=fptr->next)
	fptr->forecast = fptr->a*pd + fptr->b*dividend + fptr->c;
#endif

// Now update all the forecasts that were active in the previous period,
// since now we know how they performed.

// Precompute things for speed
    tauv = p->tauv;
    a = 1.0/tauv;
    b = 1.0-a;
// special rates for variance
// We often want this to be different from tauv
// PARAM:  100. should be a parameter  BL
    av = 1.0/tauv;
    bv = 1.0-av;

    ae = 1.0/10.;
    be = 1.0 - ae;

    /* fixed variance if tauv at max */
    if (tauv == 100000) {
	a = 0.0;
	b = 1.0;
        av = 0.0;
        bv = 1.0;
    }
//  make these easy to get to
    maxdev = p->maxdev;
    maxdevsq = maxdev*maxdev;

// Update global mean (p+d) and our variance
    ftarget = price + dividend;
//    ftarget = 0.90 + 0.1*normal() ;
    deviation = ftarget - lforecast;
    if (fabs(deviation) > maxdev) deviation = maxdev;
    global_mean = b*global_mean + a*ftarget;
    // Use default for initial variances - for stability at startup
    if (t < tauv)
	variance = p->initvar;
    else
	variance = bv*variance + av*deviation*deviation;

// Update all the forecasters that were activated.
    if (t > 1)
    for (fptr=lactivelist; fptr!=NULL; fptr=fptr->lnext) {

//      Handle error summary
        deviation = ftarget - fptr->lforecast;

/*
  	if (fptr->errct > tauv )
            fptr->error = b*fptr->error + a*deviation;
	else {
	    c = 1.0/(1.+fptr->errct);
	    fptr->error = (1.0 - c)*fptr->error +
						c*deviation;
        }
        fptr->errct++;
*/

        deviation = deviation*deviation;
// 	Benchmark test line - replace true deviation with random one
//      PARAM: Might be coded as a parameter sometime 
//      deviation = drand(); 
/* Only necessary for absolute deviations
	if (deviation < 0.0) deviation = -deviation;
*/
	if (deviation > maxdev) deviation = maxdev;
  	if (fptr->count > 0 )
            fptr->actvar = b*fptr->actvar + a*deviation;
	else {
	    c = 1.0/(1.+fptr->count);
	    fptr->actvar = (1.0 - c)*fptr->actvar +
						c*deviation;
	}
/*
        fptr->strength = 1./fptr->variance+(16-fptr->specificity);
*/
    }

// NOTE: On exit, fptr->forecast is only guaranteed to be valid for
// forcasters which matched.  The inspector has to calculate the rest
// itself if it wants to show them all.  This is for speed.
    return self;
}


- enabledStatus:(BOOL)flag
{
    if (!flag) {	/* cleanup for display when disabled */
	forecast = 0.0;
	nactive = 0;
	activelist = NULL;
    }
    return self;
}


/* mark "technical rule" for detailed printout
 * might parameterize, but probably best to rewrite print
 * status method */
 
#define TTRULE 13

/*
 *  This method prints out selected details on the bf agent
 *  Used by AgentManager
 *  It is a mess, and it always will be since it depends on current
 *    production runs.
*/
- pAgentStatus:(FILE *) fp
{
    struct BF_fcast *fptr, *topfptr;
    //    int i;
    int *count[4];
/*
    double pm[3],pm2[3];
    double pmtt[3],pm2tt[3];
    double pmtt2[3],pm2tt2[3];
    double sum1,sum2;
*/

    topfptr = fcast + p->numfcasts;
    condbits = [self bitDistribution:&count cumulative:NO];

/*  these print formats are tuned to some of my analysis programs - please
 *  don't change BL 
 */
/*
    for (fptr = fcast; fptr < topfptr; fptr++) { 
	fprintf(fp,"%f %f %d ",fptr->variance,fptr->strength,fptr->count);
         	for (i=0; i<condbits; i++)
		fprintf(fp,"%d ",
		(fptr->conditions[WORD(i)] >> SHIFT[i])&3);
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
    topfptr = fcast + p->numfcasts;
*/

    for (fptr = fcast; fptr < topfptr; fptr++) {
	fprintf(fp,"%8.3lf %8.3lf %8.3lf %8.3lf %8.3lf %2d %6d %6d %6d %6d\n", 
	fptr->strength,fptr->variance,fptr->a,fptr->c,
	fptr->actvar,fptr->specificity,fptr->count,fptr->lastactive,
	fptr->lastused,fptr->birth);
    }

/*  get first and second moments for forecast parameters for 
    both unconditional and rules using technical bit specified. */
/*
    for (fptr = fcast; fptr < topfptr; fptr++) {
    	pm[0] += fptr->c;
    	pm[1] += fptr->a;
	pm[2] += fptr->b;
    	pm2[0] += fptr->c*fptr->c;
    	pm2[1] += fptr->a*fptr->a;
	pm2[2] += fptr->b*fptr->b;
    }
    for (fptr = fcast; fptr < topfptr; fptr++) {
	if(((fptr->conditions[WORD(TTRULE)] >> SHIFT[TTRULE])&3) == 1) {
	    pmtt[0] += fptr->c;
	    pmtt[1] += fptr->a;
	    pmtt[2] += fptr->b;
	    pmtt2[0] += fptr->c*fptr->c;
	    pmtt2[1] += fptr->a*fptr->a;
	    pmtt2[2] += fptr->b*fptr->b;
	    sum1 += fptr->count;
	}
	if(((fptr->conditions[WORD(TTRULE)] >> SHIFT[TTRULE])&3) == 2) {
	    pm2tt[0] += fptr->c;
	    pm2tt[1] += fptr->a;
	    pm2tt[2] += fptr->b;
	    pm2tt2[0] += fptr->c*fptr->c;
	    pm2tt2[1] += fptr->a*fptr->a;
	    pm2tt2[2] += fptr->b*fptr->b;
	    sum2 += fptr->count;
	}
    }
 */   
/*
    if((pmtt[0]==0) && (count[1][TTRULE]+count[2][TTRULE]!=0)) {
        topfptr = fcast + p->numfcasts;
	for (fptr = fcast; fptr < topfptr; fptr++) {
	    for(i=0; i<condbits; i++)
		fprintf(fp,"%d ",(fptr->conditions[WORD(i)]>>SHIFT[i])&3);
	    fprintf(fp,"\n");
	}
    }    

*/
/*
    for(i=0;i<3;i++) {
	pm[i] /=  ((double)p->numfcasts);
	pm2[i] = pm2[i]/((double)p->numfcasts);
	fprintf(fp,"%f %f %f ",pm[i],pmtt[i],pm2tt[i]);
	fprintf(fp,"%f %f %f ",pm2[i],pmtt2[i],pm2tt2[i]);
    }

    fprintf(fp,"%d %d\n",count[1][TTRULE],count[2][TTRULE]);
*/
    return self;
}


- (int)nbits
{
    return p->condbits;
}


- (int)nrules
{
    return p->numfcasts;
}


- (int)lastgatime
{
    return lastgatime;
}


- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum
{
    struct BF_fcast *fptr, *topfptr;
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

    topfptr = fcast + p->numfcasts;
    for (fptr = fcast; fptr < topfptr; fptr++) {
	agntcond = fptr->conditions;
        if(t - fptr->lastused<10000)
	for (i = 0; i < condbits; i++)
	    count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
    }
    return condbits;
}

- (int)fMoments:(double *)moment cumulative:(BOOL)cum
{
    struct BF_fcast *fptr, *topfptr;
    int i;
    double twt,wt;
    double mt[8];

    condbits = p->condbits;

    if (!cum)
	for(i=0;i<8;i++)
	    moment[i] = 0;

    for(i=0;i<8;i++)
	    mt[i] = 0;

    twt = 0;
    topfptr = fcast + p->numfcasts;
    for (fptr = fcast; fptr < topfptr; fptr++) {

	    if((t-fptr->lastactive<10000) && (fptr->strength>=medstrength))
                  twt += wt = 1;
            else
                  wt = 0;
/*
	    twt += wt = 1;
*/
	    mt[0] += wt*fptr->a;
	    mt[2] += wt*fptr->b;
	    mt[4] += wt*fptr->c;
	    mt[6] += wt*fptr->variance;
    }
    if(twt!=0)
    for(i=0;i<8;i+=2)
	mt[i] /= twt;
    else
    for(i=0;i<8;i+=2)
	mt[i] = 0;


    twt = 0;
    for (fptr = fcast; fptr < topfptr; fptr++) {

	    if((t-fptr->lastactive<10000) && (fptr->strength>=medstrength))
                  twt += wt = 1;
            else
                  wt = 0;
/*
	    twt += wt = 1;
*/
	    mt[1] += wt*fabs(fptr->a-mt[0]);
	    mt[3] += wt*fabs(fptr->b-mt[2]);
	    mt[5] += wt*fabs(fptr->c-mt[4]);
	    mt[7] += wt*fabs(fptr->variance-mt[6]);
    }
    if(twt!=0)
    for(i=1;i<8;i+=2)
        mt[i] /= twt; 
    else
    for(i=1;i<8;i+=2)
        mt[i] = 0; 


    for(i=0;i<8;i+=1)
        moment[i] += mt[i]; 

    return 1;
}


- (const char *)descriptionOfBit:(int)bit
{
    if (bit < 0 || bit > p->condbits)
	return "(Invalid condition bit)";
    else
	return [World descriptionOfBit:p->bitlist[bit]];
}


// Genetic algorithm
//
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
//  4. Generalize() looks for rules that haven't been triggered for
//     "longtime" and generalizes them by changing a randomly chosen
//     fraction "genfrac" of 0/1 bits to "don't care".  It does this
//     independently of strength to all rules in the population.
//
// Parameter list:
//
//   npool	-- size of pool of weakest rules for possible relacement;
//		   specified as a fraction of numfcasts by "poolfrac"
//   nnew	-- number of new rules produced
//		   specified as a fraction of numfcasts by "newfrac"
//   pcrossover -- probability of running Crossover() at all.
//   plinear    -- linear combination "crossover" prob.
//   prandom    -- random from each parent crossover prob.
//   pmutation  -- per bit mutation prob.
//   plong      -- long jump prob.
//   pshort     -- short (neighborhood) jump prob.
//   nhood      -- size of neighborhood.
//   longtime	-- generalize if rule unused for this length of time
//   genfrac	-- fraction of 0/1 bits to make don't-care when generalising


/*------------------------------------------------------*/
/*	GA						*/
/*------------------------------------------------------*/
- performGA
{
    register struct BF_fcast *fptr;
    struct BF_fcast *nr;
    register int f;
    //register int i;
    int specificity, new, parent1, parent2;
    BOOL changed;
    double ava,avb,avc,sumc;
    double dn;
    double temp[MAXRULE];
    double bitcost;
    double meanv,madv;

    ++gacount;
    p->lastgatime = lastgatime = t;

/* Make instance variable visible to GA routines */
    pp = p;
    condwords = p->condwords;
    condbits = p->condbits;
    bitlist = p->bitlist;
    bitcost = p->bitcost;

    for (f=0; f < p->numfcasts; f++) {
        // This is here for startup where strength = 0
        if(fcast[f].count != 0) {
            if(fcast[f].count>pp->mincount)
                    fcast[f].active = 1;
            fcast[f].variance = fcast[f].actvar;
	    fcast[f].strength  = p->maxdev-fcast[f].variance+fcast[f].specfactor ;
         }
         temp[f] = fcast[f].strength;
   }

   if(t<25000000) {

// Find the npool weakest rules, for later use in TrnasferFcasts
    MakePool(fcast);

// Compute median strength
    medstrength = lthreshstrength;
    lmedstrength = median(temp,p->numfcasts);


// Compute average strength (for assignment to new rules)
    avstrength = ava = avb = avc = sumc = 0.0;
    meanv = meane = meana = meanb = meanc = stda = stdb = stdc = 0;
    minstrength = 1.0e20;
    for (f=0; f < p->numfcasts; f++) {
    	avstrength += fcast[f].strength;
	sumc += 1./fcast[f].variance*(fcast[f].count>0);
	ava += fcast[f].a * 1./fcast[f].variance* (fcast[f].count>0);
	avb += fcast[f].b * 1./fcast[f].variance* (fcast[f].count>0);
	avc += fcast[f].c * 1./fcast[f].variance* (fcast[f].count>0);
        meanv += fcast[f].variance;
        meana += fcast[f].a;
	meanb += fcast[f].b;
	meanc += fcast[f].c;
        stda += fcast[f].a*fcast[f].a;
	stdb += fcast[f].b*fcast[f].b;
	stdc += fcast[f].c*fcast[f].c;
        if(fcast[f].strength<minstrength)
             minstrength = fcast[f].strength;
    }
    lminstrength = minstrength;
    if(sumc!=0) {
    ava /= sumc;
    avb /= sumc;
    avc /= sumc;
    }
    else {
    ava = fcast[0].a;
    avb = fcast[0].b;
    avc = fcast[0].c;
    }
    dn = p->numfcasts;
    meana /= dn;
    meanb /= dn;
    meanc /= dn;
    meanv /= dn;
    stda /= dn;
    stdb /= dn;
    stdc /= dn;
    stda = sqrt(stda-meana*meana);
    stdb = sqrt(stdb-meanb*meanb);
    if(stdc>meanc*meanc)
    stdc = sqrt(stdc-meanc*meanc);
    else
    stdc = 0;

    madv = 0;
    for (f=0; f < p->numfcasts; f++) {
	madv += fabs(fcast[f].variance-meanv);
    }
    madv /= dn;


/*
 * Set rule 0 (always all don't care) to inverse variance weight 
 * of the forecast parameters.  A somewhat Bayesian way for selecting 
 * the params for the unconditional forecast.  Remember, rule 0 is imune to
 * all mutations and crossovers.  It is the default rule.
*/
    fcast[0].a = ava;
    fcast[0].b = avb;
    fcast[0].c = avc;

    meanc = avc;

    lavstrength = avstrength /= p->numfcasts;
    // fitness = avstrength;

//  RANDOM sim for mean error
/*
    for(i=0;i<10;i++) {
        f = irand(p->numfcasts);
        meane += fcast[f].error;
    }
    meane /= 10.;
*/
	

// Loop to construct nnew new rules
    for (new = 0; new < p->nnew; new++) {
	changed = NO;

    // Loop used if we force diversity
	do {

	// Pick first parent using touranment selection
	    do
		parent1 = Tournament(fcast);
	    while (parent1 == -1);

	// Perhaps pick second parent and do crossover; otherwise just copy
	    if (drand() < p->pcrossover) {
		do
		    parent2 = Tournament(fcast);
		while (parent2 == parent1 || parent2 == -1) ;
		Crossover(fcast, new, parent1, parent2);
		changed = YES;
	    }
	    else
		CopyRule(&newfcast[new],&fcast[parent1]);

	// Mutate the result
            if(changed==NO)
	    if (Mutate(new,changed)) changed = YES;

	// Set strength and lastactive if it's really new
	    if (changed) {
		nr = newfcast + new;
                nr->actvar = p->maxdev-nr->strength+nr->specfactor; 
                if(nr->actvar<(fcast[0].variance-madv)) {
                    nr->actvar = fcast[0].variance-madv;
                    nr->strength = p->maxdev - (fcast[0].variance - madv) + nr->specfactor;
		}
/*
                if(nr->actvar<variance)) {
                    nr->actvar = variance;
                    nr->strength = p->maxdev - variance + nr->specfactor;
		}
*/
/*
                if((nr->count<p->tauv)&&(nr->actvar<pp->initvar)) {
                    nr->strength = lmedstrength;
                    nr->actvar = p->maxdev - lmedstrength + nr->specfactor;
		}
*/
                if(nr->actvar <= 0) {
                    nr->actvar = p->maxdev - lmedstrength + nr->specfactor;
                    nr->strength = lmedstrength;
                }
/*
                if(nr->count == 0) {
                    nr->actvar = p->maxdev - lmedstrength + nr->specfactor;
                    nr->strength = lmedstrength;
                }
*/
                nr->variance = nr->actvar;
		nr->lastactive = t;
		nr->birth = t;
                nr->error = 0;
                nr->errct = 0;
                nr->active = 0;
                nr->count = 0;
	    }


	} while (!changed);
	/* Replace while(0) with while(!changed) to force diversity */
    }

// Replace nnew of the weakest old rules by the new ones
    TransferFcasts();

// Generalize any rules that haven't been used for a long time
    Generalize(fcast);

// Compute average specificity
    specificity = 0;
    for (f = 0; f < p->numfcasts; f++) {
	fptr = fcast + f;
	specificity += fptr->specificity;
        if(irand(4)==0) {
		fptr->error = 0;
                fptr->errct = 0;
        }
    }
    avspecificity = ((double) specificity)/p->numfcasts;
    }

    return self;
}


/*------------------------------------------------------*/
/*	CopyRule					*/
/*------------------------------------------------------*/
static void CopyRule(struct BF_fcast *to, struct BF_fcast *from)
{
    unsigned int *conditions;
    int i;

    conditions = to->conditions;	// save pointer to conditions
    *to = *from;			// copy whole fcast structure
    to->conditions = conditions;	// restore pointer to conditions
    for (i=0; i<condwords; i++)
	conditions[i] = from->conditions[i];	// copy actual conditions
}


/*------------------------------------------------------*/
/*	MakePool					*/
/*------------------------------------------------------*/
static void MakePool(struct BF_fcast *fcast)
{
    register int j, top;
    register struct BF_fcast *fptr, *topfptr;

// Dumb bubble sort
    topfptr = fcast + pp->npool;
    top = -1;
    for (fptr = fcast; fptr < topfptr; fptr++) {
	for (j = top; j >= 0 && fptr->strength < reject[j]->strength; j--)
	    reject[j+1] = reject[j];
	reject[j+1] = fptr;
	top++;
    }
    topfptr = fcast + pp->numfcasts;
    for (; fptr < topfptr; fptr++) {
	if (fptr->strength < reject[top]->strength) {
	    for (j = top-1; j>=0 && fptr->strength < reject[j]->strength; j--)
		reject[j+1] = reject[j];
	    reject[j+1] = fptr;
	}
    }
    /* protect all don't cares (first) from elimination - bl */
    lthreshstrength = reject[pp->npool-1]->strength;
    for(j=0;j<pp->npool;j++)
    	if (reject[j]==fcast) reject[j] = NULL;
/* Note that reject[npool-1]->strength gives the "dud threshold" */

}


/*------------------------------------------------------*/
/*	Tournament					*/
/*------------------------------------------------------*/
static int Tournament(struct BF_fcast *fcast)
{
/*
    int	candidate1 = irand(pp->numfcasts);
    int	candidate2;
*/

    int candidate1,candidate2,i;
        i = 0;
        do {
          candidate1  = irand(pp->numfcasts);
          i++;
        }
        while((fcast[candidate1].count==0)&&(i<50));
        i = 0;
        do {
          candidate2  = irand(pp->numfcasts);
          i++;
       }
       while((candidate2==candidate1)||((fcast[candidate2].count==0)&&(i<50)));
        
/*
           
    do
	candidate2 = irand(pp->numfcasts);
    while (candidate2 == candidate1);

*/
    if (fcast[candidate1].strength > fcast[candidate2].strength)
	return candidate1;
    else
	return candidate2;

}

/*------------------------------------------------------*/
/*	Crossover					*/
/*------------------------------------------------------*/
static void Crossover(struct BF_fcast *fcast, int new, int parent1,
int parent2)
/*
 * On the condition bits, Crossover() uses uniform crossover -- each
 * bit is chosen randomly from one parent or the other.
 * For the real-valued forecasting parameters, Crossover() does
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
    register int bit;
    unsigned int *cond1, *cond2, *newcond;
    struct BF_fcast *nr = newfcast + new;
    int	word, parent, specificity;
    double weight1, weight2, choice;
    int bitparent;

/* Uniform crossover of condition bits */
    newcond = nr->conditions;
    cond1 = fcast[parent1].conditions;
    cond2 = fcast[parent2].conditions;
    if(irand(1)==0) {
    for (word = 0; word <condwords; word++)
	newcond[word] = 0;
    for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (irand(2)?cond1:cond2)[WORD(bit)]&MASK[bit];
    }
    else {
    bitparent = irand(2);
    for (word = 0; word <condwords; word++)
	newcond[word] = 0;
    for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (bitparent?cond1:cond2)[WORD(bit)]&MASK[bit];
    }

/* Select one crossover method for the forecasting parameters */
    choice = drand();
    if (choice < pp->plinear) {

    /* Crossover method 1 -- linear combination */
	if((fcast[parent1].variance>0) && (fcast[parent2].variance>0))
	    weight1 = 1./fcast[parent1].variance/(1./fcast[parent1].variance +
				    1./fcast[parent2].variance);
	else
	    weight1 = 0.5;
	weight2 = 1.0-weight1;
	nr->a = weight1*fcast[parent1].a + weight2*fcast[parent2].a;
	nr->b = weight1*fcast[parent1].b + weight2*fcast[parent2].b;
	nr->c = weight1*fcast[parent1].c + weight2*fcast[parent2].c;
    }
    else if (choice < pp->plinear + pp->prandom) {

    /* Crossover method 2 -- randomly from each parent */
	nr->a = fcast[(irand(2)? parent1: parent2)].a;
	nr->b = fcast[(irand(2)? parent1: parent2)].b;
	nr->c = fcast[(irand(2)? parent1: parent2)].c;
    }
    else {

    /* Crossover method 3 -- all from one parent */
	parent = (irand(2)? parent1: parent2);
	nr->a = fcast[parent].a;
	nr->b = fcast[parent].b;
	nr->c = fcast[parent].c;
    }

/* Set miscellanaeous variables (but not lastactive, strength, variance) */
//    nr->count = 0;	// call it new in any case
    if (fcast[parent1].count<fcast[parent2].count)
       nr->count = fcast[parent1].count;
    else
       nr->count = fcast[parent2].count;
/*
    if (fcast[parent1].lastactive<fcast[parent2].lastactive)
       nr->lastactive = fcast[parent2].lastactive;
    else
       nr->lastactive = fcast[parent1].lastactive;
*/
    nr->lastactive = (fcast[parent1].lastactive+fcast[parent2].lastactive)/2;
       
    specificity = -pp->nnulls;
    for (bit = 0; bit < condbits; bit++)
	if ((nr->conditions[WORD(bit)]&MASK[bit]) != 0)
	    specificity++;
    nr->specificity = specificity;
//    nr->specfactor = 1.0/(1.0 + pp->bitcost*nr->specificity);
    nr->specfactor = (condbits - nr->specificity)*pp->bitcost;
    nr->error = 0;
/*
    if( ((fcast[parent1].count * fcast[parent2].count) == 0 )||
         ((t-fcast[parent1].lastactive)>pp->longtime) ||
         ((t-fcast[parent2].lastactive)>pp->longtime) )
*/
/*
    if( (fcast[parent1].count + fcast[parent2].count) == 0 )
*/
    if(( ((t-fcast[parent1].lastactive)>pp->longtime) || 
        ((t-fcast[parent2].lastactive)>pp->longtime) ) || 
		((fcast[parent1].count*fcast[parent2].count)==0))
        nr->strength = lmedstrength;
    else 
/*
    if( (fcast[parent1].count * fcast[parent2].count) == 0 )
        nr->strength = lmedstrength;
    else
*/
        nr->strength = 0.5*(fcast[parent1].strength+fcast[parent2].strength);
/*
        nr->strength = lavstrength;
*/
/*
Experimental code to allow inherited strength, making sure
that unused rules don't permeate good strength.  Too complicated
for now, but keep this around.  Stength is set in the main GA
routine anyway. BL
    if((fcast[parent1].count==0) || (fcast[parent2].count==0))
        nr->strength = lavstrength;
    else
        nr->strength = 0.5*(fcast[parent1].strength+fcast[parent2].strength);
*/

}


/*------------------------------------------------------*/
/*	Mutate						*/
/*------------------------------------------------------*/
static BOOL Mutate(int new, BOOL changed)
/*
 * For the condition bits, Mutate() looks at each bit with
 * probability pmutation.  If chosen, a bit is changed as follows:
 *    0  ->  * with probability 2/3, 1 with probability 1/3
 *    1  ->  * with probability 2/3, 0 with probability 1/3
 *    *  ->  0 with probability 1/3, 1 with probability 1/3,
 *           unchanged with probability 1/3
 * This maintains specificity on average.
 *
 * For the forecasting parameters, Mutate() may do one of two things,
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
    register int bit;
    register struct BF_fcast *nr = newfcast + new;
    unsigned int *cond, *cond0;
    double choice, temp;
    BOOL bitchanged = NO;
    BOOL longjump   = NO;
    int  selmutate;

    bitchanged = changed;
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
		    bitchanged = changed = YES;
		}
		else if (irand(3) > 0) {
		    *cond |= (irand(2)+1) << SHIFT[bit];
		    nr->specificity++;
		    bitchanged = changed = YES;
		}
	    }
	}
    }

    selmutate = irand(2);
    /* mutate p+d coefficient */
    if(0==0) {
    choice = drand();
    if (choice < pp->plong) {
	/* long jump = uniform distribution between min and max */
	nr->a =  pp->a_min + pp->a_range*drand();
/*
        nr->a = meana;
*/
/*
        temp = nr->a + 2.*stda*urand();
	nr->a = (temp > pp->a_max? pp->a_max:
		    (temp < pp->a_min? pp->a_min: temp));
*/
	if(pp->a_range !=0) {
	    changed = YES;
            longjump = YES;
        }
    }
    else if (choice < pp->plong + pp->pshort) {
	/* short jump  = uniform within fraction nhood of range */
/*
	if(nr->error==0)
	    temp = nr->a + pp->a_range*pp->nhood*urand();
	else {
        if(nr->error > 0)
	    temp = nr->a - pp->a_range*pp->nhood*drand();
	else
     	    temp = nr->a + pp->a_range*pp->nhood*drand(); 
        }
*/
	temp = nr->a + pp->a_range*pp->nhood*urand();
	nr->a = (temp > pp->a_max? pp->a_max:
		    (temp < pp->a_min? pp->a_min: temp));
	if(pp->a_range !=0)
	    changed = YES;
	changed = YES;
    }
    }
    /* else leave alone */

    /* mutate dividend coefficient */
    choice = drand();
    if (choice < pp->plong) {
	/* long jump = uniform distribution between min and max */
	nr->b =  pp->b_min + pp->b_range*drand();
	if(pp->b_range !=0) {
	    changed = YES;
            longjump = YES;
        }
    }
    else if (choice < pp->plong + pp->pshort) {
	/* short jump  = uniform within fraction nhood of range */
	temp = nr->b + pp->b_range*pp->nhood*urand();
	nr->b = (temp > pp->b_max? pp->b_max:
		    (temp < pp->b_min? pp->b_min: temp));
	if(pp->b_range !=0)
	changed = YES;
    }
    /* else leave alone */

    /* mutate constant term */
    if(1==1) {
    choice = drand();
    if (choice < pp->plong) {
	/* long jump = uniform distribution between min and max */
        if(0==0)
	temp =  pp->c_min + pp->c_range*drand();
        else
        temp = meanc + meane;
/*
        temp = nr->c + 2.*stdc*urand();
*/
/*
        temp = nr->c + 0.5*nr->error;
*/
	nr->c = (temp > pp->c_max? pp->c_max:
		    (temp < pp->c_min? pp->c_min: temp));
	if(pp->c_range !=0) {
	    changed = YES;
            longjump = YES;
        }
    }
    else if (choice < pp->plong + pp->pshort) {
	/* short jump  = uniform within fraction nhood of range */
//	if(nr->error==0)
        if(0==0)
	    temp = nr->c + pp->c_range*pp->nhood*urand();
	else {
        if(nr->error > 0)
	    temp = nr->c + pp->c_range*pp->nhood*drand();
	else
     	    temp = nr->c - pp->c_range*pp->nhood*drand(); 
        }

/*
        if(nr->error > 0)
	    temp = nr->c - 5.*stdc*pp->nhood*drand();
	else
     	    temp = nr->c + 5.*stdc*pp->nhood*drand(); 
*/
/*
        temp = nr->c + nr->error;
*/

	nr->c = (temp > pp->c_max? pp->c_max:
		    (temp < pp->c_min? pp->c_min: temp));
	changed = YES;
    }
    }
    /* else leave alone */


    if (changed) {
        nr->error = 0;
//	nr->specfactor = 1.0/(1.0 + pp->bitcost*nr->specificity);
        nr->specfactor = (condbits - nr->specificity)*pp->bitcost;
/*
        if((nr->count==0)||((t - nr->lastactive) > pp->longtime))
*/
        if( (nr->count==0) || ((t-nr->lastactive) > pp->longtime))
            nr->strength = lmedstrength;
         else
            if(bitchanged)
              nr->strength = lmedstrength;
    }
/*
    if(bitchanged)
        if( nr->count!=0)
	    nr->strength = lmedstrength;
        else
            nr->strength = lminstrength;
*/
/*
 * This is some messy code to set up a second generalization system on
 * rules that aren't changed.  It works hard to keep the proliferation
 * of unuseable rules down.
*/
/*
    else {
	    int j;
            
	    if(irand(5)==-10) {
	    j = (int)ceil(nr->specificity*pp->genfrac);
	    for (;j>0;) {
		bit = irand(condbits);
		if (bitlist[bit] < 0) continue;
		if ((nr->conditions[WORD(bit)]&MASK[bit])) {
		    nr->conditions[WORD(bit)] &= NMASK[bit];
		    --nr->specificity;
		    changed = YES;
		    j--;
		}
	    }
        if(nr->count == 0)
		nr->strength = lminstrength;
        nr->specfactor = 1.0/(1.0 + pp->bitcost*nr->specificity);
        nr->specfactor = (condbits - nr->specificity)*pp->bitcost;
	nr->count = 0;
	}
    }
*/
    nr->specfactor = (condbits - nr->specificity)*pp->bitcost;
//    nr->count = 0;

    return(changed);
}


/*------------------------------------------------------*/
/*	TransferFcasts					*/
/*------------------------------------------------------*/
static void TransferFcasts()
{
    register struct BF_fcast *fptr, *nr;
    register int new;
    int nnew;
    int j;

    nnew = pp->nnew;
/*
    for (new = 0; new < nnew; new++) {
	nr = newfcast + new;
	fptr = GetMort(nr);

    // Copy the whole structure and conditions
	CopyRule(fptr, nr);
    }
*/
    j = 0;
    for (new = 0; new < nnew; new++) {
	nr = newfcast + new;
	while( (fptr = reject[j++])==NULL);
	{
	  printf(" %d. replaced strength=%f\n",j,fptr->strength);//BaT
	CopyRule(fptr, nr);
	}
    }

}


/*------------------------------------------------------*/
/*	GetMort						*/
/*------------------------------------------------------*/
static struct BF_fcast *GetMort(struct BF_fcast *nr)
/* GetMort() selects one of the npool weak old fcasts to replace
 * with a newly generated rule.  It pays no attention to strength,
 * but looks at similarity of the condition bits -- like tournament
 * selection, we pick two candidates at random and choose the one
 * with the MORE similar bitstring to be replaced.  This maintains
 * more diversity.
 */
{
  //register int bit, temp1, temp2, different1, different2;
    
    struct BF_fcast *fptr;
    // unsigned int *cond1, *cond2, *newcond;
    int npool, r1;
    //    int r2, bitmax, word;

    npool = pp->npool;

    r1 = irand(npool);
    while ((reject[r1] == NULL))
	r1 = irand(npool);
/*
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
*/

/*
 *  This is the big decision whether to push diversity by selecting rules
 *  to leave.  Original version is 1 which choses the least different rules
 *  to leave.  Version 2 choses at random, and version 3 choses the least
 *  frequently used rule.  
*/
/*
    if (different1 < different2) {
	fptr = reject[r1];
	reject[r1] = NULL;
    }
    else {
	fptr = reject[r2];
	reject[r2] = NULL;
    }
*/
	fptr = reject[r1];
	reject[r1] = NULL;
/*
	if(reject[r1]->count < reject[r2]->count) {
	fptr = reject[r1];
	reject[r1] = NULL;
        }
	else {
	fptr = reject[r2];
	reject[r1] = NULL;
	}
*/
    return fptr;
}


/*------------------------------------------------------*/
/*	Generalize					*/
/*------------------------------------------------------*/
static void Generalize(struct BF_fcast *fcast)
/*
 * Each forecast that hasn't be used for longtime is generalized by
 * turning a fraction genfrac of the 0/1 bits to don't-cares.
 */
{
    register struct BF_fcast *fptr;
    register int f;
    int	bit, j;
    BOOL changed;

    for (f = 0; f < pp->numfcasts; f++) {
	fptr = fcast + f;
	if (t - fptr->lastactive > pp->longtime) {
	    changed = NO;
	    j = (int)ceil(fptr->specificity*pp->genfrac);
	    for (;j>0;) {
		bit = irand(condbits);
		if (bitlist[bit] < 0) continue;
		if ((fptr->conditions[WORD(bit)]&MASK[bit])) {
		    fptr->conditions[WORD(bit)] &= NMASK[bit];
		    --fptr->specificity;
		    changed = YES;
		    j--;
		}
	    }
	    if (changed) {
		fptr->count = 0;
		fptr->lastactive = t;
//	        fptr->specfactor = 1.0/(1.0 + pp->bitcost*fptr->specificity);
	        fptr->specfactor = (condbits-  fptr->specificity)*pp->bitcost;
                fptr->actvar = pp->maxdev-lmedstrength+fptr->specfactor;
                if(fptr->actvar <0 )
			fptr->actvar = fptr->variance; 
                fptr->variance = fptr->actvar; 
		fptr->strength = lmedstrength;
                fptr->error = 0;
	    }
	}
    }
}

@end
