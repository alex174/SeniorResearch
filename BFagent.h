// Interface for BFagent -- Classifier predictors

#import "Agent.h"
#import "BFParams.h"
#import "BFCast.h"
#import <collections.h>
#import "World.h"


@interface BFagent:Agent
{
  int currentTime; /*"The agent regularly checks with Swarm to see what time it is"*/
  double forecast;       /*"prediction of stock price: (trialprice+dividend)*pdcoeff + offset."*/
  double lforecast; /*"lagged forecast: forecast value from previous period"*/
  double global_mean; /*"price+dividend"*/
  double realDeviation;  /*" ftarget-lforecast: how far off was the agent's forecast?"*/
  double variance;   /*"an Exp.Weighted MA of the agent's historical variance: Combine the old variance with deviation^squared, as in:  bv*variance + av*deviation*deviation"*/
  double medianstrength;

  double pdcoeff;   /*" coefficient used in predicting stock price, recalculated each period in prepareForTrading"*/  
  double offset;    /*" coefficient used in predicting stock price, recalculated each period in prepareForTrading"*/  
  double divisor;   /*" a coefficient used to calculate demand for stock. It is a proportion (lambda) of forecastvar (basically, accuracy of forecasts)"*/
  int gacount;     /*" how many times has the Genetic Algorithm been used?"*/
       
  BFParams * privateParams;     /*"BFParams object holds parameters of this object"*/

  id <Array> fcastList;        /*"A Swarm Array, holding the forecasts that the agent might use"*/

  id <List> activeList;       /*"A Swarm list containing a subset of all forecasts"*/
  id <List> oldActiveList;    /*"A copy of the activeList from the previous time step"*/
  BFCast * strongestBFCast;  /*"A pointer to the strongest rule of the agent"*/
}

+ (void)setBFParameterObject: x;
+ (void)init;

- (BFCast *)getStrongestBFCast;
- createEnd;
- initForecasts;
- (int)getNfcasts;

- (BFCast *)createNewForecast;  //all conditions=0

- setConditionsRandomly: (BFCast *)fcastObject; //apply to forecast
- prepareForTrading;
- (BitVector *) collectWorldData: aZone;
- updateActiveList: (BitVector *)worldvalues;

- (double)getDemandAndSlope: (double *)slope forPrice: (double)trialprice;
- (double)getRealForecast;
- (double)getMedianstrength;
- updatePerformance;
- (double)getDeviation;
- (int)nbits;
- (int)nrules;

- performGA;

- (BFCast *)  CopyRule:(BFCast *) to From: (BFCast *) from;
- (void) MakePool: (id <List>)rejects From: (id <Array>) list;
- (BOOL) Mutate: (BFCast *) new Status: (BOOL) changed Strength: (double)medstrength;
- (BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2 Strength: (double)medstrength;
- (void) TransferFcastsFrom: newList To:  forecastList Replace: rejects; 
- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects;
- (void) Generalize: (id) list Strength: (double) strength;
- (BFCast *) Tournament: (id <Array>) list;
- (double) CalculateAndUseMadv;
- (double) CalculateMedian;
- (BFCast *) FcastSetParams: (BFCast *)aNewForecast Strength: (double)medstrength Madv: (double)madv;
- (BOOL) PickParents: (BFCast *) aNewForecast Strength: (double)medstrength;

- printcond: (int)word;

- copyList: list To: outputList;

- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
- (int)fMoments: (double *)moment cumulative: (BOOL)cum;
- (const char *)descriptionOfBit:(int)bit;

- (void)lispOutDeep: stream;
- (void)bareLispOutDeep: stream;

@end






