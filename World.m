// The Santa Fe Stockmarket -- Implementation of class World

// SOME VARIABLES EXPLAINED
//
// int malength[]
//	List of moving average periods.
//


#import "World.h"
#import "MovingAverage.h"

#import <random.h>

#include <math.h>
#include <misc.h>


//pj:
/*" drand(), urand() and irand(x)  are convenience macros to replace stuff from ASM random with Swarm random stuff "*/

#define drand()    [uniformDblRand getDoubleSample]
#define urand()  [uniformDblRand getDoubleWithMin: -1 withMax: 1]
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1] 

/*" GETMA(x,j) is a macro that checks to see if we want an exponential MA or regular when we retrieve values from MA objects "*/
#define GETMA(x,j) exponentialMAs ? [[x atOffset: j] getEWMA]:[[x atOffset: j] getMA]

/*" bitname struct holds the substantive information about various world indicators
 It is a list of bit names and descriptions
// NB: If you change the order or meaning of bits, also check or change:
// 1. Their computation in -makebitvector in this file.
// 2. The PUPDOWBITNUM value.
// 3. The NAMES documentation file -- do "market -n > NAMES".
 "*/
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


//#define NWORLDBITS	(sizeof(bitnamelist)/sizeof(struct bitnamestruct))
#define NULLBIT         -1

// The index of the "pup" bit
#define PUPDOWNBITNUM	42

// Breakpoints for price*interest/dividend and dividend/mean-dividend ratios.
static double ratios[] =
	{0.25, 0.5, 0.75, 0.875, 1.0, 1.125, 1.25, 1.5, 2.0, 4.0};
#define NRATIOS		(sizeof(ratios)/sizeof(double))
#define EQ  0


// ------ Private methods ------
@interface World(Private)

- makebitvector;

@end


@implementation World

/*" The World is a class that is mainly used to serve the information
  needs of BFagents.  The World takes price data and converts it into
  a number of trends, averages, and so forth.

One instance of this object is created to manage the "world" variables
-- the globally-visible variables that reflect the market itself,
including the moving averages and the world bits.  Everything is based
on just two basic variables, price and dividend, which are set only by
the -setPrice: and -setDividend: messages.

The World also manages the list of bits, translating between bit names
and bit numbers, and providing descriptions of the bits' functions.
These are done by class methods because they are needed before the
instnce is instantiated."*/

/*"	Supplies a description of the specified bit, taken from the
 *	bitnamelist[] table below.  Also works for NULLBIT.
"*/
+ (const char *)descriptionOfBit: (int)n
{
  if (n == NULLBIT)
    return "(Unused bit for spacing)";
  else if (n < 0 || n >= (int)NWORLDBITS)
    return "(Invalid world bit)";
  return bitnamelist[n].description;
}



/*" Supplies the name of the specified bit, taken from the
//	bitnamelist[] table below.  Also works for NULLBIT. Basically,
//	it converts a bit number to a bit name.
"*/
+ (const char *)nameOfBit: (int)n
{
  if (n == NULLBIT)
    return "null";
  else if (n < 0 || n >= (int)NWORLDBITS)
    return "";
  return bitnamelist[n].name;
}


+ (int)bitNumberOf: (const char *)name
/*" Converts a bit name to a bit number. Supplies the number of a bit
 * given its name.  Unknown names return NULLBIT.  Relatively slow
 * (linear search). Could be made faster with a hash table etc, but
 * that's not worth it for the intended usage.  "*/
{
  unsigned n;
  
  for (n = 0; n < NWORLDBITS; n++)
    if (strcmp(name,bitnamelist[n].name) == EQ)
      break;
  if (n >= NWORLDBITS) n = NULLBIT;

  return n;
}


- setintrate: (double)rate
  /*" Interest rate set in ASMModelSwarm."*/
{
  intrate = rate;
  return self;
}


- setExponentialMAs: (BOOL)aBool
  /*" Turns on the use of exponential MAs in calculations.  Can be
    turned on in GUI or ASMModelSwarm.m. If not, simple averages of
    the last N periods."*/
{
  exponentialMAs = aBool;
  return self;
}


- (int)getNumWorldBits
  /*" Returns numworldbits; used by the BFagent."*/
{
  return nworldbits;
}


