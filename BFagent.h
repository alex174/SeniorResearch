// Interface for BFagent -- Classifier predictors

#import "Agent.h"
#import "BFParams.h"


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
  // struct BFparams *p;
  int gacount;
  int nactive;
  BFParams * privateParams;             //created from same mechanism as public params
  struct BF_fcast	**reject;	/* GA temporary storage */
  struct BF_fcast	*newfcast;	/* GA temporary storage */

}

+(void)setBFParameterObject: x;
+(void)init;
+didInitialize;
+prepareForTrading;
//+(int)lastgatime;
+setRealWorld: (int *)array;
+(int)setNumWorldBits;

-createEnd;
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
//pj:-(int)fMoments: (double *)moment cumulative: (BOOL)cum;
//pj:-(const char *)descriptionOfBit:(int)bit;

@end





