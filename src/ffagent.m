// The Santa Fe Stock Market -- Implementation of FFagent class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// Each FF agent is endowed with one of more "forecasters" that are invoked
// at each period t to make predictions of p(t+1)+d(t+1) given a trial
// value ("trialprice") for p(t) and all previous price and dividend
// information (including d(t)).  These forecasters are updated in the
// next period, after p(t+1)+d(t+1) is known, giving a moving average of
// their squared prediction error ("variance").  This variance is transformed
// into a "strength"; high variance implies low strength and vice-versa.  At
// each period a particular forecaster is chosen, using either:
//   1. probability proportional to strength; or
//   2. highest srtength.
// The chosen forecaster then determines the desired holding,
// and hence the demand, via a standard risk-aversion calculation.
//
// The forecasters used by a particular agent are chosen randomly from a
// fixed set of forecating methods.  Typically each agent has a different
// subset.  This is analogous to Arthur's El Farol (Bar) problem.
//
// These agents do not work very well except in a mixed market of other
// agents.  Their risk aversion makes them all want to be out of the
// market at first, and they need other agents to sell to.  With the
// "slope" specialist they often lead to wild price fluctuations -- once
// any large fluctuation occurs their predictors become terrible, and
// drive further wild behavior.  The fcastmin/fcastmax clipping helps
// this only partially, since when the forecast (or demand) gets pinned
// against a constraint the "slope" d(demand)/d(price) becomes 0 and the
// specialist has a hard time choosing a new price.  This is probably
// fairly easy to fix, but the project's attention turned instead to the
// BFagents where the bit conditions and simpler predictors lead to much
// stabler behavior.

// PUBLIC METHODS
// + initClass:(int)theclass
// + createType:(int)thetype from:(const char *)filename
// + writeParamsToFile:(FILE *)fp forType:(int)thetype
// + (int)nrulesForType:(int)thetype
// - initAgent:(int)thetag type:(int)thetype
// - prepareForTrading
// - (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
// - updatePerformance
// - free
// - copy
//	See Agent.m.
//
// + (const char *)descriptionOfMethod:(int)n
//	Returns a description of forecasting method n, for use by the
//	front end.
//
// - makeForecast:(Rule)rptr forPrice:(double)trialprice
//	Makes one of the forecasts, setting rptr->forecast and rptr->dfdp.
//	The method used is given by method[rptr-rule].
//
// IMPLEMENTATION NOTE
//	This implementation is rather inefficient because the forecasts
//	are calculated separately for each agent.  We probably ought to
//	compute the forecast for all forecasting methods for each new
//	period or trialprice, as a class method for each FF type, and then
//	just look them up.  Even the variances for each method are identical
//	in all agents within an FF type, but are calculated separately!

// IMPORTS
#include  "global.h"
#include  "ffagent.h"
#include  <stdlib.h>
#include  <math.h>
#include  <string.h>
#include  "random.h"
#include  "error.h"
#include  "util.h"

// Typedefs for agents, parameters, and rules
typedef FFagent *Agptr;
typedef struct FFparams *Params;
typedef struct FF_rule RuleStruct;
typedef struct FF_rule *Rule;

// Definitions and key table for selection methods
#define SELECT_BEST	0
#define SELECT_ROULETTE	1
static struct keytable selectionkeys[] = {
    {"best", SELECT_BEST},
    {"roulette", SELECT_ROULETTE},
    {NULL, -1}
};

// Maximum strength -- sets betafact to avoid overflow in exp()
#define MAXSTRENGTH	1e30

// Local variables
static int class;
static double betafact;


@implementation FFagent

+ initClass:(int)theclass;
{
// Save our class
    class = theclass;

// Compute constants
    betafact = 1.0/log(MAXSTRENGTH);

    return self;
}


+ createType:(int)thetype from:(const char *)filename
{
    Params params;

// Allocate space for our parameters, store in paramslist
    params = (Params)getmem(sizeof(struct FFparams));
    paramslist[thetype] = (void *)params;

// Set predefined entries
    params->class = class;	// not used, but useful in debugger
    params->type = thetype;	// not used, but useful in debugger

// Open parameter file
    (void) openInputFile(filename, "FF agent parameters");

// Read in the parameters
    params->numrules = readInt("numfcasts",1,NMETHODS);
    params->tauv = readDouble("tauv",1.0,100000.0);
    params->lambda = readDouble("lambda",0.0,100000.0);
    params->maxbid = readDouble("maxbid",0.0,1000.0);
    params->fcastmin = readDouble("fcastmin",0.0,1000.0);
    params->fcastmax = readDouble("fcastmax",0.0,100000.0);
    params->selectionmethod = readKeyword("selectionmethod",selectionkeys);
    params->beta = readDouble("beta",0.0,10.0);
    params->maxdev = readDouble("maxdev",0.001,1e6);
    params->a1 = readDouble("a1",0.0,100.0);
    params->a2 = readDouble("a2",-1000.0, 1000.0);

// Quit if there were errors
    abandonIfError("[Forecaster +createType:from:]");

// Compute derived parameters
    params->tauvnew = -expm1(-1.0/params->tauv);

    return self;
}


