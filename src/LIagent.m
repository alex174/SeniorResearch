// Implementation for LIagent -- linear predictors

#import "global.h"
#import "LIagent.h"
#import "random.h"

// Macro to check arguments for debugging
#ifdef DEBUG
#define CHECKFCAST(f)	{if ((f) < 0 || (f) >= numfcasts) \
			[self error:"Invalid forecast number '%d'", (f)];}
#else
#define CHECKFCAST(f)	{}
#endif


@implementation LIagent

- makePredictor:(int)f
{
    CHECKFCAST(f)
    predictortype[f] = irand(NTYPES);

// set params to REE - this is messy
    rho = 0.99;
    sigma = 0.04;
    dmean = 10.;
    pa = rho/(1+intrate-rho);
    pb = (pa+1.0)*((1.0-rho)*dmean-lambda*sigma)/intrate;
    
    oldreturn = intrate;
    mr = 0;
    return self;
}


- (BOOL)predict:(int)f return:(double *)forecast forPrice:(double)trialprice;
{
    double priceforecast;
    double dividendforecast;

    CHECKFCAST(f)
    
    /*
    switch(predictortype[f]) {
    */
    switch(0) {
    case 0:
	*forecast = (pa+1)*rho*dividend + pb;
	*forecast = (9.9)*rho*dividend+2;	
	break;
    case 1:
	*forecast = returnratio + (returnratio - oldreturn);
	oldreturn = returnratio;
	break;
    case 2:
	priceforecast = trialprice + (trialprice-price);
	dividendforecast = dividend + (dividend - olddividend);
	*forecast = (priceforecast + dividendforecast - trialprice)/trialprice;
	break;
    case 3:
	*forecast = (returnratio + intrate)*0.5;
 	break;
    case 4:
	dividendforecast = dividend + (dividend - olddividend);
	*forecast = dividendforecast/trialprice;
 	break;
   }
   return YES;
}


@end
