// Code for a "bitstring forecaster" (BF) agent

// +init
//     Initializes the class, setting parameters and allocating space
//     for arrays.
//
// +didInitialize
//     Tells the agent class object that initialization (including creation
//     of agents) is finished.
//
// +prepareForTrading
//	Sent for each type of this class, announcing the start of a new
//	trading period.  The class object can use this to set up any common
//	information for use by getDemandandSlope:forPrice: etc.  The
//	pointer to "params" identifies the particular type.  These class
//	messages are follwed by -prepareForTrading messages to each
//	enabled instance.
//
// +(BOOL)lastgatime
//	Returns the most recent time at which a GA ran for any agent of
//	this type.  
//
// -free
//      frees space used by forecast lists
//
// -(int *(*)[4])bitDistribution;
//	Returns a pointer to an array of 4 pointers to arrays containing the
//	number of 00's, 01's, 10's, and 11's for each of this agent's
//	condition bits, summed over all rules/forecasters.  Agents that
//	don't use condition bits return NULL.  This uses the method
//	-bitDistribution:cumulative: described below that is provided by
//	subclasses that have condition bits.
//
// -(int)nbits
//	Returns the number of condition bits used by this agent, or 0 if
//	condition bits aren't used.
//
// -(const char *)descriptionOfBit: (int)bit
//	If the agent uses condition bits, returns a description of the
//	specified bit.  Invalid bit numbers return an explanatory message.
//	Agents that don't use condition bits return NULL.
//
// -(int)nrules
//	Returns the number of rules or forecasters used by this agent, or 0
//	if rules/forecasters aren't used.
//
// -(int)lastgatime
//	Returns the last time at which an agent's genetic algorithm was run.
//	Agents that don't use a genetic algorithm return MININT.  This may
//	be used to see if the bit distribution might have changed, since
//	a change can only occur through a genetic algorithm.
//
// -(int)bitDistribution:(int *(*)[4])countptr cumulative: (BOOL)cum
//	Places in (*countptr)[0] -- (*countptr)[3] the addresses of 4
//	arrays, (*countptr)[0][i] -- (*countptr)[3][i], which are filled
//	with the number of bits that are 00, 01, 10, or 11 respectively,
//	for each condition bit i= 0, 1, nbits-1, summed over all rules or
//	forecasters.  Returns nbits, the number of condition bits.  If
//	cum is YES, adds the new counts to whatever is in the (*coutptr)
//	arrays already.  Agents that don't use condition bits return -1.
//	The 4-element array (*countptr)[4] must already exist, but the
//	arrays to which its element point are supplied dynamically.  This
//	method must be provided by each subclass that has condition bits.
// 

#import "BFagent.h"
#import <random.h> 
#import "World.h"
#include <misc.h>
#import "BFParams.h"
#import <defobj.h>

extern World *worldForAgent;

//pj: 
//convenience macros to replace stuff from ASM random with Swarm random stuff 
 
#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 
#define urand()  [uniformDblRand getDoubleWithMin: -1 withMax: 1] 
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1]  
 
//  //Macros for bittables
//  #define WORD(bit)	(bit>>4)
//  #define MAXCONDBITS	80
//pj: no need for externs here, not used in other classes
//pj: extern int SHIFT[MAXCONDBITS];
//pj: extern unsigned int MASK[MAXCONDBITS];
//pj: extern unsigned int NMASK[MAXCONDBITS];

static int SHIFT[MAXCONDBITS];
static unsigned int MASK[MAXCONDBITS];
static unsigned int NMASK[MAXCONDBITS];

// Type of forecasting.  WEIGHTED forecasting is untested in its present form.
#define WEIGHTED 0

static void makebittables(void);

//pj: this is a static global declaration of the params object, shared by all instances.
//pj: note there is also a local copy which is, in current code, the same thing.
static BFParams *  params;

//pj: other global variables were moved either to the performGA method where they are 
//pj: needed or into the BFParams class, where they are used to create BFParams objects



//pj: I don't want to share this across agents.  Now it is an IVAR.
// Working space, dynamically allocated, shared by all instances
//    static struct BF_fcast	**reject;	/* GA temporary storage */
//    static struct BF_fcast	*newfcast;	/* GA temporary storage */

//pj:  extern int ReadBitname(const char *variable, const struct keytable *table);
//pj:  ReadBitname moved to BFParams


// PRIVATE METHODS
@interface BFagent(Private)
- performGA;
@end


@implementation BFagent

+(void)setBFParameterObject: x
{
    params=x;
}

+(void)init
{
//Makes the bit tables for the agent    
  makebittables();
  return;
}



