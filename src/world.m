// The Santa Fe Stock Market -- Implementation of World class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// One instance of this object is created to manage the "world" variables
// -- the globally-visible variables that reflect the market itself,
// including the moving averages and the world bits.  Everything is based
// on just two basic variables, price and dividend, which are set only
// by the -setPrice: and -setDividend: messages.
//
// The World also manages the list of bits, translating between bit names
// and bit numbers, and providing descriptions of the bits' functions.
// These are done by class methods because they are needed before the
// instance is instantiated.

// PUBLIC METHODS
//
// + (const char *)descriptionOfBit:(int)n
//	Supplies a description of the specified bit, taken from the
//	bitnamelist[] table below.  Also works for NULLBIT.
//
// + (const char *)nameOfBit:(int)n
//	Supplies the name of the specified bit, taken from the
//	bitnamelist[] table below.  Also works for NULLBIT.
//
// + (int)bitNumberOf:(const char *)name
//	Supplies the number of a bit given its name.  Unknown names
//	return NULLBIT.  Relatively slow (linear search).
//
// + writeNamesToFile:(FILE *)fp
//	Writes the name and description of all the bits to file "fp".
//
// - (int)initWithBaseline:(double)baseline
//	Initializes the World instance, using initial values based on
//	a price scale of "baseline" for the dividend.  Returns maxhistory,
//	the look-back length of the internal price and dividend records.
//
// - setPrice:(double)p
//	Sets the market price to "p".  All price changes (besides trial
//	prices) should use this method.  Updates the price history, price
//	moving averages, price up/down records, volatility measures,
//	oldprice, profitperunit, and returnratio.
//
// - setDividend:(double)d
//	Sets the dividend to "d".  All dividend changes should use
//	this method.  Updates the dividend history, dividend moving
//	averages, dividend up/down records, and oldprice.
//
// - makeBitVector
//	Creates the vector of "world" bits on the basis of the most recent
//	-setPrice: and -setDividend: messages.	Called once per period.
//
// - (int)pricetrend:(int)nperiods
//	Returns 1 or -1 respectively if the price has risen or fallen
//	monotonically at the last "nperiods".  Otherwise returns 0.  Causes
//	an error if nperiods is too large (see UPDOWNLOOKBACK).
//
// - check
//	Checks that the moving averages and some internal history variables
//	are self-consistent.  For debugging.
//
// GLOBAL VARIABLES NEEDED
//
// double intrate
//	Interest rate.
//
// BOOL exponentialMAs
//	Whether to use exponenetially weighted moving averages, or (if NO)
//	simple averages of the last N periods.
//
// GLOBAL VARIABLES SUPPLIED
//
// double price, oldprice
//	The current and previous price
//
// double dividend, olddividend
//	The current and previous dividend
//
// double profitperunit
//	The profit gained per unit of previous stockholding, equal to
//	price + dividend - oldprice.
//
// double returnratio
//	The return on investment, profitperunit/oldprice.
//
// double vol
//	A measure of volatility: (price - oldprice)^2
//
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
//
// double volt[]
//	A volatility measure looking back for each of the moving average
//      periods.  E.g. for period = 5; [price(t) - price(t-5)]^2.
//
// int nworldbits
//	Number of world bits.
//
// int realworld[]
//	The world bits, with value 2 for off and 1 for on.

// IMPORTS
#include "global.h"
#include "world.h"
#include <math.h>
#include <string.h>
#include "random.h"
#include "error.h"
#include "util.h"

// List of bit names and descriptions
// NB: If you change the order or meaning of bits, also check or change:
// 1. Their computation in -makeBitVector in this file.
// 2. The PUPDOWBITNUM value.
// 3. The "names" documentation file -- do "market -n > names".

