// The Santa Fe Stockmarket -- Implementation of class World

// One instance of this object is created to manage the "world" variables
// -- the globally-visible variables that reflect the market itself,
// including the moving averages and the world bits.  Everything is based
// on just two basic variables, price and dividend, which are set only
// by the -setPrice: and -setDividend: messages.
//
// The World also manages the list of bits, translating between bit names
// and bit numbers, and providing descriptions of the bits' functions.
// These are done by class methods because they are needed before the
// instnce is instantiated.

// PUBLIC METHODS
//
// +(const char *)descriptionOfBit: (int)n
//	Supplies a description of the specified bit, taken from the
//	bitnamelist[] table below.  Also works for NULLBIT.
//
// +(const char *)nameOfBit: (int)n
//	Supplies the name of the specified bit, taken from the
//	bitnamelist[] table below.  Also works for NULLBIT.
//
// +(int)bitNumberOf: (const char *)name
//	Supplies the number of a bit given its name.  Unknown names
//	return NULLBIT.  Relatively slow (linear search).
//
// +writeNamesToFile: (FILE *)fp
//	Writes the name and description of all the bits to file "fp".
//
// -setintrate: (double)rate
//     Interest rate set in ASMModelSwarm.
//
// -setExponentialMAs: (BOOL)aBOOL
//      Established in ASMModelSwarm.  Whether to use exponenetially weighted
//      moving averages, or (if NO) simple averages of the last N periods.
//
// -(int)getNumWorldBits
//      Returns numworldbits; used by teh BFagent.
//
// -initWithBaseline: (double)base
//	Initializes the World instance, using initial values based on
//	a price scale of "baseline" for the dividend.  The baseline is 
//      set in ASMModelSwarm.  
//
// -setPrice: (double)p
//	Sets the market price to "p".  All price changes (besides trial
//	prices) should use this method.  Also computes profitperunit and
//	returnratio.
//
// -(double)getPrice
//      Returns the price, used by many.
//
// -(double)getProfitperUnit
//      Returns profitperunit, used by Specialist.
//
// -setDividend: (double)d
//	Sets the dividend to "d".  All dividend changes should use
//	this method.
//
// -(double)getDividend
//      Returns the dividend, used by many.
//
// -(double)getRiskNeutral
//      Returns the risk neutral price.  It is just dividend/intrate.
//
// -updateWorld
//	Updates all the other World variables (moving averages and bits)
//	on the basis of the most recent -setPrice: and -setDividend: messages.
//	Called once per period.  [This could be done automatically as
//	part of -setDividend:].
//
// -getRealWorld: (int *)anArray
//      Returns the real world string of bits.  Used by BFagent to compare
//      their worlds to the real world.
// 
// -(int)pricetrend: (int)nperiods
//	Returns 1 or -1 respectively if the price has risen or fallen
//	monotonically at the last "nperiods".  Otherwise returns 0.  Causes
//	an error if nperiods is too large (see UPDOWNLOOKBACK).
//
// SOME VARIABLES EXPLAINED
// int nmas
//	Number of moving averages available.  This is the dimension of
//	the following moving average arrays.
//
// int matime[]
//	List of moving average periods.
//
// double pmav[]
//	The current moving averages of price.  E.g. for period = 5, this
//	is the average of the price 1, 2, 3, 4 and 5 periods ago.
//
// double oldpmav[]
//	The previous moving averages of price; e.g. for period = 5, this
//	is the average of the price 6, 7, 8, 9, and 10 periods ago.
//
// double dmav[]
//	The current moving averages of dividend.  E.g. for period = 5, this
//	is the average of the dividend 0, 1, 2, 3, and 4 periods ago.
//
// double olddmav[]
//	The previous moving averages of dividend; e.g. for period = 5, this
//	is the average of the dividend 5, 6, 7, 8, and 9 periods ago.


#import "World.h"
#import <random.h>

#include <math.h>
#include <misc.h>

// List of bit names and descriptions
// NB: If you change the order or meaning of bits, also check or change:
// 1. Their computation in -makebitvector in this file.
// 2. The PUPDOWBITNUM value.
// 3. The NAMES documentation file -- do "market -n > NAMES".

//pj:
// These are convenience macros to replace stuff from ASM random with Swarm random stuff

