#import <objectbase/SwarmObject.h>

@interface ASMModelParams: SwarmObject
{
@public
  int numBFagents;  /*" number of BFagents "*/
  float initholding;
  double initialcash;
  double minholding;
  double mincash;
  double intrate;

  //Dividend parameters
  double baseline;   //Also used by World.
  double mindividend;
  double maxdividend;
  double amplitude;
  double period;
  int exponentialMAs;   //Also used by World.//pj:was BOOL
  //Specialist parameters
  double maxprice;
  double minprice;
  double taup;
  int sptype;
  int maxiterations;
  double minexcess;
  double eta;
  double etamax;
  double etamin;
  double rea;
  double reb;
  int randomSeed;
  //Agent parameters overridden by the BFagent.  
  //These might be used for other agents that a user implements. 
  double maxbid; 
  double maxdev;
  int setOutputForData;
};

@end