+ writeParamsToFile:(FILE *)fp forType:(int)thetype
{
    Params params = (Params)paramslist[thetype];

    showint(fp, "numfcasts", params->numrules);
    showdble(fp,"tauv", params->tauv);
    showdble(fp,"lambda", params->lambda);
    showdble(fp,"maxbid", params->maxbid);
    showdble(fp,"fcastmin", params->fcastmin);
    showdble(fp,"fcastmax", params->fcastmax);
    showstrng(fp, "selectionmethod", findkeyword(params->selectionmethod,
				    selectionkeys, "selection method"));
    showdble(fp,"beta", params->beta);
    showdble(fp,"maxdev",params->maxdev);
    showdble(fp,"a1",params->a1);
    showdble(fp,"a2",params->a2);

    return self;
}


+ (int)nrulesForType:(int)thetype
{
    return ((Params)paramslist[thetype])->numrules;
}


- initAgent:(int)thetag type:(int)thetype;
/*
 * Initializes an FFagent.
 */
{
    int i, r, m, j;
    int list[NMETHODS];
    double maxdevsq, initstrength;

// Initialize generic variables common to all agents
    [super initAgent:thetag type:thetype];

// Initialize our instance variables
    p = paramslist[thetype];
    for (i=0; i<NMETHODS; i++) {
	usedby[i] = -1;
	list[i] = i;
    }

// Allocate memory for forecasters initialize them
    rule = (Rule) getmem(sizeof(RuleStruct)*p->numrules);
    rptrtop = rule + p->numrules;
    maxdevsq = p->maxdev*p->maxdev;
    initstrength = exp(p->beta/(maxdevsq + betafact*p->beta));
    for (r = 0, m = NMETHODS; r < p->numrules; r++) {
	rule[r].oldforecast = rule[r].forecast = price + dividend;
	rule[r].variance = maxdevsq ;	// large initial value
	rule[r].strength = initstrength;
	rule[r].count = 0;
    // Choose a random prediction method for each, without replacement
	i = irand(rng,m);
	j = list[i];
	usedby[j] = r;
	method[r] = j;
	list[i] = list[--m];
    }

    return self;
}


- free
{
    free(rule);
    return [super free];
}


- copy
{
    Agptr new;

// Allocate and copy instance variables
    new = (Agptr)[super copy];

// Allocate and copy rules
    new->rule = (Rule) getmem(sizeof(RuleStruct)*p->numrules);
    (void) memcpy(new->rule, rule, sizeof(RuleStruct)*p->numrules);
    new->rptrtop = new->rule + p->numrules;
    return new;
}


