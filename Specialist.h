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
  int maxiterations;
  id agentList;
  double volume;
  double taupdecay;
  double taupnew;
  @private
  World * worldForSpec;
  SpecialistType sptype;
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


@end