static void makebittables()    //declared in BFagent.m
/*
 * Construct tables for fast bit packing and condition checking for
 * classifier systems.  Assumes 32 bit words, and storage of 16 ternary
 * values (0, 1, or *) per word, with one of the following codings:
 * Value       Message-board coding         Rule coding
 *   0			2			1
 *   1			1			2
 *   *			-			0
 * Thus rule satisfaction can be checked with a simple AND between
 * the two types of codings.
 *
 * Sets up the tables to store MAXCONDBITS ternary values in
 * CONDWORDS = ceiling(MAXCONDBITS/16) words.
 *
 * After calling this routine, given an array declared as
 *		int array[CONDWORDS];
 * you can do the following:
 *
 * a. Store "value" (0, 1, 2, using one of the codings above) for bit n with
 *	array[WORD(n)] |= value << SHIFT[n];
 *    if the stored value was previously 0; or
 * 
 * b. Store "value" (0, 1, 2, using one of the codings above) for bit n with
 *	array[WORD(n)] = (array[WORD(n)] & NMASK[n]) | (value << SHIFT[n]);
 *    if the initial state is unknown.
 *
 * c. Store value 0 for bit n with
 *	array[WORD(n)] &= NMASK[n];
 * 
 * d. Extract the value of bit n (0, 1, 2, or possibly 3) with
 *	value = (array[WORD(n)] >> SHIFT[n]) & 3;
 *
 * e. Test for value 0 for bit n with
 *	if ((array[WORD(n)] & MASK[n]) == 0) ...
 *
 * f. Check whether a condition is fulfilled (using the two codings) with
 *	for (i=0; i<CONDWORDS; i++)
 *	    if (condition[i] & array[i]) break;
 *	if (i != CONDWORDS) ...
 *
 */
{
  register int bit;

  for (bit=0; bit < MAXCONDBITS; bit++) 
    {
      SHIFT[bit] = (bit%16)*2;
      MASK[bit] = 3 << SHIFT[bit];
      NMASK[bit] = ~MASK[bit];
    }
}

+didInitialize
{
//    struct BF_fcast *fptr, *topfptr;
//    unsigned int *conditions;
//    unsigned int *newconds;	
    //pj: no longer needed because these are converted to arrays in +init  
  //  // Free working space we're done with
  //    free(probs);
  //    free(bits);



//  // Allocate working space for GA
//    int npoolmax = getDouble(params,"npoolmax");
//    int nnewmax = getDouble(params,"nnewmax");
//    int ncondmax = getDouble (params,"ncondmax");

//    reject = calloc(npoolmax,sizeof(struct BF_fcast *));
//    if(!reject)
//      printf("There was an error allocating space for reject.");

//    newfcast = calloc(nnewmax,sizeof(struct BF_fcast));
//    if(!newfcast)
//      printf("There was an error allocating space for newfcast.");
    
//    newconds = calloc(ncondmax*nnewmax,sizeof(unsigned int));
//    if(!newconds)
//      printf("There was an error allocating space for newconds.");

//  // Tie up pointers for conditions
//    topfptr = newfcast + nnewmax;
//    conditions = newconds;
//    for (fptr = newfcast; fptr < topfptr; fptr++) 
//      {
//        fptr->conditions = conditions;
//        conditions += ncondmax;
//      }

  return self;
}


+prepareForTrading      //called at the start of each trading period
{
  int i, n;
  int * myRealWorld;
  int nworldbits;
  int * bitlist;
  //previously were global vars
  int condbits;
  int condwords;
  int * myworld;
  BFParams * pp;
  //?why relable this?????????????????
  pp=params;

  //pp = params;
  
  condwords = getInt(pp,"condwords");
  condbits = getInt(pp,"condbits");

  //bitlist = pp->bitlist;
  bitlist = [pp getBitListPtr];

  //myworld = pp->myworld;
  myworld = [pp getMyworldPtr];

  for (i = 0; i < condwords; i++)
    myworld[i] = 0;
  //pj: nworldbits = [self setNumWorldBits];
  //replace with:
   nworldbits = [worldForAgent getNumWorldBits];

   //pj:when does this get freed????????
  myRealWorld = calloc(nworldbits, sizeof(int));
  if(!myRealWorld)
    printf("There was an error allocating space for myRealWorld.");
  
  [self setRealWorld: myRealWorld];
  for (i=0; i < condbits; i++) 
    {
      if ((n = bitlist[i]) >= 0)
	myworld[WORD(i)] |= myRealWorld[n] << SHIFT[i];
    }

  return self;
}


//  +(int)lastgatime
//  {
//    //  pp = (struct BFparams *)params;
//    //return pp->lastgatime;
//    return params->lastgatime;
//  }


+setRealWorld: (int *)array
{
  [worldForAgent getRealWorld: array];
  return self;
}

//pj: superfluous method
+(int)setNumWorldBits
{
  int numofbits;
  numofbits = [worldForAgent getNumWorldBits];
  return numofbits;
}

