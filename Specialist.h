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
  double maxprice;
  double minprice;
  double eta;
  double etainitial;
  double minexcess;
  double rea;
  double reb;
  double bidfrac;
  double offerfrac;
  int maxiterations; /*" maximum passes while adjusting trade conditions"*/
  id agentList; /*" set of traders whose demands must be reconciled"*/
  double volume; /*" volume of trades conducted"*/
  double taupdecay;
  double taupnew;
  @private
    World * worldForSpec; /*" reference to World object that keeps data"*/
  SpecialistType sptype; /*" an enumerated type indicating the sort of Specialist is being used, valued 0, 1, or 2"*/
}

// Methods to set parameters
-setAgentList: (id)aList;
-setWorld: (World *)myWorld;
-setMaxPrice: (double)maximumPrice;
-setMinPrice: (double)minimumPrice;
-setTaup: (double)aTaup;
-setSPtype: (int)i;
-setMaxIterations: (int)someIterations;
-setMinExcess: (double)minimumExcess;
-setETA: (double)ETA;

-setREA: (double)REA;
-setREB: (double)REB;


-(double)performTrading;
-(double)getVolume;
-completeTrades;
y

@end






