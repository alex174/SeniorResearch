// Code for Forecaster abstract superclass of agents

#import "global.h"
#import "Forecaster.h"
#import <stdlib.h>
#import <math.h>
#import <string.h>
#import "random.h"
#import "error.h"
#import "util.h"

// Local variables
static int class;
static struct Fparams *params;


@implementation Forecaster

+ initClass:(int)myclass
{
    class = myclass;	// save our class
    return self;
}


+ (void *)createType:(int)mytype :(const char *)filename
{
    
// Allocate space for our parameters
    params = (struct Fparams *)getmem(sizeof(struct Fparams));
    params->class = class;	// not used, but useful in debugger
    params->type = mytype;	// not used, but useful in debugger
   
/* Read in parameters from parameter file for Forecasting agents */
    (void) OpenInputFile(filename, "forecast parameters");
    params->defaultnumfcasts = ReadInt("numfcasts",1,1000);
    params->tauv = ReadDouble("tauv",1.0,100000.0);
    params->defaultlambda = ReadDouble("lambda",0.0,100000.0);
    params->maxbid = ReadDouble("maxbid",0.0,1000.0);
    params->beta = ReadDouble("beta",0.0,10.0);
    abandonIfError("[Forecaster +createType::]");

/* Compute derived parameters */
    params->tauvnew = -expm1(-1.0/params->tauv);
    params->tauvdecay = 1.0 - params->tauvnew;

    return  (void *)params;
}


+ writeParams:(void *)theParams ToFile:(FILE *)fp;
{
    struct Fparams *parm = (struct Fparams *)theParams;

    showint(fp, "defaultnumfcasts", parm->defaultnumfcasts);
    showdble(fp,"tauv", parm->tauv);
    showdble(fp,"defaultlambda", parm->defaultlambda);
    showdble(fp,"maxbid", parm->maxbid);
    showdble(fp,"beta", parm->beta);

    return self;
}


- initAgent:(int)mytag
/*
 * Initializes a forecasting agent.  This could be overridden by a
 * particular type of forecasting agent, but then you must assure that
 * the equivalent steps are taken.
 */ 
{
    register int f;

// Initialize generic variables common to all agents, link into list
    [super initAgent:mytag];

// Initialize our instance variables
    p = params;		/* last values set by +createAgent:: */
    lambda = p->defaultlambda;
    numfcasts = p->defaultnumfcasts;

// Allocate memory for forecasters and tell them to initialize
    fcasts = (fcast *) getmem(sizeof(fcast)*numfcasts);
    for (f = 0; f < numfcasts; f++) {
	fcasts[f].lforecast = fcasts[f].forecast = price;
	fcasts[f].variance = 0.25;	// large initial value
	fcasts[f].count = 0;
	[self makePredictor: f];
    }

    return self;
}


- free
{
    free(fcasts);
    return [super free];
}


#ifdef NEXTSTEP
- copyFromZone:(NXZone *)zone
{
    Forecaster *new = (Forecaster *)[super copyFromZone: zone];
#else
- copy
{
    Forecaster *new = (Forecaster *)[super copy];
#endif

    new->fcasts = (fcast *) GETMEM(sizeof(fcast)*numfcasts);
    (void) memcpy(new->fcasts, fcasts, sizeof(fcast)*numfcasts);
    return new;
}


- (double)lambda
{
    return lambda;
}


- setLambda:(double)newLambda
{
    lambda = newLambda;
    return self;
}


- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice
// Returns the agent's requested bid (if >0) or offer (if <0).
{
    register fcast *fptr;
    fcast *prev, *fptrtop;
    double divisor, sum, x, scaledbeta;
    
// Ask all forecasters to give their forecast, and construct linked list
// of those that complied, accumulating their strengths
    sum = 0.0;
    prev = NULL;
    scaledbeta = 0.01*p->beta;
    fptrtop = fcasts+numfcasts;
    for (fptr=fcasts; fptr < fptrtop; fptr++) {
	fptr->lforecast = fptr->forecast;
	if(fptr->variance >= 10) {
		fptr->variance = 0.25;
		}

	if ([self predict:(fptr-fcasts) return:&fptr->forecast
						forPrice:trialprice]) {
	    sum += exp(p->beta/(fptr->variance+scaledbeta));
	    fptr->next = prev;
	    prev = fptr;
	}
	
	fptr->cumstrength = sum;
    }
    first = prev;

// Choose a forecast using weighted roulette wheel, calculate desired
// holding (from forecast and risk aversion), make bid
    if (sum == 0.0) {
	chosen = NULL;		// no forecasts at all -- hold
	demand = 0.0;
	/* slope is not revealed */
	return demand;
    }
    else {
	if (numfcasts == 1)
	    chosen = fcasts;	
	else {
	    x = drand() * sum;
	    for (fptr=fcasts; fptr < fptrtop; fptr++)
		if (fptr->cumstrength > x) break;
	    chosen = fptr;
	}
	divisor = lambda*chosen->variance;
	demand = - ((trialprice*intratep1 - chosen->forecast)/divisor +
								position);
    // This ignores the possible dependence of forecast on trialprice:	
	*slope = -intratep1/divisor;

    /* Constrain forecasting agent to |maxbid|. */
	if (demand > p->maxbid) {
	    demand = p->maxbid;
	    *slope = 0.0;
	}
	else if (demand < -p->maxbid) {
	    demand = -p->maxbid;	
	    *slope = 0.0;
	}

	return [super constrainDemand:slope:trialprice];

    }

}


- updatePerformance
// Updates the variance of all the active predictors
{
    register fcast *fptr;
    double difference, dsquared;

    for (fptr=first; fptr!=NULL; fptr=fptr->next) {
    	
	/*
	difference = returnratio - intrate;
	*/
	difference = price + dividend - fptr->lforecast;
	dsquared = difference*difference;
	
	if (dsquared>1.0) dsquared = 1.0;
	
	fptr->variance = p->tauvdecay*fptr->variance +
			p->tauvnew*dsquared;
	/*		
	fptr->variance = 0.25;
	*/
	
	fptr->count++;
    }

    return self;
}


- makePredictor:(int)f
{
    return self;
}


- (BOOL)predict:(int)n return:(double *)forecast forPrice:(double)trialprice
{
    [self subclassResponsibility:_cmd];
    return NO;		// not reached
}


@end
