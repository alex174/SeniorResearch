// Interface for BFagent -- Classifier predictors

#import "Agent.h"

// Structure for list of individual forecasts
struct BF_fcast 
{
  double forecast;	// this forecast of return
  double lforecast;	// previous forecast
  double variance;	// variance of this forecast
  double strength;
  double a;		// (price + dividend) coefficient
  double b;		// dividend coefficient
  double c;		// constant term
  double specfactor;	// specificity factor; strength=specfactor/variance
  struct BF_fcast *next;	// linked list of ACTIVE forecasts
  struct BF_fcast *lnext;
  unsigned int *conditions;
  int lastactive;
  int specificity;
  int count;
};

struct BFparams 
{
  int numfcasts;
  int condwords;
  int condbits;
  int mincount;
  int gafrequency;
  int firstgatime;
  int longtime;	// unused time before Generalize()
  int individual;
  double tauv;
  double lambda;
  double maxbid;
  double bitprob;
  double subrange;	// fraction of min-max range for initial random values
  double a_min,a_max;	// min and max for p+d coef
  double b_min,b_max;	// min and max for div coef
  double c_min,c_max;	// min and max for constant term
  double a_range,b_range,c_range;	// derived: max - min
  double newfcastvar;	// variance assigned to a new forecaster
  double initvar;	// variance of overall forecast for t<200
  double bitcost;	// penalty parameter for specificity
  double maxdev;	// max deviation of a forecast in variance estimation
  double poolfrac;	// fraction of rules in replacement pool
  double newfrac;	// fraction of rules replaced
  double pcrossover;	// probability of running Crossover() at all.
  double plinear;	// linear combination "crossover" prob.
  double prandom;	// random from each parent crossover prob.
  double pmutation;	// per bit mutation prob.
  double plong;	        // long jump prob.
  double pshort;	// short (neighborhood) jump prob.
  double nhood;	        // size of neighborhood.
  double genfrac;	// fraction of 0/1 bits to generalize
  double gaprob;	// derived: 1/gafrequency
  int npool;		// derived: replacement pool size
  int nnew;		// derived: number of new rules
  int nnulls;
  int lastgatime;
  int *bitlist;		// dynamic array, length condbits
  double *problist;	// dynamic array, length condbits
  unsigned int *myworld;// dynamic array, length condwordsdouble avspecificity
};


@interface BFagent:Agent
{
  int currentTime;
  int lastgatime;	// last time a GA was run
  double avspecificity;
  double forecast;
  double lforecast;
  double global_mean;
  double realDeviation;
  double variance;
  double pdcoeff;
  double offset;
  double divisor;
  struct BF_fcast *fcast;		// array of size numfcasts
  struct BF_fcast *activelist;
  struct BF_fcast *lactivelist; 	// last active list
  struct BFparams *p;
  int gacount;
  int nactive;
}

+(void *)init;
+didInitialize;
+prepareForTrading;
+(int)lastgatime;
+setRealWorld: (int *)array;
+(int)setNumWorldBits;

-initForecasts;
-free;
-prepareForTrading;
-getInputValues;  //does nothing, used only if their are ANNagents
-feedForward;     //does nothing, used only if their are ANNagents
-(double)getDemandAndSlope:(double *)slope forPrice:(double)trialprice;
-(double)getRealForecast;
-updatePerformance;
-(double)getDeviation;
-updateWeights;   //does nothing, used only if their are ANNagents
-(int)nbits;
-(int)nrules;
-(int)lastgatime;
-(int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
-(int)fMoments: (double *)moment cumulative: (BOOL)cum;
-(const char *)descriptionOfBit:(int)bit;

@end