static struct bitnamestruct {
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

// ------ Global variables defined in this file -------
// These may be read anywhere, but should only be changed by World.
// They could be made into instance variables with accessor methods, but
// are made global for efficiency.
double price;
double oldprice;
double dividend;
double olddividend;
double profitperunit;
double returnratio;
double vol;
int nmas = NMAS;
int matime[NMAS] = {5, 20, 100, 500};	// Moving average periods
double pmav[NMAS];
double oldpmav[NMAS];
double dmav[NMAS];
double olddmav[NMAS];
double volt[NMAS];
int nworldbits;
int realworld[NWORLDBITS];


@implementation World


/*------------------------------------------------------*/
/*	+descriptionOfBit:				*/
/*------------------------------------------------------*/
+ (const char *)descriptionOfBit:(int)n
{
    if (n == NULLBIT)
	return "(Unused bit for spacing)";
    else if (n < 0 || n >= NWORLDBITS)
	return "(Invalid world bit)";
    return bitnamelist[n].description;
}


/*------------------------------------------------------*/
/*	+nameOfBit:					*/
/*------------------------------------------------------*/
+ (const char *)nameOfBit:(int)n
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


/*------------------------------------------------------*/
/*	+bitNumberOf:					*/
/*------------------------------------------------------*/
+ (int)bitNumberOf:(const char *)name
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


/*------------------------------------------------------*/
/*	+writeNamesToFile:				*/
/*------------------------------------------------------*/
+ writeNamesToFile:(FILE *)fp
{
    int i;

    for (i=0; i<NWORLDBITS; i++)
	showstrng(fp, bitnamelist[i].description, bitnamelist[i].name);
    return self;
}


/*------------------------------------------------------*/
/*	-initWithBaseline:				*/
/*------------------------------------------------------*/
- (int)initWithBaseline:(double)baseline
/*
 * Initializes arrays etc.  Returns maxhistory.
 */
{
    int i;
    double initprice, initdividend;

// Check pup index
    if (strcmp([World nameOfBit:PUPDOWNBITNUM], "pup") != EQ)
	[self error:"PUPDOWNBITNUM is incorrect"];

// Set price and dividend etc from baseline
    dividendscale = baseline;
    initprice = baseline/intrate;
    initdividend = baseline;
    saveddividend = olddividend = dividend = initdividend;
    savedprice = oldprice = price = initprice;

// Initialize profit measures, etc
    returnratio = intrate;
    profitperunit = 0.0;
    vol = 0.0;

// Initialize miscellaneous variables
    nworldbits = NWORLDBITS;
    nmas = NMAS;
    phistory_top = 0;
    dhistory_top = 0;
    pupdown_top = 0;
    dupdown_top = 0;
    if (exponentialMAs)
	maxhistory = matime[NMAS-1];
    else
	maxhistory = 2*matime[NMAS-1];

// Allocate arrays
    pupdown = (int *) getmem(sizeof(int)*UPDOWNLOOKBACK);
    dupdown = (int *) getmem(sizeof(int)*UPDOWNLOOKBACK);
    pricehistory = (double *) getmem(sizeof(double)*maxhistory);
    divhistory = (double *) getmem(sizeof(double)*maxhistory);
    if (exponentialMAs) {
	aweight = (double *)getmem(sizeof(double)*NMAS);
	bweight = (double *)getmem(sizeof(double)*NMAS);
    }

// Initialize arrays
    for (i = 0; i < UPDOWNLOOKBACK; i++) {
	pupdown[i] = 0;
	dupdown[i] = 0;
    }

    for (i = 0; i < maxhistory; i++) {
	pricehistory[i] = initprice;
	divhistory[i] = initdividend;
    }

    for (i = 0; i < NMAS; i++) {
	pmav[i] = initprice;
	oldpmav[i] = initprice;
	dmav[i] = initdividend;
	olddmav[i] = initdividend;
        volt[i] = 0.0;
    }

    if (exponentialMAs) {
	for (i = 0; i < NMAS; i++) {
	    bweight[i] = -expm1(-1.0/matime[i]);
	    aweight[i] = 1.0 - bweight[i];
	}
    }

// Create bit vector
    [self makeBitVector];

    return maxhistory;
}


/*------------------------------------------------------*/
/*	-setPrice:					*/
/*------------------------------------------------------*/
- setPrice:(double)p
/*
 * Sets the current price to p, and updates the price history, price
 * up/down records, price moving averages, volatilities, profitperunit,
 * returnratio, and oldprice.
 *
 * Checks internally for illegal changes of "price", giving us the
 * effective benefit of encapsulation with the simplicity of use of
 * a global variable.
 */
{
    int i, r, rago, rrago;
    double m, deltap;

    if (price != savedprice)
	message("*** price was changed illegally");

    oldprice = price;
    price = p;
    savedprice = price;

/* Update profitperunit, returnratio, and volatility */
    profitperunit = price - oldprice + dividend;
    if (oldprice <= 0.0)
	returnratio = profitperunit*1000.0;	/* Arbitrarily large */
    else
	returnratio = profitperunit/oldprice;
    vol = price - oldprice;
    vol *= vol;

/* Update the binary up/down indicator for price */
    pupdown_top = (pupdown_top + 1) % UPDOWNLOOKBACK;
    pupdown[pupdown_top] = price > oldprice;

/* Update the price moving averages and n-back volatilities */
    phistory_top = phistory_top + 1 + maxhistory;
    if (exponentialMAs) {
	for (i = 0; i < NMAS; i++) {
	    r = matime[i];
	    rago = (phistory_top-r)%maxhistory;
	    pmav[i] = aweight[i]*pmav[i] + bweight[i]*price;
	    oldpmav[i] = aweight[i]*oldpmav[i] + bweight[i]*pricehistory[rago];
            deltap = price - pricehistory[rago];
            volt[i] = deltap*deltap;
	}
    }
    else {
	for (i = 0; i < NMAS; i++) {
	    r = matime[i];
	    m = 1.0 / (double)r;
	    rago = (phistory_top-r)%maxhistory;
	    rrago = (phistory_top-r-r)%maxhistory;
            deltap = price - pricehistory[rago];
	    pmav[i] += deltap * m;
	    oldpmav[i] += (pricehistory[rago] - pricehistory[rrago]) * m;
            volt[i] = deltap*deltap;
	}
    }

/* Update the price history */
    phistory_top %= maxhistory;
    pricehistory[phistory_top] = price;

    return self;
}


/*------------------------------------------------------*/
/*	-setDividend:					*/
/*------------------------------------------------------*/
- setDividend:(double)d
/*
 * Sets the global value of "dividend", and updates the dividend
 * history, dividend up/down records, dividend moving averages, and
 * olddividend.
 *
 * Checks internally for illegal changes of "dividend", giving us the
 * effective benefit of encapsulation with the simplicity of use of
 * a global variable.
 */
{
    int i, r, rago, rrago;
    double m;

    if (dividend != saveddividend)
	message("*** dividend was changed illegally");

    olddividend = dividend;
    dividend = d;
    saveddividend = dividend;

/* Update the binary up/down indicator for dividend */
    dupdown_top = (dupdown_top + 1) % UPDOWNLOOKBACK;
    dupdown[dupdown_top] = dividend > olddividend;

/* Update the dividend moving averages */
    dhistory_top = dhistory_top + 1 + maxhistory;
    if (exponentialMAs) {
	for (i = 0; i < NMAS; i++) {
	    r = matime[i];
	    rago = (dhistory_top-r)%maxhistory;
	    dmav[i] = aweight[i]*dmav[i] + bweight[i]*dividend;
	    olddmav[i] = aweight[i]*olddmav[i] + bweight[i]*divhistory[rago];
	}
    }
    else {
	for (i = 0; i < NMAS; i++) {
	    r = matime[i];
	    m = 1.0 / (double)r;
	    rago = (dhistory_top-r)%maxhistory;
	    rrago = (dhistory_top-r-r)%maxhistory;
	    dmav[i] += (dividend - divhistory[rago]) * m;
	    olddmav[i] += (divhistory[rago] - divhistory[rrago]) * m;
	}
    }

/* Update the dividend history */
    dhistory_top %= maxhistory;
    divhistory[dhistory_top] = dividend;

    return self;
}


/*------------------------------------------------------*/
/*	-makeBitVector					*/
/*------------------------------------------------------*/
- makeBitVector
/*
 * Set all the world bits, based on the current dividend, price, and
 * their moving averages and histories.
 *
 * Note that this is called after setDividend: but before the trading,
 * and thus before setPrice:, in each period.  The prices implied in
 * arrays like pupdown[] are therefore from the previous period, while the
 * dividends are for the current period.
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
    realworld[i++] = irand(rng,2);

    /* Dividend went up or down, now and for last few periods */
    temp = dupdown_top + UPDOWNLOOKBACK;
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
    temp = pupdown_top + UPDOWNLOOKBACK;
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
	[self error:"Bits calculated != bits defined"];

/* Now convert these bits using the code:
 *  yes -> 1    (01)
 *  no  -> 2    (10)
 * Then we're able to check rule satisfaction with simple ANDs.
 */
    for (i = 0; i < NWORLDBITS; i++)
	realworld[i] = 2 - realworld[i];

