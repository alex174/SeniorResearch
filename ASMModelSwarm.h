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
  
  id <ActionGroup> periodActions; /*" An ActionGroup that collects things that are supposed to happen in a particular sequential order during each timestep "*/
  id <Schedule> periodSchedule; /*" Schedule on which we add period (repeating) actions, most importantly, the action group periodActions"*/
  id <Schedule> startupSchedule;
  
  id <List> agentList;       /*"A Swarm collection of agents "*/
  Specialist * specialist;      /*"Specialist who clears the market   "*/
  Dividend * dividendProcess; /*"Dividend process that generates dividends  "*/
  World * world;          /*"A World object, a price historian, really   "*/
  Output * output;         /*"An Output object   "*/
  
  BFParams * bfParams;          /*" A (BFParams) parameter object holding BFagent parameters"*/
  ASMModelParams * asmModelParams;  /*" A (ASMModelParms) parameter object holding parameters of Models"*/
  
                    
}


-createEnd;

- setParamsModel: (ASMModelParams *) modelParams BF: (BFParams *) bfp ; 
- setOutputObject: (Output *) obj;
 //pj: new param receiver 
- getAgentList;
- (int)getNumBFagents;
- (double)getInitialCash;
- (World *)getWorld;
- (Specialist *)getSpecialist;
- (Output *)getOutput;
- setBatchRandomSeed: (int)newSeed;

- buildObjects;

- createAgents;


- lispArchive: (char *)inputName;
- lispLoadAgents: (const char *)lispfile;
- lispLoadWorld: (const char *)lispfile;

- writeParams;
- buildActions;

- (void)updateAgentPerformance;
- (void)prepareAgentsForTrading;
- (void)creditAgentEarningsAndPayTaxes;


- activateIn: (id)swarmContext;
- doWarmupStep;

- periodStepDividend;
- periodStepPrice;


-(long int) getModelTime;

-(void) drop;


@end