-createEnd
{

  //pj: this is moved from "didInitialize" because these are now IVARS.
  struct BF_fcast *fptr, *topfptr;
  unsigned int *conditions;
  unsigned int *newconds;	


// Allocate working space for GA
  int npoolmax = getDouble(params,"npoolmax");
  int nnewmax = getDouble(params,"nnewmax");
  int ncondmax = getDouble (params,"ncondmax");

  reject = calloc(npoolmax,sizeof(struct BF_fcast *));
  if(!reject)
    printf("There was an error allocating space for reject.");

  newfcast = calloc(nnewmax,sizeof(struct BF_fcast));
  if(!newfcast)
    printf("There was an error allocating space for newfcast.");
    
  newconds = calloc(ncondmax*nnewmax,sizeof(unsigned int));
  if(!newconds)
    printf("There was an error allocating space for newconds.");

  // Tie up pointers for conditions
  topfptr = newfcast + nnewmax;
  conditions = newconds;
  for (fptr = newfcast; fptr < topfptr; fptr++) 
    {
      fptr->conditions = conditions;
      conditions += ncondmax;
    }

  fprintf(stderr,"BFagent creatended \n");
  return [super createEnd];
}


-initForecasts
{
  struct BF_fcast *fptr, *topfptr;
  unsigned int *conditions, *cond;
  int word, bit, specificity;
  int condbits;
  int condwords;
  double *problist;
  double abase, bbase, cbase, asubrange, bsubrange, csubrange;
  double newfcastvar, bitcost;
  int *bitlist;

// Initialize our instance variables

   if ((privateParams =
         [lispAppArchiver getWithZone: [self getZone] key: "bfParams"]) == nil)
      raiseEvent(InvalidOperation,
                 "Can't find the BFParams parameters");
    [privateParams init];

  avspecificity = 0.0;
  lactivelist = activelist = NULL;
  gacount = 0;

  variance = getDouble(privateParams, "initvar");
  [self getPriceFromWorld];
  [self getDividendFromWorld];
  global_mean = price + dividend;
  forecast = lforecast = global_mean;

// Extract some things for rapid use (is this worth it?)
  // condwords = p->condwords;
  condwords = getInt (privateParams,"condwords");
  // condbits = p->condbits;
  condbits = getInt (privateParams,"condbits");
  // bitlist = p->bitlist;
  bitlist = [privateParams getBitListPtr];
  //problist = p->problist;
  problist = [privateParams getProbListPtr];
  newfcastvar = privateParams->newfcastvar;
  bitcost = getDouble (privateParams, "bitcost");

// Allocate memory for forecasts and their conditions
  fcast = calloc(privateParams->numfcasts,sizeof(struct BF_fcast));
  if(!fcast)
    printf("There was an error allocating space for fcast.");
  
  conditions = calloc(privateParams->numfcasts*condwords,sizeof(unsigned int));
  if(!conditions)
    printf("There was an error allocating space for conditions.");

// Iniitialize the forecasts
  topfptr = fcast + privateParams->numfcasts;
  for (fptr = fcast; fptr < topfptr; fptr++) 
    {
      fptr->forecast = 0.0;
      fptr->lforecast = global_mean;
      fptr->count = 0;
      fptr->lastactive = 1;
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
	for (bit = 0; bit < condbits; bit++) 
	  {
	    if (bitlist[bit] < 0)
	      cond[WORD(bit)] |= MASK[bit];	/* Set spacing bits to 3 */
	    else if (drand() < problist[bit]){
	      cond[WORD(bit)] |= (irand(2)+1) << SHIFT[bit];
	      ++fptr->specificity;
	    }
	  }
      fptr->specfactor = 1.0/(1.0 + bitcost*fptr->specificity);
      fptr->variance = newfcastvar;
      fptr->strength = fptr->specfactor/fptr->variance;
    }

/* Compute average specificity */
  specificity = 0;
  for (fptr = fcast; fptr < topfptr; fptr++)
    specificity += fptr->specificity;
  avspecificity = ((double) specificity)/privateParams->numfcasts;

/* Set the forecasting parameters for each fcast to random values in a
 * fraction "subrange" of their range, centered at the midpoint.  For
 * subrange=1 this is the whole range (min to max).  For subrange=0.5,
 * values lie between 1/4 and 3/4 of this range.  subrange=0 gives
 * homogeneous agents, with values at the middle of their min-max range. 
 */
  abase = privateParams->a_min + 0.5*(1.-privateParams->subrange)*privateParams->a_range;
  bbase = privateParams->b_min + 0.5*(1.-privateParams->subrange)*privateParams->b_range;
  cbase = privateParams->c_min + 0.5*(1.-privateParams->subrange)*privateParams->c_range;
  asubrange = privateParams->subrange*privateParams->a_range;
  bsubrange = privateParams->subrange*privateParams->b_range;
  csubrange = privateParams->subrange*privateParams->c_range;
  for (fptr = fcast; fptr < topfptr; fptr++) 
    {
      fptr->a = abase + drand()*asubrange;
      fptr->b = bbase + drand()*bsubrange;
      fptr->c = cbase + drand()*csubrange;
    }
  
  return self;
}


