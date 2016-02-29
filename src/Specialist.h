//#import <objectbase.h>    //Specialist is a SwarmObject
#import "World.h"

@class Agent;

typedef enum 
{
  SP_RE = 0,
  SP_SLOPE = 1,
  SP_ETA = 2
} SpecialistType;


@interface Specialist: SwarmObject
{
  double maxprice; /*"Ceiling on stock price"*/
  double minprice; /*"Floor under stock price"*/
  double eta;  /*"Used in adjusting price to balance supply/demand"*/
  // double etainitial; /not used in ASM-2.0
  double minexcess; /*"excess demand must be smaller than this if the price adjustment process is to stop"*/
  double rea; /*"rational expectations benchmark"*/ 
  double reb; /*" trialprice = rea*dividend + reb "*/
  double bidfrac; /*"used in completing trades: volume/bidtotal"*/
  double offerfrac; /*"used in completing trades: volume/offertotal"*/
  int maxiterations; /*" maximum passes while adjusting trade conditions"*/
  //  id agentList; /*" set of traders whose demands must be reconciled"*/
  double volume; /*" volume of trades conducted"*/
  double taupdecay; /*"The agent's profit is calculated as an exponentially weighted moving average.  This coefficient weights old inputs in the EWMA"*/ 
  double taupnew; /*"Used in calculating exponentially weighted moving average;  taupnew = -expm1(-1.0/aTaup); taupdecay =  1.0 - taupnew; "*/ 
  @private
    //   World * worldForSpec; /*" reference to World object that keeps data"*/
  SpecialistType sptype; /*" an enumerated type indicating the sort of Specialist is being used, valued 0, 1, or 2"*/
}

// Methods to set parameters
- setMaxPrice: (double)maximumPrice;
- setMinPrice: (double)minimumPrice;
- setTaup: (double)aTaup;
- setSPtype: (int)i;
- setMaxIterations: (int)someIterations;
- setMinExcess: (double)minimumExcess;
- setETA: (double)ETA;

- setREA: (double)REA;
- setREB: (double)REB;


- (double)performTrading: (id)agentList Market: (id)worldForSpec;
- (double)getVolume;
- completeTrades: agentList Market: worldForSpec;


@end






