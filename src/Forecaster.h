// Interface for Forecaster class
// This is an abstract superclass for some forecasting agents (not BF, NE).

#import "Agent.h"


// Structure for list of individual forecasts
typedef struct FC_fcast {
    struct FC_fcast *next;	// linked list of ACTIVE forecasts
    double forecast;		// this forecast of return
    double lforecast;		// last forecast
    double variance;		// variance of this forecast
    double cumstrength;		// work space for roulette wheel
    int count;			// number of times used
} fcast;


// Parameters common to all agents in a type derived from here
struct Fparams {
    int class;
    int type;
    double maxbid;
    double tauv;
    double tauvdecay;
    double tauvnew;
    double beta;
    double defaultlambda;
    int defaultnumfcasts;
} ;


@interface Forecaster:Agent
{
@public
    double lambda;	// risk aversion parameter
    fcast *fcasts;	// array of size numfcasts
    fcast *first;	// pointer to first ACTIVE one
    fcast *chosen;	// pointer to chosen one
    int numfcasts;	// how many forecasters we have
    struct Fparams *p;	// pointer to our parameters
}

// CLASS METHODS OVERRIDDEN FROM Agent CLASS
+ initClass:(int)myclass;
+ (void *)createType:(int)mytype :(const char *)filename;
+ writeParams:(void *)theParams ToFile:(FILE *)fp;

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)nameidx;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;
- updatePerformance;

// INSTANCE METHODS OVERRIDDEN FROM Object CLASS
- free;
#ifdef NEXTSTEP
- copyFromZone:(NXZone *)zone;
#else
- copy;
#endif

// PUBLIC INSTANCE METHODS ADDED BY THIS CLASS
- (double)lambda;
- setLambda:(double)newLambda;

// PRIVATE METHOD, DOES NOTHING, MAY BE OVERRIDDEN BY SUBCLASS
- makePredictor:(int)f;

// MUST BE DEFINED IN SUBCLASS
- (BOOL)predict:(int)f return:(double *)forecast forPrice:(double)trialprice;

@end