#define drand()    [uniformDblRand getDoubleSample]
#define urand()  [uniformDblRand getDoubleWithMin: -1 withMax: 1]
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1] 

static struct bitnamestruct 
{
  const char *name;
  const char *description;
} bitnamelist[] = {
  
{"on", "dummy bit -- always on"},			// 0
{"off", "dummy bit -- always off"},
{"random", "random on or off"},

{"dup", "dividend went up this period"},		// 3
{"dup1", "dividend went up one period ago"},
{"dup2", "dividend went up two periods ago"},
{"dup3", "dividend went up three periods ago"},
{"dup4", "dividend went up four periods ago"},

{"d5up", "5-period MA of dividend went up"},		// 8
{"d20up", "20-period MA of dividend went up"},
{"d100up", "100-period MA of dividend went up"},
{"d500up", "500-period MA of dividend went up"},

{"d>d5",   "dividend > 5-period MA"},			// 12
{"d>d20",  "dividend > 20-period MA"},
{"d>d100", "dividend > 100-period MA"},
{"d>d500", "dividend > 500-period MA"},

{"d5>d20", "dividend: 5-period MA > 20-period MA"},	// 16
{"d5>d100", "dividend: 5-period MA > 100-period MA"},
{"d5>d500", "dividend: 5-period MA > 500-period MA"},
{"d20>d100", "dividend: 20-period MA > 100-period MA"},
{"d20>d500", "dividend: 20-period MA > 500-period MA"},
{"d100>d500", "dividend: 100-period MA > 500-period MA"},

{"d/md>1/4", "dividend/mean dividend > 1/4"},		// 22
{"d/md>1/2", "dividend/mean dividend > 1/2"},
{"d/md>3/4", "dividend/mean dividend > 3/4"},
{"d/md>7/8", "dividend/mean dividend > 7/8"},
{"d/md>1",   "dividend/mean dividend > 1  "},
{"d/md>9/8", "dividend/mean dividend > 9/8"},
{"d/md>5/4", "dividend/mean dividend > 5/4"},
{"d/md>3/2", "dividend/mean dividend > 3/2"},
{"d/md>2", "dividend/mean dividend > 2"},
{"d/md>4", "dividend/mean dividend > 4"},

{"pr/d>1/4", "price*interest/dividend > 1/4"},		// 32
{"pr/d>1/2", "price*interest/dividend > 1/2"},
{"pr/d>3/4", "price*interest/dividend > 3/4"},
{"pr/d>7/8", "price*interest/dividend > 7/8"},
{"pr/d>1",   "price*interest/dividend > 1"},
{"pr/d>9/8", "price*interest/dividend > 9/8"},
{"pr/d>5/4", "price*interest/dividend > 5/4"},
{"pr/d>3/2", "price*interest/dividend > 3/2"},
{"pr/d>2",   "price*interest/dividend > 2"},
{"pr/d>4",   "price*interest/dividend > 4"},

{"pup", "price went up this period"},			// 42
{"pup1", "price went up one period ago"},
{"pup2", "price went up two periods ago"},
{"pup3", "price went up three periods ago"},
{"pup4", "price went up four periods ago"},

{"p5up", "5-period MA of price went up"},		// 47
{"p20up", "20-period MA of price went up"},
{"p100up", "100-period MA of price went up"},
{"p500up", "500-period MA of price went up"},

{"p>p5", "price > 5-period MA"},			// 51
{"p>p20", "price > 20-period MA"},
{"p>p100", "price > 100-period MA"},
{"p>p500", "price > 500-period MA"},

{"p5>p20", "price: 5-period MA > 20-period MA"},	// 55
{"p5>p100", "price: 5-period MA > 100-period MA"},
{"p5>p500", "price: 5-period MA > 500-period MA"},
{"p20>p100", "price: 20-period MA > 100-period MA"},
{"p20>p500", "price: 20-period MA > 500-period MA"},
{"p100>p500", "price: 100-period MA > 500-period MA"}
};


#define NWORLDBITS	(sizeof(bitnamelist)/sizeof(struct bitnamestruct))
#define NULLBIT         -1

// The index of the "pup" bit
#define PUPDOWNBITNUM	42

// Number of moving averages
#define NMAS	4

