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
  int currentTime; /*"The agent regularly checks with Swarm to see what time it is"*/
  int lastgatime;	/*" last time period when the GeneticAlgorithm was run"*/
  double avspecificity; /*'average specificity of active forecasts"*/
  double forecast;       /*"prediction of stock price: (trialprice+dividend)*pdcoeff + offset."*/
  double lforecast; /*"lagged forecast: forecast value from previous period"*/
  double global_mean; /*"price+dividend"*/
  double realDeviation;  /*" ftarget-lforecast: how far off was the agent's forecast?"*/
  double variance;   /*"an Exp.Weighted MA of the agent's historical variance: Combine the old variance with deviation^squared, as in:  bv*variance + av*deviation*deviation"*/
  double pdcoeff;   /*" coefficient used in predicting stock price, recalculated each period in prepareForTrading"*/  
  double offset;    /*" coefficient used in predicting stock price, recalculated each period in prepareForTrading"*/  
  double divisor;   /*" a coefficient used to calculate demand for stock. It is a proportion (lambda) of forecastvar (basically, accuracy of forecasts)"*/
  int gacount;     /*" how many times has the Genetic Algorithm been used?"*/
  // int nactive;     
  BFParams * privateParams;     /*"BFParams object holds parameters of this object"*/

  id <Array> fcastList;        /*"A Swarm Array, holding the forecasts that the agent might use"*/

  id <List> activeList;       /*"A Swarm list containing a subset of all forecasts"*/
  id <List> oldActiveList;    /*"A copy of the activeList from the previous time step"*/
}

+ (void)setBFParameterObject: x;
+ (void)init;

- createEnd;
- initForecasts;

- (BFCast *)createNewForecast;  //all conditions=0

- setConditionsRandomly: (BFCast *)fcastObject; //apply to forecast
- prepareForTrading;
- (BitVector *) collectWorldData: aZone;
- updateActiveList: (BitVector *)worldvalues;

- getInputValues;  //does nothing, used only if their are ANNagents
- feedForward;     //does nothing, used only if their are ANNagents
- (double)getDemandAndSlope: (double *)slope forPrice: (double)trialprice;
- (double)getRealForecast;
- updatePerformance;
- (double)getDeviation;
- updateWeights;   //does nothing, used only if their are ANNagents
- (int)nbits;
- (int)nrules;

- performGA;
- (int)lastgatime;

- printcond: (int)word;

- copyList: list To: outputList;

- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
- (int)fMoments: (double *)moment cumulative: (BOOL)cum;
- (const char *)descriptionOfBit:(int)bit;

@end






