#import <objectbase/Swarm.h>
#import "BFagent.h"
#import "Specialist.h"
#import "Dividend.h"
#import "World.h"
#import "Output.h"
#import "ASMModelParams.h"


@interface ASMModelSwarm: Swarm
{
  int modelTime;    /*"An integer used to represent the current timestep"*/
  id warmupActions;
  id periodActions;
  id warmupSchedule;
  id periodSchedule;
  id startupSchedule;
  id initPeriodSchedule;

  id agentList;       /*"A Swarm collection of agents "*/
  id specialist;      /*"Specialist who clears the market   "*/
  id dividendProcess; /*"Dividend process that generates dividends  "*/
  id world;          /*"A World object, a price historian, really   "*/
  id output;         /*"An Output object   "*/

  BFParams * bfParams;          /*" A (BFParams) parameter object holding BFagent parameters"*/
  ASMModelParams * asmModelParams;  /*" A (ASMModelParms) parameter object holding parameters of Models"*/
                      
}


-createEnd;

- setParamsModel: (ASMModelParams *) modelParams BF: (BFParams *) bfp ;  //pj: new param receiver 
- getAgentList;
- (int)getNumBFagents;
- (double)getInitialCash;
- (World *)getWorld;
- (Specialist *)getSpecialist;
- (Output *)getOutput;
- setBatchRandomSeed: (int)newSeed;

- buildObjects;
- writeParams;
- buildActions;
- activateIn: (id)swarmContext;
- doWarmupStep;
- (void)warmUp: x;

- (void)initPeriod: x;

- warmupStepDividend;
- warmupStepPrice;
- periodStepDividend;
- periodStepPrice;


-(long int) getModelTime;

-(void) drop;

@end