// Number of up/down movements to store for price and dividend, including
// the current values.  Used for pup, pup1, ... pup[UPDOWNLOOKBACK-1], and
// similarly for dup[n], and for -pricetrend:.  The argument to -pricetrend:
// must be UPDOWNLOOKBACK or less.
#define	UPDOWNLOOKBACK	5

// Breakpoints for price*interest/dividend and dividend/mean-dividend ratios.
static double ratios[] =
	{0.25, 0.5, 0.75, 0.875, 1.0, 1.125, 1.25, 1.5, 2.0, 4.0};
#define NRATIOS		(sizeof(ratios)/sizeof(double))
#define EQ  0


// ------ Private methods ------
@interface World(Private)
-makebitvector;
@end


@implementation World

+(const char *)descriptionOfBit: (int)n
{
  if (n == NULLBIT)
    return "(Unused bit for spacing)";
  else if (n < 0 || n >= NWORLDBITS)
    return "(Invalid world bit)";
  return bitnamelist[n].description;
}


+(const char *)nameOfBit: (int)n
/*
 * Converts a bit number to a bit name.
 */
{
  if (n == NULLBIT)
    return "null";
  else if (n < 0 || n >= NWORLDBITS)
    return "";
  return bitnamelist[n].name;
}


+(int)bitNumberOf: (const char *)name
/*
 * Converts a bit name to a bit number.  Could be made faster with
 * a hash table etc, but that's not worth it for the intended usage.
 */
{
  int n;
  
  for (n = 0; n < NWORLDBITS; n++)
    if (strcmp(name,bitnamelist[n].name) == EQ)
      break;
  if (n >= NWORLDBITS) n = NULLBIT;

  return n;
}


-setintrate: (double)rate
{
  intrate = rate;
  return self;
}


-setExponentialMAs: (BOOL)aBool
{
  exponentialMAs = aBool;
  return self;
}


-(int)getNumWorldBits
{
  return nworldbits;
}


-initWithBaseline: (double)baseline
/*
 * Initializes arrays etc.  Returns maxhistory.
 */
{
  int i;
  double initprice, initdividend;
  
// Check pup index
  if (strcmp([World nameOfBit:PUPDOWNBITNUM], "pup") != EQ)
    printf("PUPDOWNBITNUM is incorrect");

// Set price and dividend etc from baseline
  dividendscale = baseline;
  initprice = baseline/intrate;
  initdividend = baseline;
  saveddividend = dividend = initdividend;
  [self setDividend:initdividend];
  savedprice = price = initprice;
  [self setPrice:initprice];

// Initialize profit measures
  returnratio = intrate;
  profitperunit = 0.0;

// Initialize miscellaneous variables
  nworldbits = NWORLDBITS;
  nmas = NMAS;

  matime = calloc(NMAS, sizeof(int));
  if(!matime)
    printf("Error allocating memory for matime.");
  matime[0] = 5;
  matime[1] = 20;
  matime[2] = 100;
  matime[3] = 500;
  
  history_top = 0;
  updown_top = 0;
  if (exponentialMAs)
    maxhistory = matime[NMAS-1];
  else
    maxhistory = 2*matime[NMAS-1];

// Allocate arrays
  pupdown = calloc(UPDOWNLOOKBACK,sizeof(int));
  if(!pupdown)
    printf("Error allocating memory for pupdown.");
  
  dupdown = calloc(UPDOWNLOOKBACK,sizeof(int));
  if(!dupdown)
    printf("Error allocating memory for dupdown.");
  
  pricehistory = calloc(maxhistory,sizeof(double));
  if(!pricehistory)
    printf("Error allocating memory for pricehistory.");
  
  divhistory = calloc(maxhistory,sizeof(double));
  if(!divhistory)
    printf("Error allocating memory for divhistory.");
  
  if (exponentialMAs) 
    {
      aweight = calloc(NMAS,sizeof(double));
      if(!aweight)
	printf("Error allocating memory for aweight.");
      bweight = calloc(NMAS,sizeof(double));
      if(!bweight)
	printf("Error allocating memory for bweight.");
    }

  pmav = calloc(NMAS,sizeof(double));
  if(!pmav)
    printf("Error allocating memory for pmav.");

  oldpmav = calloc(NMAS, sizeof(double));
  if(!oldpmav)
    printf("Error allocating memory for oldpmav.");

  dmav = calloc(NMAS, sizeof(double));
  if(!dmav)
    printf("Error allocating memory for dmav.");

  olddmav = calloc(NMAS, sizeof(double));
  if(!olddmav)
    printf("Error allocating memory for olddmav.");
  
  realworld = calloc(NWORLDBITS, sizeof(int)); 
  if(!realworld)
    printf("Error allocating memory for realworld.");

// Initialize arrays
  for (i = 0; i < UPDOWNLOOKBACK; i++) 
    {
    pupdown[i] = 0;
    dupdown[i] = 0;
    }

  for (i = 0; i < maxhistory; i++) 
    {
    pricehistory[i] = initprice;
    divhistory[i] = initdividend;
    }

  for (i = 0; i < NMAS; i++) 
    {
      pmav[i] = initprice;
      oldpmav[i] = initprice;
      dmav[i] = initdividend;
      olddmav[i] = initdividend;
    }

  if (exponentialMAs) 
    {
      for (i = 0; i < NMAS; i++) 
	{
	bweight[i] = -expm1(-1.0/matime[i]);
	aweight[i] = 1.0 - bweight[i];
	}
    }

// Initialize bits
  [self makebitvector];

  return self;
}