    return self;
}


/*------------------------------------------------------*/
/*	-pricetrend:					*/
/*------------------------------------------------------*/
- (int)pricetrend:(int)n;
/*
 * Returns +1, -1, or 0 according to whether the price has risen
 * monotonically, fallen monotonically, or neither, at the last
 * n updates.
 */
{
    int trend, i;

    if (n > UPDOWNLOOKBACK)
	[self error:"argument %d to -pricetrend: exceeds %d", n,
							UPDOWNLOOKBACK];
    for (i=0, trend=0; i<n; i++)
	trend |= realworld[i+PUPDOWNBITNUM];

    if (trend == 1)
	return 1;
    else if (trend == 2)
	return -1;
    else
	return 0;
}


/*------------------------------------------------------*/
/*	-check						*/
/*------------------------------------------------------*/
- check
/*
 * Checks that moving averages and up/down records are correct.
 */
{
    register int i, j;
    int t1, t2;
    int m, k;
    double psum, dsum, oldpsum, olddsum;

    if (pricehistory[phistory_top] != price)
	message("*w: price %f != %f", pricehistory[phistory_top], price);
    if (divhistory[dhistory_top] != dividend)
	message("*w: dividend %f != %f", divhistory[dhistory_top], dividend);

    for (i=0; i<UPDOWNLOOKBACK; i++) {
	j = (pupdown_top-i+UPDOWNLOOKBACK)%UPDOWNLOOKBACK;
	t1 = (phistory_top-i+maxhistory)%maxhistory;
	t2 = (phistory_top-i+maxhistory-1)%maxhistory;
	if (pupdown[j] != (pricehistory[t1] > pricehistory[t2]))
	    message("*w: pupdown[%d]=%d, t1/2=%d/%d, price1/2=%f/%f",
		j, pupdown[j], t1, t2, pricehistory[t1], pricehistory[t2]);
    }

    for (i=0; i<UPDOWNLOOKBACK; i++) {
	j = (dupdown_top-i+UPDOWNLOOKBACK)%UPDOWNLOOKBACK;
	t1 = (dhistory_top-i+maxhistory)%maxhistory;
	t2 = (dhistory_top-i+maxhistory-1)%maxhistory;
	if (dupdown[j] != (divhistory[t1] > divhistory[t2]))
	    message("*w: dupdown[%d]=%d, t1/2=%d/%d, dividend1/2=%f/%f",
		j, dupdown[j], t1, t2, divhistory[t1], divhistory[t2]);
    }

    if (! exponentialMAs) {
	for (i=0; i<NMAS; i++) {
	    m = matime[i];
	    psum = 0.0;
	    oldpsum = 0.0;
	    for (j=0; j<m; j++) {
		k = (phistory_top-j+maxhistory)%maxhistory;
		psum += pricehistory[k];
		k = (phistory_top-j-m+maxhistory)%maxhistory;
		oldpsum += pricehistory[k];
	    }
	    if (fabs(psum/m-pmav[i]) > 0.0001*fabs(pmav[i]))
		message("*w: pmav[%d] %g %g", i,psum/m,pmav[i]);
	    if (fabs(oldpsum/m-oldpmav[i]) > 0.0001*fabs(oldpmav[i]))
		message("*w: oldpmav[%d] %g %g", i,oldpsum/m,oldpmav[i]);
	}
	for (i=0; i<NMAS; i++) {
	    m = matime[i];
	    dsum = 0.0;
	    olddsum = 0.0;
	    for (j=0; j<m; j++) {
		k = (dhistory_top-j+maxhistory)%maxhistory;
		dsum += divhistory[k];
		k = (dhistory_top-j-m+maxhistory)%maxhistory;
		olddsum += divhistory[k];
	    }
	    if (fabs(dsum/m-dmav[i]) > 0.0001*fabs(dmav[i]))
		message("*w: dmav[%d] %g %g", i,dsum/m,dmav[i]);
	    if (fabs(olddsum/m-olddmav[i]) > 0.0001*fabs(olddmav[i]))
		message("*w: olddmav[%d] %g %g", i,olddsum/m,olddmav[i]);
	}
    }

    message("#w: p=%.4f d=%.4f", price, dividend);

    return self;
}

@end