-free
{
  free(fcast->conditions);
  free(fcast);
  return [super free];
}


-prepareForTrading
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
  unsigned int real0 = 0, real1, real2, real3, real4;
  double weight, countsum, forecastvar;
  int mincount;

  int * myworld;
 

#if  WEIGHTED == 1    
  static double a, b, c, sum, sumv;
#else
  struct BF_fcast *bestfptr;
  double maxstrength;
#endif

  topfptr = fcast + privateParams->numfcasts;
  
// First the genetic algorithm is run if due
  currentTime = getCurrentTime( );
  if (currentTime >= privateParams->firstgatime && drand() < privateParams->gaprob) 
    {
      [self performGA]; 
      // Clear linked list for active rules
      lactivelist = activelist = NULL;
    }	    

  lforecast = forecast;
    
// Preserve last active list
  lactivelist = activelist;
  for (fptr = activelist; fptr!=NULL; fptr = fptr->next) 
    {
      fptr->lnext = fptr->next;
      fptr->lforecast = fptr->forecast;
    }

// Main inner loop over forecasters.  We set this up separately for each
// value of condwords, for speed.  It's ugly, but fast.  Don't mess with
// it!  Taking out fptr->conditions will NOT make it faster!  The highest
// condwords allowed for here sets the maximum number of condition bits
// permitted (no matter how large MAXCONDBITS).
  nextptr = &activelist;	/* start of linked list */
  // myworld = p->myworld;
   myworld = [privateParams getMyworldPtr];

  if(!myworld)
    real0 = myworld[0];
  switch (privateParams->condwords) {
  case 1:
    for (fptr = fcast; fptr < topfptr; fptr++) 
      {
	if (fptr->conditions[0] & real0) continue;
	*nextptr = fptr;
	nextptr = &fptr->next;
      }
    break;
  case 2:
    real1 = myworld[1];
    for (fptr = fcast; fptr < topfptr; fptr++) 
      {
	if (fptr->conditions[0] & real0) continue;
	if (fptr->conditions[1] & real1) continue;
	*nextptr = fptr;
	nextptr = &fptr->next;
      }
    break;
  case 3:
    real1 = myworld[1];
    real2 = myworld[2];
    for (fptr = fcast; fptr < topfptr; fptr++) 
      {
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
    for (fptr = fcast; fptr < topfptr; fptr++) 
      {
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
    for (fptr = fcast; fptr < topfptr; fptr++) 
      {
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
  mincount = privateParams->mincount;
  for (fptr=activelist; fptr!=NULL; fptr=fptr->next) 
    {
      fptr->lastactive = t;
      if (++fptr->count >= mincount) 
	{
	  ++nactive;
	  a += fptr->strength*fptr->a;
	  b += fptr->strength*fptr->b;
	  c += fptr->strength*fptr->c;
	  sum += fptr->strength;
	  sumv += fptr->variance;
	}
    }
  if (nactive) 
    {
      pdcoeff = a/sum;
      offset = (b/sum)*dividend + (c/sum);
      forecastvar = (privateParams->individual? sumv/((double)nactive) :variance);
    }
#else
// Now go through the list and find best forecast
  maxstrength = -1e50;
  bestfptr = NULL;
  nactive = 0;
  mincount = privateParams->mincount;
  for (fptr=activelist; fptr!=NULL; fptr=fptr->next) 
    {
      fptr->lastactive = currentTime;
      if (++fptr->count >= mincount) 
	{
	  ++nactive;
	  if (fptr->strength > maxstrength) 
	    {
	      maxstrength = fptr->strength;
	      bestfptr = fptr;
	    }
	}
    }
  if (nactive) 
    {
      pdcoeff = bestfptr->a;
      offset = bestfptr->b*dividend + bestfptr->c;
      forecastvar = (privateParams->individual? bestfptr->variance :variance);
    }
#endif
  else 
    {
      // No forecast!!
      // Use weighted (by count) average of all rules
      countsum = 0.0;
      pdcoeff = 0.0;
      offset = 0.0;
      mincount = privateParams->mincount;
      for (fptr = fcast; fptr < topfptr; fptr++)
	if (fptr->count >= mincount) 
	  {
	    countsum += weight = (double)fptr->strength;
	    offset += (fptr->b*dividend + fptr->c)*weight;
	    pdcoeff += fptr->a*weight;
	  }
      if (countsum > 0.0) 
	{
	  offset /= countsum;
	  pdcoeff /= countsum;
	}
      else
	offset = global_mean;
      forecastvar = variance;
    }
  divisor = privateParams->lambda*forecastvar;
    
  return self;
}


-getInputValues      //does nothing, used only if their are ANNagents
{
  return self;
}


-feedForward        //does nothing, used only if their are ANNagents
{
  return self;
}


-(double)getDemandAndSlope: (double *)slope forPrice: (double)trialprice
/*
 * Returns the agent's requested bid (if >0) or offer (if <0) using
 * best (or mean) linear forecast chosen by -prepareForTrading
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
  if (forecast >= 0.0) 
    {
      demand = -((trialprice*intratep1 - forecast)/divisor + position);
      *slope = (pdcoeff-intratep1)/divisor;
    }
  else 
    {
      forecast = 0.0;
      demand = - (trialprice*intratep1/divisor + position);
      *slope = -intratep1/divisor;
    }

// Clip bid or offer at "maxbid".  This is done to avoid problems when
// the variance of the forecast becomes very small, thought it's not clear
// that this is the best solution.
  if (demand > privateParams->maxbid) 
    { 
      demand = privateParams->maxbid;
      *slope = 0.0;
    }
  else if (demand < -privateParams->maxbid) 
    {
      demand = -privateParams->maxbid;
      *slope = 0.0;
    }
    
  [super constrainDemand:slope:trialprice];
  return demand;
}


-(double)getRealForecast
{
  return forecast;
}


-updatePerformance
{
  register struct BF_fcast *fptr;
  double deviation, ftarget, tauv, a, b, c, av, bv, maxdev;
    
// Now update all the forecasts that were active in the previous period,
// since now we know how they performed.

// Precompute things for speed
  tauv = privateParams->tauv;
  a = 1.0/tauv;
  b = 1.0-a;
// special rates for variance
// We often want this to be different from tauv
// PARAM:  100. should be a parameter  BL
  av = 1.0/(double)100.0;
  bv = 1.0-av;

    /* fixed variance if tauv at max */
  if (tauv == 100000) 
    {
      a = 0.0;
      b = 1.0;
      av = 0.0;
      bv = 1.0;
    }
  maxdev = privateParams->maxdev;

// Update global mean (p+d) and our variance
  [self getPriceFromWorld];
  ftarget = price + dividend;
  realDeviation = deviation = ftarget - lforecast;
  if (fabs(deviation) > maxdev) deviation = maxdev;
  global_mean = b*global_mean + a*ftarget;
// Use default for initial variances - for stability at startup
  currentTime = getCurrentTime( );
  if (currentTime < 1)
    variance = privateParams->initvar;
  else
    variance = bv*variance + av*deviation*deviation;

// Update all the forecasters that were activated.
  if (currentTime > 0)
    for (fptr=lactivelist; fptr!=NULL; fptr=fptr->lnext) 
      {
        deviation = (ftarget - fptr->lforecast)*(ftarget - fptr->lforecast);

// 	Benchmark test line - replace true deviation with random one
//      PARAM: Might be coded as a parameter sometime 
//      deviation = drand(); 

//      Only necessary for absolute deviations
//      if (deviation < 0.0) deviation = -deviation;

	if (deviation > maxdev) deviation = maxdev;
  	if (fptr->count > tauv)
	  fptr->variance = b*fptr->variance + a*deviation;
	else 
	  {
	    c = 1.0/(1.+fptr->count);
	    fptr->variance = (1.0 - c)*fptr->variance +
						c*deviation;
	  }
        fptr->strength = fptr->specfactor/fptr->variance;
      }

// NOTE: On exit, fptr->forecast is only guaranteed to be valid for
// forcasters which matched.  The inspector has to calculate the rest
// itself if it wants to show them all.  This is for speed.
  return self;
}


-(double)getDeviation
{
  return fabs(realDeviation);
}


-updateWeights         //does nothing, used only if their are ANNagents
{
  return self;
}


-(int)nbits
{
  return privateParams->condbits;
}


-(int)nrules
{
  return privateParams->numfcasts;
}


-(int)lastgatime
{
  return lastgatime;
}


-(int)bitDistribution: (int *(*)[4])countptr cumulative: (BOOL)cum
{
  struct BF_fcast *fptr, *topfptr;
  unsigned int *agntcond;
  int i;
  int condbits;
 

  static int *count[4];	// Dynamically allocated 2-d array
  static int countsize = -1;	// Current size/4 of count[]
  static int prevsize = -1;

  condbits = getInt (privateParams, "condbits");

  if (cum && condbits != prevsize)
    printf("There is an error with an agent's condbits.");
  prevsize = condbits;

// For efficiency the static array can grow but never shrink
  if (condbits > countsize) 
    {
      if (countsize > 0) free(count[0]);
      count[0] = calloc(4*condbits,sizeof(int));
      if(!count[0])
	printf("There was an error allocating space for count[0].");
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

  topfptr = fcast + privateParams->numfcasts;
  for (fptr = fcast; fptr < topfptr; fptr++) 
    {
      agntcond = fptr->conditions;
      for (i = 0; i < condbits; i++)
	count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
    }

  return condbits;
}

//pj: this method was never called anywhere
//  -(int)fMoments: (double *)moment cumulative: (BOOL)cum
//  {
//    struct BF_fcast *fptr, *topfptr;
//    int i;
//    int condbits;

//    condbits = getInt (privateParams, "condbits");
  
//    if (!cum)
//  	for(i=0;i<6;i++)
//  	  moment[i] = 0;
  
//    topfptr = fcast + privateParams->numfcasts;
//    for (fptr = fcast; fptr < topfptr; fptr++) 
//      {
//        moment[0] += fptr->a;
//        moment[1] += fptr->a*fptr->a;
//        moment[2] += fptr->b;
//        moment[3] += fptr->b*fptr->b;
//        moment[4] += fptr->c;
//        moment[5] += fptr->c*fptr->c;
//      }
    
//    return privateParams->numfcasts;
//  }

//pj: this method is not called anywhere
//  -(const char *)descriptionOfBit: (int)bit
//  {
//    if (bit < 0 || bit > getInt(privateParams,"condbits"))
//      return "(Invalid condition bit)";
//    else
//      return [World descriptionOfBit:privateParams->bitlist[bit]];
//  }


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

- performGA
{
  register struct BF_fcast *fptr;
  struct BF_fcast *nr;
  register int f;
  int specificity, new, parent1, parent2;
  BOOL changed;
  double ava,avb,avc,sumc;
  //previously declared as globals
  int * bitlist;
  int condbits;
  int condwords;
  static double avstrength,minstrength;	
  static BFParams * pp;  //this is just declared to serve as a shortcut
  static struct BF_fcast *GetMort(struct BF_fcast *);//declares GetMort for other fns


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
  if(from->count==0)
    to->strength = minstrength;
}


/*------------------------------------------------------*/
/*	MakePool					*/
/*------------------------------------------------------*/
static void MakePool(struct BF_fcast *fcastinput)
{
  register int j, top;
  register struct BF_fcast *fptr, *topfptr;

// Dumb bubble sort
  topfptr = fcastinput + pp->npool;
  top = -1;
  for (fptr = fcastinput; fptr < topfptr; fptr++) 
    {
      for (j = top; j >= 0 && fptr->strength < reject[j]->strength; j--)
	reject[j+1] = reject[j];
      reject[j+1] = fptr;
      top++;
    }
  topfptr = fcastinput + pp->numfcasts;
  for (; fptr < topfptr; fptr++) {
    if (fptr->strength < reject[top]->strength) 
      {
	for (j = top-1; j>=0 && fptr->strength < reject[j]->strength; j--)
	  reject[j+1] = reject[j];
	reject[j+1] = fptr;
      }
  }
    /* protect all don't cares (first) from elimination - bl */
  for(j=0;j<pp->npool;j++)
    if (reject[j]==fcastinput) reject[j] = NULL;
/* Note that reject[npool-1]->strength gives the "dud threshold" */
}


/*------------------------------------------------------*/
/*	Tournament					*/
/*------------------------------------------------------*/
static int Tournament(struct BF_fcast *fcastinput)
{
  int candidate1 = irand(pp->numfcasts);
  int candidate2;
    
  do
    candidate2 = irand(pp->numfcasts);
  while (candidate2 == candidate1);

  if (fcastinput[candidate1].strength > fcastinput[candidate2].strength)
      return candidate1;
  else
    return candidate2;
}


/*------------------------------------------------------*/
/*	Crossover					*/
/*------------------------------------------------------*/
static void Crossover(struct BF_fcast *fcastinput, int new, int parent1,
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
  int word, parent, specificity;
  double weight1, weight2, choice;
  int bitparent;

/* Uniform crossover of condition bits */
  newcond = nr->conditions;
  cond1 = fcastinput[parent1].conditions;
  cond2 = fcastinput[parent2].conditions;
  if(irand(1)==0) 
    {
      for (word = 0; word <condwords; word++)
	newcond[word] = 0;
      for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (irand(2)?cond1:cond2)[WORD(bit)]&MASK[bit];
    }
  else 
    {
      bitparent = irand(2);
      for (word = 0; word <condwords; word++)
	newcond[word] = 0;
      for (bit = 0; bit < condbits; bit++)
	newcond[WORD(bit)] |= (bitparent?cond1:cond2)[WORD(bit)]&MASK[bit];
    }

/* Select one crossover method for the forecasting parameters */
  choice = drand();
  if (choice < pp->plinear) 
    {
    /* Crossover method 1 -- linear combination */
      weight1 = fcastinput[parent1].strength/(fcastinput[parent1].strength +
					 fcastinput[parent2].strength);
      weight2 = 1.0-weight1;
      nr->a = weight1*fcastinput[parent1].a + weight2*fcastinput[parent2].a;
      nr->b = weight1*fcastinput[parent1].b + weight2*fcastinput[parent2].b;
      nr->c = weight1*fcastinput[parent1].c + weight2*fcastinput[parent2].c;
    }
  else if (choice < pp->plinear + pp->prandom) 
    {
      /* Crossover method 2 -- randomly from each parent */
      nr->a = fcastinput[(irand(2)? parent1: parent2)].a;
      nr->b = fcastinput[(irand(2)? parent1: parent2)].b;
      nr->c = fcastinput[(irand(2)? parent1: parent2)].c;
    }
  else 
    {
      /* Crossover method 3 -- all from one parent */
      parent = (irand(2)? parent1: parent2);
      nr->a = fcastinput[parent].a;
      nr->b = fcastinput[parent].b;
      nr->c = fcastinput[parent].c;
    }

/* Set miscellanaeous variables (but not lastactive, strength, variance) */
  nr->count = 0;	// call it new in any case
  specificity = -pp->nnulls;
  for (bit = 0; bit < condbits; bit++)
    if ((nr->conditions[WORD(bit)]&MASK[bit]) != 0)
      specificity++;
  nr->specificity = specificity;
  nr->specfactor = 1.0/(1.0 + pp->bitcost*nr->specificity);
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
  int * bitlist= NULL;
  
  //recall pp same as privateParams
  bitlist= [pp getBitListPtr];

  bitchanged = changed;
  if (pp->pmutation > 0) 
    {
      cond0 = nr->conditions;
      for (bit = 0; bit < condbits; bit++) 
	{
	  if (bitlist[bit] < 0) continue;
	  if (drand() < pp->pmutation) 
	    {
	      cond = cond0 + WORD(bit);
	      if (*cond & MASK[bit]) 
		{
		  if (irand(3) > 0) 
		    {
		      *cond &= NMASK[bit];
		      nr->specificity--;
		    }
		  else
		    *cond ^= MASK[bit];
		  bitchanged = changed = YES;
		}
	      else if (irand(3) > 0) 
		{
		  *cond |= (irand(2)+1) << SHIFT[bit];
		  nr->specificity++;
		  bitchanged = changed = YES;
		}
	    }
	}
    }

    /* mutate p+d coefficient */
  choice = drand();
  if (choice < pp->plong) 
    {
      /* long jump = uniform distribution between min and max */
      nr->a =  pp->a_min + pp->a_range*drand();
      changed = YES;
    }
  else if (choice < pp->plong + pp->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = nr->a + pp->a_range*pp->nhood*urand();
      nr->a = (temp > pp->a_max? pp->a_max:
	       (temp < pp->a_min? pp->a_min: temp));
      changed = YES;
    }
    /* else leave alone */

    /* mutate dividend coefficient */
  choice = drand();
  if (choice < pp->plong) 
    {
      /* long jump = uniform distribution between min and max */
      nr->b =  pp->b_min + pp->b_range*drand();
      changed = YES;
    }
  else if (choice < pp->plong + pp->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = nr->b + pp->b_range*pp->nhood*urand();
      nr->b = (temp > pp->b_max? pp->b_max:
	       (temp < pp->b_min? pp->b_min: temp));
      changed = YES;
    }
    /* else leave alone */

    /* mutate constant term */
  choice = drand();
  if (choice < pp->plong) 
    {
      /* long jump = uniform distribution between min and max */
      nr->c =  pp->c_min + pp->c_range*drand();
      changed = YES;
    }
  else if (choice < pp->plong + pp->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = nr->c + pp->c_range*pp->nhood*urand();
      nr->c = (temp > pp->c_max? pp->c_max:
	       (temp < pp->c_min? pp->c_min: temp));
      changed = YES;
    }
    /* else leave alone */

  nr->count = 0;

  if (changed) 
    {
      nr->specfactor = 1.0/(1.0 + pp->bitcost*nr->specificity);
      nr->count = 0;
    }
  
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

  nnew = pp->nnew;
  for (new = 0; new < nnew; new++) 
    {
      nr = newfcast + new;
      fptr = GetMort(nr);
      
    // Copy the whole structure and conditions
      CopyRule(fptr, nr);
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
  register int bit, temp1, temp2, different1, different2;
  struct BF_fcast *fptr;
  unsigned int *cond1, *cond2, *newcond;
  int npool, r1, r2, word, bitmax;
  
  npool = pp->npool;
  
  r1 = irand(npool);
  while ((reject[r1] == NULL))
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
  for (word = 0; word < condwords; word++) 
    {
      temp1 = cond1[word] ^ newcond[word];
      temp2 = cond2[word] ^ newcond[word];
      if (word == condwords-1)
	bitmax = ((condbits-1)&15) + 1;
      for (bit = 0; bit < bitmax; temp1 >>= 2, temp2 >>= 2, bit++) 
	{
	  if (temp1 & 3)
	    different1++;
	  if (temp2 & 3)
	    different2++;
	}
    }

/*
 *  This is the big decision whether to push diversity by selecting rules
 *  to leave.  Original version is 1 which choses the least different rules
 *  to leave.  Version 2 choses at random, and version 3 choses the least
 *  frequently used rule.  
*/
  if (different1 < different2) 
    {
      fptr = reject[r1];
      reject[r1] = NULL;
    }
  else 
    {
      fptr = reject[r2];
      reject[r2] = NULL;
    }
/*
	fptr = reject[r1];
	reject[r1] = NULL;
*/
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
static void Generalize(struct BF_fcast *fcastinput)
/*
 * Each forecast that hasn't be used for longtime is generalized by
 * turning a fraction genfrac of the 0/1 bits to don't-cares.
 */
{
  register struct BF_fcast *fptr;
  register int f;
  int bit, j;
  BOOL changed;
  // int currentTime;
  int * bitlist=NULL;

  bitlist = [pp getBitListPtr];

  //currentTime = getCurrentTime();

    for (f = 0; f < pp->numfcasts; f++) 
      {
	fptr = fcastinput + f;
	if (currentTime - fptr->lastactive > pp->longtime) 
	  {
	    changed = NO;
	    j = (int)ceil(fptr->specificity*pp->genfrac);
	    for (;j>0;) 
	      {
		bit = irand(condbits);
		if (bitlist[bit] < 0) continue;
		if ((fptr->conditions[WORD(bit)]&MASK[bit])) 
		  {
		    fptr->conditions[WORD(bit)] &= NMASK[bit];
		    --fptr->specificity;
		    changed = YES;
		    j--;
		  }
	      }
	    if (changed) 
	      {
		fptr->count = 0;
		fptr->lastactive = currentTime;
		fptr->specfactor = 1.0/(1.0 + pp->bitcost*fptr->specificity);
		fptr->variance = fptr->specfactor/avstrength;
		fptr->strength = fptr->specfactor/fptr->variance;
	      }
	  }
      }
}

//********************************GA work begins now*********************//
//performGA declarations are finished. Now starts the ga method "proper" which uses those
//declared functions and variables.

  ++gacount;
  currentTime = getCurrentTime();

  privateParams->lastgatime= params->lastgatime = lastgatime = currentTime;

/* Make instance variable visible to GA routines */

   pp = privateParams;  //pj: I don't understand why it can't just use p now, but I'm not changing it yet ???

  condwords = pp->condwords;
  condbits = pp->condbits;
  bitlist = pp->bitlist;

// Find the npool weakest rules, for later use in TrnasferFcasts
  MakePool(fcast);

// Compute average strength (for assignment to new rules)
  avstrength = ava = avb = avc = sumc = 0.0;
  minstrength = 1.0e20;
  for (f=0; f < pp->numfcasts; f++) 
    {
      avstrength += fcast[f].strength;
      sumc += 1./fcast[f].variance;
      ava += fcast[f].a * 1./fcast[f].variance;
      avb += fcast[f].b * 1./fcast[f].variance;
      avc += fcast[f].c * 1./fcast[f].variance;
      if(fcast[f].strength<minstrength)
	minstrength = fcast[f].strength;
    }
  ava /= sumc;
  avb /= sumc;
  avc /= sumc;

/*
 * Set rule 0 (always all don't care) to inverse variance weight 
 * of the forecast parameters.  A somewhat Bayesian way for selecting 
 * the params for the unconditional forecast.  Remember, rule 0 is imune to
 * all mutations and crossovers.  It is the default rule.
*/
  fcast[0].a = ava;
  fcast[0].b = avb;
  fcast[0].c = avc;
  
  avstrength /= privateParams->numfcasts;
    

// Loop to construct nnew new rules
  for (new = 0; new < privateParams->nnew; new++) 
    {
      changed = NO;

      // Loop used if we force diversity
      do 
	{

	// Pick first parent using touranment selection
	  do
	    parent1 = Tournament(fcast);
	  while (parent1 == 0);

	// Perhaps pick second parent and do crossover; otherwise just copy
	  if (drand() < privateParams->pcrossover) 
	    {
	      do
		parent2 = Tournament(fcast);
	      while (parent2 == parent1 || parent2 == 0) ;
	      Crossover(fcast, new, parent1, parent2);
	      changed = YES;
	    }
	  else
	    CopyRule(&newfcast[new],&fcast[parent1]);

	// Mutate the result
	  if (Mutate(new,changed)) changed = YES;

	// Set strength and lastactive if it's really new
	  if (changed) {
	    nr = newfcast + new;
	    nr->strength = avstrength;
	    nr->variance = nr->specfactor/nr->strength;
	    nr->lastactive = currentTime;
	  }


	} while (0);
	/* Replace while(0) with while(!changed) to force diversity */
    }

// Replace nnew of the weakest old rules by the new ones
  TransferFcasts();

// Generalize any rules that haven't been used for a long time
  Generalize(fcast);

// Compute average specificity
  specificity = 0;
  for (f = 0; f < privateParams->numfcasts; f++) 
    {
      fptr = fcast + f;
      specificity += fptr->specificity;
    }
  avspecificity = ((double) specificity)/privateParams->numfcasts;

  return self;
}

@end













