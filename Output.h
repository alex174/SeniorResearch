// Artificial Stock Market Swarm Version Output File Interface

#import <stdio.h>
#import <stdarg.h>
#import <time.h>
#import <objectbase.h>
#import "World.h"
#import "Specialist.h"


@interface Output: SwarmObject
{
  World * outputWorld;
  Specialist * outputSpecialist;
 //   int numBFagents;
//    float initholding;
//    double initialcash;
//    double minholding;
//    double mincash;
//    double intrate;

//    double baseline;
//    double mindividend;
//    double maxdividend;
//    double amplitude;
//    int period;

//    BOOL exponentialMAs;

//    double maxprice;
//    double minprice;
//    double taup;
//    int sptype;
//    int maxiterations;
//    double minexcess;
//    double eta;
//    double etamax;
//    double etamin;
//    double rea;
//    double reb;
//    int seed;
//    double tauv;
//    double lambda;
//    double maxbid;
//    double initvar;
//    double maxdev;
  FILE * paramOutputFile;
  time_t runTime;

  int currentTime;
  double price;
  double dividend;
  double volume;
  FILE * dataOutputFile;
}

-setSpecialist: (Specialist *)theSpec;
-setWorld: (World *)theWorld;
//  -setNumBFagents: (int)BFagents;
//  -setInitHolding: (float)Holding;
//  -setInitialCash: (double)initcash;
//  -setminHolding: (double)holding   minCash: (double)minimumcash;
//  -setIntRate: (double)Rate;
	      
//  -setBaseline: (double)theBaseline;
//  -setmindividend: (double)minimumDividend;
//  -setmaxdividend: (double)maximumDividend;
//  -setTheAmplitude: (double)theAmplitude;
//  -setThePeriod: (int)thePeriod;

//  -setExponentialMAs: (BOOL)aBool;
  
//  -setMaxPrice: (double)maximumPrice;
//  -setMinPrice: (double)minimumPrice;
//  -setTaup: (double)aTaup;
//  -setSPtype: (int)i;
//  -setMaxIterations: (int)someIterations;
//  -setMinExcess: (double)minimumExcess;
//  -setETA: (double)ETA;
//  -setETAmin: (double)ETAmin;
//  -setETAmax: (double) ETAmax;
//  -setREA: (double)REA;
//  -setREB: (double)REB;

//  -setSeed: (int)aSeed;

//  -setTauv: (double)aTauv;
//  -setLambda: (double)aLambda;
//  -setMaxBid: (double)maximumBid;
//  -setInitVar: (double)initialVar;
//  -setMaxDev: (double)maximumDev;

-writeParams;
-prepareOutputFile;
-writeData;

@end




