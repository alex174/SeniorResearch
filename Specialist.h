#import <objectbase.h>    //Specialist is a SwarmObject
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
  double etamax;
  double etamin;
  double ldelpmax;
  double minexcess;
  double rea;
  double reb;
  double bidfrac;
  double offerfrac;
  int maxiterations;
  int varcount;
  SpecialistType sptype;
  id agentList;
  World * worldForSpec;

  double bidtotal;
  double offertotal;
  double volume;
  double oldbidtotal;
  double oldoffertotal;
  double oldvolume;

  double price;
  double taup;
  double taupdecay;
  double taupnew;
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
-setETAmin: (double)ETAmin;
-setETAmax: (double)ETAmax;
-setREA: (double)REA;
-setREB: (double)REB;

-init;
-(double)performTrading;
-(double)getVolume;
-completeTrades;


@end