/*
 * Sets the current price to p.  Also computes profitperunit and
 * returnration.
 * Checks internally for illegal changes of "price", giving us the
 * effective benefit of encapsulation with the simplicity of use of
 * a global variable.
 */

-setPrice: (double)p

{
  if (price != savedprice)
    printf("Price was changed illegally");

  oldprice = price;
  price = p;

  profitperunit = price - oldprice + dividend;
  if (oldprice <= 0.0)
    returnratio = profitperunit*1000.0;	/* Arbitrarily large */
  else
    returnratio = profitperunit/oldprice;

  savedprice = price;

  return self;
}


-(double)getPrice
{
  return price;
}


-(double)getProfitPerUnit
{
  return profitperunit;
}


-setDividend: (double)d
/*
 * Sets the global value of "dividend".  Checks for illegal changes, like
 * -setPrice:.
 */
{
  if (dividend != saveddividend)
    printf("Dividend was changed illegally.");
  
  olddividend = dividend;
  dividend = d;

  saveddividend = dividend;
  riskNeutral = dividend/intrate;
    
  return self;
}


-(double)getDividend
{
  return dividend;
}


-(double)getRiskNeutral
{
  return riskNeutral;
}



/*
 * Updates the history records, moving averages, and world bits to
 * reflect the current price and dividend.  Note that this is called
 * in each period after a new dividend has been declared but before
 * the bidding and price adjustment.  The bits seen by the agents
 * thus do NOT reflect the trial price.  The "price" here becomes
 * the "oldprice" by the end of the period.
 *
 * The dividend used here is at present the latest value, though it
 * could be argued that it should be the one before, to match price.
 * For the p*r/d bits we do use the old one.
 */
-updateWorld
{
  register int i;
  int r, rago;
  double m;
  int rrago;

/* Update the binary up/down indicators for price and dividend */
  updown_top = (updown_top + 1) % UPDOWNLOOKBACK;
  pupdown[updown_top] = price > oldprice;
  dupdown[updown_top] = dividend > olddividend;

/* Update the price and dividend moving averages */
  history_top = history_top + 1 + maxhistory;
  if (exponentialMAs) 
    {
      for (i = 0; i < NMAS; i++) 
	{
	  r = matime[i];
	  rago = (history_top-r)%maxhistory;
	  pmav[i] = aweight[i]*pmav[i] + bweight[i]*price;
	  oldpmav[i] = aweight[i]*oldpmav[i] + bweight[i]*pricehistory[rago];
	  dmav[i] = aweight[i]*dmav[i] + bweight[i]*dividend;
	  olddmav[i] = aweight[i]*olddmav[i] + bweight[i]*divhistory[rago];
	}
    }
  else 
    {
      for (i = 0; i < NMAS; i++) 
	{
	  r = matime[i];
	  m = 1.0 / (double)r;
	  rago = (history_top-r)%maxhistory;
	  rrago = (history_top-r-r)%maxhistory;
	  pmav[i] += (price - pricehistory[rago]) * m;
	  oldpmav[i] += (pricehistory[rago] - pricehistory[rrago]) * m;
	  dmav[i] += (dividend - divhistory[rago]) * m;
	  olddmav[i] += (divhistory[rago] - divhistory[rrago]) * m;
	}
    }

/* Update the price and dividend histories */
  history_top %= maxhistory;
  pricehistory[history_top] = price;
  divhistory[history_top] = dividend;
    
/* Construct the bit vector for the current state of the world */
  [self makebitvector];

  return self;
}


