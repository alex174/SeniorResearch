#import <objectbase/Swarm.h>
#import "BFagent.h"
#import "Specialist.h"
#import "Dividend.h"
#import "World.h"
#import "Output.h"
#import "ASMModelParams.h"


@interface ASMModelSwarm: Swarm
{
//    //Agent parameters
//    int numBFagents;
//    float initholding;
//    double initialcash;
//    double minholding;
//    double mincash;
//    double intrate;

//    //Dividend parameters
//    double baseline;   //Also used by World.
//    double mindividend;
//    double maxdividend;
//    double amplitude;
//    int period;

//    //Specialist parameters
//    double maxprice;
//    double minprice;
//    double taup;
//    BOOL exponentialMAs;   //Also used by World.
//    int sptype;
//    int maxiterations;
//    double minexcess;
//    double eta;
//    double etamax;
//    double etamin;
//    double rea;
//    double reb;

//    int randomSeed;

  //Agent parameters overridden by the BFagent.  
  //These might be used for other agents that a user implements. 
 //   double tauv;          
//    double lambda;
//    double maxbid; 
//    double initvar;
//    double maxdev;	

  int modelTime;
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
  // int setOutputForData;

  BFParams * bfParams;          //pj: a parameter object
  ASMModelParams * asmModelParams;  //pj: a parameter object
                      
}



//+createBegin: (id)aZone;

-createEnd;

- setParamsModel: (ASMModelParams *) modelParams BF: (BFParams *) bfp ;  //pj: new param receiver 
-getAgentList;
-(int)getNumBFagents;
-(double)getInitialCash;
-(World *)getWorld;
-(Specialist *)getSpecialist;
-(Output *)getOutput;
-setBatchRandomSeed: (int)newSeed;

-buildObjects;
// pj: -initOutputForDataWrite;
// pj: -initOutputForParamWrite;
- writeParams;
- buildActions;
- activateIn: (id)swarmContext;

void warmUp(id  warmupSchedule);
void initPeriod(id  initPeriodSchedule);

-warmupStepDividend;
-warmupStepPrice;
-periodStepDividend;
//-prepareBFagentForTrading;
-periodStepPrice;


-(long int) getModelTime;

-(void) drop;

@end
