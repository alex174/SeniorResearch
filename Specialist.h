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
//    double etamax;  pj: was unused
//    double etamin;  pj: was unused
  //double ldelpmax; pj: was unused
  double minexcess;
  double rea;
  double reb;
  double bidfrac;
  double offerfrac;
  int maxiterations;
  //int varcount;  pj: was not used in class
   SpecialistType sptype;
  id agentList;
  World * worldForSpec;

  //double bidtotal;
  //double offertotal; pj: just in performTrading method
  double volume;
  //double oldbidtotal;  pj: was unused
  //double oldoffertotal; pj: was unused
  //double oldvolume; pj: was unused

  //double price;  pj: was used only in completeTrades
  //double taup;   pj: was not needed in class
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
//-setETAmin: (double)ETAmin;  //pj: set value never used
//-setETAmax: (double)ETAmax;  //pj: set value never used
-setREA: (double)REA;
-setREB: (double)REB;

-init;//pj: init can be deleted ??
-(double)performTrading;
-(double)getVolume;
-completeTrades;


@end