- prepareForTrading
/*
 * Selects a forecaster to use for this period, either choosing the
 * best or using a roulette wheel.
 */
{
    Rule rptr;
    double sum, x, best;

// Accumulate the strengths, and find the best
    sum = 0.0;
    best = -1.0;
    for (rptr=rule; rptr < rptrtop; rptr++) {
	rptr->cumstrength = sum += rptr->strength;
	if (rptr->strength > best) {
	    best = rptr->strength;
	    chosen = rptr;
	}
    }

// Choose a forecast using a weighted roulette wheel if desired
    if (p->selectionmethod == SELECT_ROULETTE) {
	if (p->numrules > 1) {
	    x = drand(rng) * sum;
	    for (rptr=rule; rptr < rptrtop; rptr++)
		if (rptr->cumstrength > x) break;
	    chosen = rptr;
	}
	else
	    chosen = rule;	// only one -- choose it
    }
    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
/*
 * Returns the agent's requested bid (if >0) or offer (if <0).
 */
{
    double divisor;

// Ask each forecasters to give its forecast and dfdp=d(forecast)/d(price).
    [self makeForecast:chosen forPrice:trialprice];

// Calculate demand from forecast and risk aversion, and also set
// slope = d(demand)/d(price)
    divisor = p->lambda*chosen->variance;
    demand = -((trialprice*intratep1 - chosen->forecast)/divisor + position);
    *slope = (chosen->dfdp - intratep1)/divisor;

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

// Return the demand and slope after imposing budget constraints
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
    double ftarget, a, b, deviation, maxdevsq, scaledbeta;

// The first predictions are at t=1, updated here at t=2.
    if (t <= 1)
	return self;

// Precompute/extract things for speed
    a = p->tauvnew;
    b = 1.0 - a;
    maxdevsq = p->maxdev*p->maxdev;
    scaledbeta = betafact*p->beta;

// Update the usage count
    ++chosen->count;

// Compute the errors in the previous period's forecasts and use them to
// update the variances and strengths.
    ftarget = price + dividend;
    for (rptr=rule; rptr < rptrtop; rptr++) {
	deviation = ftarget - rptr->oldforecast;
	deviation = deviation*deviation;
	if (deviation > maxdevsq) deviation = maxdevsq;
	rptr->variance = b*rptr->variance + a*deviation;
	rptr->strength = exp(p->beta/(rptr->variance+scaledbeta));
    }

// Compute all this agents' forecasts for the current period, for use in
// the next update and possibly for frontend display.
    for (rptr=rule; rptr < rptrtop; rptr++) {
	[self makeForecast:rptr forPrice:price];
	rptr->oldforecast = rptr->forecast;
    }

    return self;
}


// Table of method descriptions
static const char *methodDescription[NMETHODS] = {
    "Linear function of dividend",
    "Martingale for price and dividend",
    "Martingale for price, linear extrapolation for dividend",
    "Linear extrapolation for price, martingale for dividend",
    "Linear extrapolation of both price and dividend",
    "Quadratric extrapolation for price, martingale for dividend",
    "Quadratric extrapolation for price, linear extrapolation for dividend",
    "Linear extrapolation for dividend, linear function of result"
};


+ (const char *)descriptionOfMethod:(int)n
{
    return methodDescription[n];
}


- makeForecast:(Rule)rptr forPrice:(double)trialprice
/*
 * Tries to predict forecast = E[p(t+1)+d(t+1)] given:
 *
 *	trialprice = p(t)  [tentative, may iterate]
 *	price = p(t-1)
 *	oldprice = p(t-2),
 *	dividend = d(t)
 *	olddividend = d(t-1)
 *
 * Also gives dfdp = d(forecast)/d(trialprice).
 *
 * Note that these forecasts are all reasonable in a stable market that's
 * close to fundamentals, but some behave very badly when the price is
 * fluctuating widely.  This makes these FF agents destabilizing, especially
 * when the "slope" specialist is used.
 */
{
    double priceforecast, dividendforecast;

    switch (method[rptr-rule]) {
    case 0:
    // Linear function of dividend
	rptr->forecast = p->a1*dividend + p->a2;
	rptr->dfdp = 0.0;
	break;
    case 1:
    // Martingale for p and d
	rptr->forecast = dividend + trialprice;
	rptr->dfdp = 1.0;
	break;
    case 2:
    // Martingale for p, linear extrapolation for d
	dividendforecast = (dividend - olddividend) +  dividend;
	rptr->forecast = trialprice + dividendforecast;
	rptr->dfdp = 1.0;
	break;
    case 3:
    // Linear extrapolation for p, martingale for d
	priceforecast =  (trialprice - price) + trialprice;
	rptr->forecast = priceforecast + dividend;
	rptr->dfdp = 2.0;
	break;
    case 4:
    // Linear extrapolation of both p and d
	priceforecast =  (trialprice - price) + trialprice;
	dividendforecast = (dividend - olddividend) +  dividend;
	rptr->forecast = priceforecast + dividendforecast;
	rptr->dfdp = 2.0;
	break;
    case 5:
    // Quadratric extrapolation for p, martingale for d
	priceforecast = (trialprice - price)*3.0 + oldprice;
	rptr->forecast = priceforecast + dividend;
	rptr->dfdp = 3.0;
	break;
    case 6:
    // Quadratric extrapolation for p, linear extrapolation for d
	priceforecast = (trialprice - price)*3.0 + oldprice;
	dividendforecast = (dividend - olddividend) +  dividend;
	rptr->forecast = priceforecast + dividendforecast;
	rptr->dfdp = 3.0;
	break;
    case 7:
    // Linear extrapolation for d, linear function of result
	dividendforecast = (dividend - olddividend) +  dividend;
	rptr->forecast = p->a1*dividendforecast + p->a2;
	rptr->dfdp = 0.0;
	break;
    }

// Clip range of forecast to assure sanity
    if (rptr->forecast < p->fcastmin) {
	rptr->forecast = p->fcastmin;
	rptr->dfdp = 0.0;
    }
    else if (rptr->forecast > p->fcastmax) {
	rptr->forecast = p->fcastmax;
	rptr->dfdp = 0.0;
    }
    return self;
}

@end
