#import <objectbase/Swarm.h>
#import "BFagent.h"
#import "Specialist.h"
#import "Dividend.h"
#import "World.h"
#import "Output.h"

@interface ASMModelSwarm: Swarm
{
  //Agent parameters
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

  //Specialist parameters
  double maxprice;
  double minprice;
  double taup;
  BOOL exponentialMAs;   //Also used by World.
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

  id warmupActions;
  id periodActions;
  id warmupSchedule;
  id periodSchedule;
  id startupSchedule;
  id initPeriodSchedule;

  id agentList;
  id specialist;
  id dividendProcess;
  id world;
  id output;
  BOOL setOutputForData;
}



+createBegin: (id)aZone;
-createEnd;

-getAgentList;
-(int)getNumBFagents;
-(double)getInitialCash;
-(World *)getWorld;
-(Specialist *)getSpecialist;
-(Output *)getOutput;
-setBatchRandomSeed: (int)newSeed;

-buildObjects;
-initOutputForDataWrite;
-initOutputForParamWrite;
-buildActions;
-activateIn: (id)swarmContext;

void warmUp(id  warmupSchedule);
void initPeriod(id  initPeriodSchedule);

-warmupStepDividend;
-warmupStepPrice;
-periodStepDividend;
//-prepareBFagentForTrading;
-periodStepPrice;


@end
