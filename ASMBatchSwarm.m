#import "ASMBatchSwarm.h"
#import "Parameters.h"

@implementation ASMBatchSwarm

+createBegin: (id)aZone
{
  ASMBatchSwarm * obj;

  obj = [super createBegin: aZone];

  //overridden by settings from scm file
  // obj->loggingFrequency = 1;
  //obj->experimentDuration = 500;
	
  return obj;
}


-buildObjects
{
  id modelZone;
  BFParams * bfParams = [(id)arguments getBFParams];
  ASMModelParams * asmModelParams = [(id)arguments getModelParams];

  [super buildObjects];

  modelZone = [Zone create: [self getZone]];
  asmModelSwarm = [ASMModelSwarm create: modelZone];
 
  [asmModelSwarm setParamsModel: asmModelParams BF: bfParams];

  //ObjectLoader: is deprecated
  //: [ObjectLoader load: self fromAppDataFileNamed: "batch.setup"];

  //pj:  [ObjectLoader load: asmModelSwarm fromAppDataFileNamed: "param.data"];

 
  [asmModelSwarm buildObjects];

  output = [asmModelSwarm getOutput];
  [output prepareOutputFile];
  [output writeParams: asmModelParams BFAgent: bfParams Time: 0];
  
  return self;
}


-buildActions
{
  [super buildActions];
  
  [asmModelSwarm buildActions];

  if(loggingFrequency)
    {
      displayActions = [ActionGroup create: [self getZone]];
      [displayActions createActionTo: output message: M(writeData)];
						    
      displaySchedule = [Schedule createBegin: [self getZone]];
      [displaySchedule setRepeatInterval: loggingFrequency];
      displaySchedule = [displaySchedule createEnd];
      [displaySchedule at: 0 createAction: displayActions];
    }

  stopSchedule = [Schedule create: [self getZone]];
  [stopSchedule at: experimentDuration createActionTo: self message: M(stopRunning)];

  return self;
}


-activateIn: (id)swarmContext
{
  [super activateIn: swarmContext];
  [asmModelSwarm activateIn: self];

  [stopSchedule activateIn: self];
  if(loggingFrequency)
    [displaySchedule activateIn: self];
 
  return [self getSwarmActivity];
}



- expostParamWrite
{
 [[asmModelSwarm getOutput] writeParams: [(id) arguments getModelParams] BFAgent: [(id) arguments getBFParams] Time: [asmModelSwarm getModelTime]]; 
  return self;
}


-go
{
  printf("\nYou typed 'asm -batchmode'.  The simulation is running without graphics.\n\n");
  printf("The Artificial Stock Market is running for %d time steps and writing 
its data.\n\n",experimentDuration);
  if(loggingFrequency)
    printf("It is logging data every %d timesteps to a time-dated output.data file.\n\n",
	   loggingFrequency);

  [[self getActivity] run];
  return [[self getActivity] getStatus];
}
  

-stopRunning
{
  [getTopLevelActivity() terminate];
  return self;
}

@end