- initWithBaseline: (double)baseline
/*"
Initializes moving averages, using initial values based on
a price scale of "baseline" for the dividend.  The baseline is 
set in ASMModelSwarm. " */
{
  int i;
  double initprice, initdividend;
  

  priceMA = [Array create: [self getZone] setCount: NMAS];
  oldpriceMA = [Array create: [self getZone] setCount: NMAS];
  divMA = [Array create: [self getZone] setCount: NMAS];
  olddivMA = [Array create: [self getZone] setCount: NMAS];


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
 
  malength[0] = 5;
  malength[1] = 20;
  malength[2] = 100;
  malength[3] = MAXHISTORY;
  
  history_top = 0;
  updown_top = 0;
  
  //divhistory = [[self getZone] alloc: MAXHISTORY*sizeof(double)]; 
  //pricehistory = [[self getZone] alloc: MAXHISTORY*sizeof(double)]; 

  //  realworld = calloc(NWORLDBITS, sizeof(int)); 
  if(!realworld)
    printf("Error allocating memory for realworld.");

// Initialize arrays
  for (i = 0; i < UPDOWNLOOKBACK; i++) 
    {
      pupdown[i] = 0;
      dupdown[i] = 0;
    }

  for (i = 0; i < MAXHISTORY; i++) 
    {
      pricehistory[i] = initprice;
      divhistory[i] = initdividend;
    }

  for (i = 0; i < NMAS; i++) 
    {
      {
	MovingAverage * prMA = [MovingAverage create: [self getZone]];
	[prMA initWidth: malength[i] Value: initprice];
	[priceMA atOffset: i put: prMA];
      }
      {
	MovingAverage * dMA = [MovingAverage create: [self getZone]];
	[dMA initWidth: malength[i] Value: initdividend];
	[divMA atOffset: i put: dMA];
      }
      {
	MovingAverage * oldpMA = [MovingAverage create: [self getZone]];
	[oldpMA initWidth: malength[i] Value: initprice];
	[oldpriceMA atOffset: i put: oldpMA];
      }
      {
	MovingAverage * olddMA = [MovingAverage create: [self getZone]];
	[olddMA initWidth: malength[i] Value: initdividend];
	[olddivMA atOffset: i put: olddMA];
      }
    }

// Initialize bits
  [self makebitvector];

  return self;
}

/*" Sets the market price to "p".  All price changes (besides trial
prices) should use this method.  Also computes profitperunit and
returnratio.  Checks internally for illegal changes of "price", giving us the
effective benefit of encapsulation with the simplicity of use of
a global variable. "*/
- setPrice: (double)p
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

/*"Returns the price, used by many classes."*/
- (double)getPrice
{
  return price;
}

/*"Returns profitperunit, used by Specialist."*/
- (double)getProfitPerUnit
{
  return profitperunit;
}


/*"Sets the global value of "dividend".  All dividend changes should
	use this method.  It checks for illegal changes, as does
	-setPrice:."*/
- setDividend: (double)d
{
  if (dividend != saveddividend)
    printf("Dividend was changed illegally.");
  
  olddividend = dividend;
  dividend = d;

  saveddividend = dividend;
  riskNeutral = dividend/intrate;
    
  return self;
}

/*"Returns the most recent dividend, used by many."*/
- (double)getDividend
{
  return dividend;
}

/*"Returns the risk neutral price.  It is just dividend/intrate."*/
- (double)getRiskNeutral
{
  return riskNeutral;
}



/*" Updates the history records, moving averages, and world bits to
 * reflect the current price and dividend.  Note that this is called
 * in each period after a new dividend has been declared but before
 * the bidding and price adjustment.  The bits seen by the agents thus
 * do NOT reflect the trial price.  The "price" here becomes the
 * "oldprice" by the end of the period. It is called once per period.
 * (This could be done automatically as part of -setDividend:).
 *
 * The dividend used here is at present the latest value, though it
 * could be argued that it should be the one before, to match price.
 * For the p*r/d bits we do use the old one.
 "*/
