// Interface for BFagent -- Classifier predictors

#import "Agent.h"
#import "BFParams.h"
#import "BFCast.h"
#import <collections.h>
#import "World.h"


//pj:   // Structure for list of individual forecasts
//pj:  struct BF_fcast 
//pj:  THIS STRUCT HAS MOVED INTO ITS OWN CLASS, BFCast. Go see.

//pj:  struct BFparams moved to its own class, BFParams.
//pj: I did not rename for fun, but to help make sure all code was completely updated.

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
  // struct BF_fcast *fcast;		// array of size numfcasts
  //struct BF_fcast *activelist;
  //struct BF_fcast *lactivelist; 	// last active list
  // struct BFparams *p;
  int gacount;
  int nactive;
  BFParams * privateParams;             //created from same mechanism as public params
  // struct BF_fcast	**reject;	/* GA temporary storage */
  //  struct BF_fcast	*newfcast;	/* GA temporary storage */
  //id <Array> rejectList; //need ** accounted for ???

  id <Array> fcastList;
  //id <Array> newconds;

  id <List> activeList;
  id <List> lActiveList;
}

+(void)setBFParameterObject: x;
+(void)init;
//+didInitialize;
+prepareForTrading;
//+(int)lastgatime;
+setRealWorld: (int *)array;
+(int)setNumWorldBits;

-createEnd;
-initForecasts;
//-free;
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

-printcond: (int) word;

//-(int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
//pj:-(int)fMoments: (double *)moment cumulative: (BOOL)cum;
//pj:-(const char *)descriptionOfBit:(int)bit;

@end