-makebitvector
/*
 * Set all the world bits, based on the current dividend, price, and
 * their moving averages and histories.
 */
{
  register int i, j, k, temp;
  double multiple;

// Note that "i" increases monotonically throughout this routine, always
// being the next bit to assign.  It is crucial that the order here is the
// same as in bitnamelist[].
  i = 0;
    
  realworld[i++] = 1;
  realworld[i++] = 0;
  realworld[i++] = irand(2);

  /* Dividend went up or down, now and for last few periods */
  temp = updown_top + UPDOWNLOOKBACK;
  for (j = 0; j < UPDOWNLOOKBACK; j++, temp--)
    realworld[i++] = dupdown[temp%UPDOWNLOOKBACK];

  /* Dividend moving averages went up or down */
  for (j = 0; j < NMAS; j++)
    realworld[i++] = dmav[j] > olddmav[j];

  /* Dividend > MA[j] */
  for (j = 0; j < NMAS; j++)
    realworld[i++] = dividend > dmav[j];

  /* Dividend MA[j] > dividend MA[k] */
  for (j = 0; j < NMAS-1; j++)
    for (k = j+1; k < NMAS; k++)
      realworld[i++] = dmav[j] > dmav[k];

  /* Dividend as multiple of meandividend */
  multiple = dividend/dividendscale;
  for (j = 0; j < NRATIOS; j++)
    realworld[i++] = multiple > ratios[j];

  /* Price as multiple of dividend/intrate.  Here we use olddividend to
   * make a more reasonable comparison with the [old] price. */
  multiple = price*intrate/olddividend;
  for (j = 0; j < NRATIOS; j++)
    realworld[i++] = multiple > ratios[j];

  /* Price went up or down, now and for last few periods */
  temp = updown_top + UPDOWNLOOKBACK;
  for (j = 0; j < UPDOWNLOOKBACK; j++, temp--)
    realworld[i++] = pupdown[temp%UPDOWNLOOKBACK];

  /* Price moving averages went up or down */
  for (j = 0; j < NMAS; j++)
    realworld[i++] = pmav[j] > oldpmav[j];

  /* Price > MA[j] */
  for (j = 0; j < NMAS; j++)
    realworld[i++] = price > pmav[j];

  /* Price MA[j] > price MA[k] */
  for (j = 0; j < NMAS-1; j++)
    for (k = j+1; k < NMAS; k++)
      realworld[i++] = pmav[j] > pmav[k];

  // Check
  if (i != NWORLDBITS)
    printf("Bits calculated != bits defined."); 

/* Now convert these bits using the code:
 *  yes -> 1    (01)
 *  no  -> 2    (10)
 * Then we're able to check rule satisfaction with simple ANDs.
 */
  for (i = 0; i < NWORLDBITS; i++)
    realworld[i] = 2 - realworld[i];

  return self;
}


-getRealWorld: (int *)anArray
{
  memcpy(anArray, realworld, NWORLDBITS*sizeof(int)); 
  return self;
}
    

-(int)pricetrend: (int)n;
/*
 * Returns +1, -1, or 0 according to whether the price has risen
 * monotonically, fallen monotonically, or neither, at the last
 * n updates.
 */
{
  int trend, i;

  if (n > UPDOWNLOOKBACK)
    printf("argument %d to -pricetrend: exceeds %d", n, UPDOWNLOOKBACK);
  for (i=0, trend=0; i<n; i++)
    trend |= realworld[i+PUPDOWNBITNUM];
  
  if (trend == 1)
    return 1;
  else if (trend == 2)
    return -1;
  else
    return 0;
}


@end












