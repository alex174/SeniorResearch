#import <objectbase/SwarmObject.h>

@interface ASMModelParams: SwarmObject
{
@public
  int numBFagents;
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
  int period;
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
  double tauv;          
  double lambda;
  double maxbid; 
  double initvar;
  double maxdev;
  int setOutputForData;
	
};

@end


