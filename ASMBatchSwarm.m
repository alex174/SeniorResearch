#import "ASMBatchSwarm.h"
#import "Parameters.h"

@implementation ASMBatchSwarm
/*"If the model is started with ./asm -b, then this ASMBatchSwarm acts
  as the top level Swarm. The benefit here is that the model runs
  faster because it is not driving a graphical interface.  It also
  turns on data-writing."*/


+createBegin: (id)aZone
{
  ASMBatchSwarm * obj;
  obj = [super createBegin: aZone];	
  return obj;
}

/*"Create a model swarm, have the model swarm build its objects, and
then get the output object from the model.  Later the output object is
instructed to write results"*/
-buildObjects
{
  id modelZone;
  BFParams * bfParams = [(id)arguments getBFParams];

  ASMModelParams * asmModelParams = [(id)arguments getModelParams];

  output = [[Output createBegin: self] createEnd];

  [super buildObjects];

  asmModelSwarm = [ASMModelSwarm create: self]; 
  
  [asmModelSwarm setOutputObject: output];

  [asmModelSwarm setParamsModel: asmModelParams BF: bfParams];

  [asmModelSwarm buildObjects];

  [output createTimePlots];
  [output prepareCOutputFile];
  [output writeParams: asmModelParams BFAgent: bfParams Time: 0];
  
  return self;
}

/*"Create schedules.  Assures that the output object writes the data when needed and checks to see if the required number of time steps has been completed"*/
- buildActions
{ 
  id agentlist;
  [super buildActions];
  
  [asmModelSwarm buildActions];

  if(loggingFrequency)
    {
      agentlist = [asmModelSwarm getAgentList];
       
      displayActions = [ActionGroup create: [self getZone]];
      [displayActions createActionTo: output message: M(writeCData)];
      [displayActions createActionTo: output     message: M(stepPlots)];			
	    
      displaySchedule = [Schedule createBegin: [self getZone]];
      [displaySchedule setRepeatInterval: loggingFrequency];
      displaySchedule = [displaySchedule createEnd];
      [displaySchedule at: 0 createAction: displayActions];
    }

  stopSchedule = [Schedule create: [self getZone]];
  [stopSchedule at: experimentDuration createActionTo: self message: M(stopRunning)];

  return self;
}

/*"activateIn: is required to preserve the hierarchy of schedules across many levels"*/
- activateIn: (id)swarmContext
{
  [super activateIn: swarmContext];
  [asmModelSwarm activateIn: self];

  [stopSchedule activateIn: self];
  if(loggingFrequency)
    [displaySchedule activateIn: self];
 
  return [self getSwarmActivity];
}


/*"Tell the objects that are keeping records on parameter values to write them to files at the end of the simulation."*/ 
- expostParamWrite
{
 [[asmModelSwarm getOutput] writeParams: [(id) arguments getModelParams] BFAgent: [(id) arguments getBFParams] Time: [asmModelSwarm getModelTime]]; 
  return self;
}


/*"Once schedules are created and activatedIn to the right part of the
  hierarchy, then go makes processing start with actions at time 0,
  then 1, then..."*/
-go
{
  printf("\nYou typed 'asm -batchmode'.  The simulation is running without graphics.\n\n");
  printf("The Artificial Stock Market is running for %d time steps and writing its data.\n\n",experimentDuration);
  if(loggingFrequency)
    printf("It is logging data every %d timesteps to a time-dated output.data file.\n\n",
	   loggingFrequency);

  [[self getActivity] run];
  return [[self getActivity] getStatus];
}
  
/*"tell the top level swarm to terminate the simulation"*/
-stopRunning
{
  [asmModelSwarm lispArchive: "end"];		
  [getTopLevelActivity() terminate];
  return self;
}


/*" The drop method lets objects know the simulation is coming to an
  end, so if they are waiting to write some data, they should do it"*/
-(void) drop
{
  [asmModelSwarm drop];
  [super drop];
}

@end