- updateWorld
{
  register int i;

/* Update the binary up/down indicators for price and dividend */
  updown_top = (updown_top + 1) % UPDOWNLOOKBACK;
  pupdown[updown_top] = price > oldprice;
  dupdown[updown_top] = dividend > olddividend;

/* Update the price and dividend moving averages */
  history_top = history_top + 1 + MAXHISTORY;
  
  //update moving averages of price and dividend

  for (i = 0; i < NMAS; i++) 
    {
      int rago = (history_top-malength[i])%MAXHISTORY;

      [[priceMA atOffset: i] addValue: price];
      [[divMA atOffset: i] addValue: dividend];

      [[oldpriceMA atOffset:i] addValue: pricehistory[rago]];
      [[olddivMA atOffset: i] addValue: divhistory[rago]];
    }


/* Update the price and dividend histories */
  history_top %= MAXHISTORY;
  pricehistory[history_top] = price;
  divhistory[history_top] = dividend;
    
/* Construct the bit vector for the current state of the world */
  [self makebitvector];

  return self;
}


- makebitvector
/*" Set all the world bits, based on the current dividend, price, and
their moving averages and histories.  This moves through the realworld
array, bit by bit, setting the values to 0, 1 or 2, according to the
data that has been observed.  Note the pointer math, such as
realworld[i++], that steps the integer i through the array.  Note that
"i" increases monotonically throughout this routine, always being the
next bit to assign.  It is crucial that the order here is the same as
in bitnamelist[]. "*/
{
  register int i, j, k, temp;
  double multiple;


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
    realworld[i++] = (GETMA(divMA,j)) > (GETMA(olddivMA,j));
  

  /* Dividend > MA[j] */
  for (j = 0; j < NMAS; j++)
    realworld[i++] = dividend > ( GETMA(divMA,j));

  /* Dividend MA[j] > dividend MA[k] */
  for (j = 0; j < NMAS-1; j++)
    for (k = j+1; k < NMAS; k++)
      realworld[i++] = (GETMA(divMA,j)) > (GETMA(divMA,k));

  /* Dividend as multiple of meandividend */
  multiple = dividend/dividendscale;
  for (j = 0; j < (int)NRATIOS; j++)
    realworld[i++] = multiple > ratios[j];

  /* Price as multiple of dividend/intrate.  Here we use olddividend to
   * make a more reasonable comparison with the [old] price. */
  multiple = price*intrate/olddividend;
  for (j = 0; j < (int)NRATIOS; j++)
    realworld[i++] = multiple > ratios[j];

  /* Price went up or down, now and for last few periods */
  temp = updown_top + UPDOWNLOOKBACK;
  for (j = 0; j < UPDOWNLOOKBACK; j++, temp--)
    realworld[i++] = pupdown[temp%UPDOWNLOOKBACK];

  /* Price moving averages went up or down */
  for (j = 0; j < NMAS; j++)
    realworld[i++] = (GETMA(priceMA,j)) > (GETMA(oldpriceMA,j));
    //realworld[i++] =pmav[j] > oldpmav[j];

  /* Price > MA[j] */
  for (j = 0; j < NMAS; j++)
     realworld[i++] = price > (GETMA(priceMA,j));

  /* Price MA[j] > price MA[k] */
  for (j = 0; j < NMAS-1; j++)
    for (k = j+1; k < NMAS; k++)
      realworld[i++] = (GETMA(priceMA,j)) > (GETMA(priceMA,k));
  
  // Check
  if (i != NWORLDBITS)
    printf("Bits calculated != bits defined."); 

/* Now convert these bits using the code:
 *  yes -> 1    (01)
 *  no  -> 2    (10)
 * Then we're able to check rule satisfaction with simple ANDs.
 */
  for (i = 0; i < (int)NWORLDBITS; i++)
    realworld[i] = 2 - realworld[i];

  return self;
}

/*" Returns the real world array of bits.  Used by BFagent to compare
  their worlds to the real world."*/
- getRealWorld: (int *)anArray
{
  memcpy(anArray, realworld, NWORLDBITS*sizeof(int)); 
  return self;
}


- (int)pricetrend: (int)n;
/*"
 * Returns +1, -1, or 0 according to whether the price has risen
 * monotonically, fallen monotonically, or neither, at the last
 * n updates. Causes
 *	an error if nperiods is too large (see UPDOWNLOOKBACK)."
 "*/
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












