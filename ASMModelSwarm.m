#import "ASMModelSwarm.h"
#import <simtools.h>
#import "Output.h"
#import "BFParams.h"
#import "BFCast.h"
#import <random.h>

#include <misc.h>


@implementation ASMModelSwarm
/*"The ASMModelSwarm is where the substantive work of the simulation
  is orchestrated.  The ASMModelSwarm object is told where to get its
  parameters, and then it buildsObjects (agents, markets, etc), it
  builds up a phony history of the market, and then it schedules the
  market opening and gives the agents a chance to buy and sell."*/

- createEnd
{
  modelTime=0; 
  //need to create output so it exists from beginning
  output = [[Output createBegin: [self getZone]] createEnd];
  return [super createEnd];
}


/*"This is very vital.  When the ASMModelSwarm is created, it needs to
 * be told where to find many constants that determine how agents are
 * created. This passes handles of objects that have the required
 * data."*/
- setParamsModel: (ASMModelParams *) modelParams BF: (BFParams *) bfp 
{
  bfParams = bfp;
  asmModelParams=modelParams;
  fprintf(stderr,"Param object %d ",asmModelParams->numBFagents);
  return self;
}

/*" Returns the number of BFagents,  which is held in asmModelParams"*/
- (int) getNumBFagents
{
  return asmModelParams->numBFagents;
}

/*" Returns the initialcash value, which is held in asmModelParams"*/
- (double) getInitialCash
{
  return asmModelParams->initialcash;
}
  
/*" Returns a list that contains all the agents"*/
- getAgentList
{
  return agentList;
}

/*" Returns a handle of the world object, the place where historical
  price/dividend information is maintained.  It is also the place
  where the BFagents can retrieve information in bit string form."*/
- (World *)getWorld
{
  if (world == nil) printf("Empty world!");
  return world;
}

/*" Return a pointer to the Specialist object"*/
- (Specialist *)getSpecialist
{
  return specialist;
}

/*" Return a pointer to an object of the Output class. Sometimes it is
  necessary for other classes to find out who the output record keeper
  is and send that class a message."*/
- (Output *)getOutput
{
  return output;
}


/*"
  Returns the integer time-step of the current simulation. 
  "*/
-(long int) getModelTime
{
  return modelTime;
}


/*"The value of the randomSeed that starts the simulation will remain
  fixed, unless you change it by using this method"*/
- setBatchRandomSeed: (int)newSeed
{
  asmModelParams->randomSeed = newSeed;
  return self;
}

/*"Build and initialize objects"*/
- buildObjects      
{
  int i;

  //  fprintf(stderr, "numBFagents  %d \n intrate  %f \n baseline %f \n eta %f \n initvar %f \n", asmModelParams->numBFagents,asmModelParams->intrate, asmModelParams->baseline, asmModelParams->eta, asmModelParams->initvar);

  if(asmModelParams->randomSeed != 0) 
    [randomGenerator setStateFromSeed: asmModelParams->randomSeed];
  //pj: note I'm making this like other swarm apps. Same each time, new seeds only if precautions taken.

 
  /* Initialize the dividend, specialist, and world (order is crucial) */
  dividendProcess = [Dividend createBegin: [self getZone]];
  [dividendProcess initNormal];
  [dividendProcess setBaseline: asmModelParams->baseline];
  [dividendProcess setmindividend: asmModelParams->mindividend];
  [dividendProcess setmaxdividend: asmModelParams->maxdividend];
  [dividendProcess setAmplitude: asmModelParams->amplitude];
  [dividendProcess setPeriod:asmModelParams-> period];
  [dividendProcess setDerivedParams];
  dividendProcess = [dividendProcess createEnd];

  world = [World createBegin: [self getZone]];
  [world setintrate: asmModelParams->intrate];
  [world setExponentialMAs: asmModelParams->exponentialMAs];
  [world initWithBaseline:asmModelParams-> baseline];
  world = [world createEnd];

  specialist = [Specialist createBegin: [self getZone]];
  [specialist setMaxPrice: asmModelParams->maxprice];
  [specialist setMinPrice: asmModelParams-> minprice];
  [specialist setTaup:asmModelParams-> taup];
  [specialist setSPtype: asmModelParams-> sptype];
  [specialist setMaxIterations: asmModelParams-> maxiterations];
  [specialist setMinExcess: asmModelParams->minexcess];
  [specialist setETA: asmModelParams-> eta];
  [specialist setREA: asmModelParams-> rea];
  [specialist setREB: asmModelParams->reb];
  [specialist setWorld: world];
  specialist = [specialist createEnd];

 
  [output setWorld: world];
  [output setSpecialist: specialist];
  
  /* Initialize the agent modules and create the agents */
  agentList = [List create: [self getZone]];  //create list for agents


  /* Set class variables */
  [BFagent init];
  [BFagent setBFParameterObject: bfParams];
  [BFagent setWorld: world];
    
  //nowObject create the agents themselves
  for (i = 0; i < asmModelParams->numBFagents; i++) 
    {
      BFagent * agent;
      agent = [BFagent createBegin: [self getZone]];
      [agent setID: i];
      [agent setintrate: asmModelParams->intrate];
      [agent setminHolding: asmModelParams->minholding   minCash:asmModelParams-> mincash];
      [agent setInitialCash: asmModelParams->initialcash];
      [agent setInitialHoldings];
      [agent setPosition: asmModelParams->initholding];
      [agent initForecasts];
      agent = [agent createEnd];
      [agentList addLast: agent];
    }
      
  //Give the specialist access to the agentList
  [specialist setAgentList: agentList];
  return self;
}

/*"This triggers a writing of the model parameters, for record keeping."*/
- writeParams
{
   if (asmModelParams != nil && bfParams != nil)
    [output writeParams: asmModelParams BFAgent: bfParams Time: modelTime];
  return self;
}


/*"Create the model actions, separating into two different action
 * groups, the warmup period and the actual period.  Note that time is
 * not calculated by a t counter but internally within Swarm.  Time is
 * recovered by the getTime message"*/

- buildActions
{
  [super buildActions];

  warmupActions = [ActionGroup create: [self getZone]];

//Set the new dividend.  This method is defined below.   
  [warmupActions createActionTo:     self
		 message: M(warmupStepDividend)];
  
// Update world -- moving averages, bits, etc
  [warmupActions createActionTo:     world      
		 message: M(updateWorld)];

//Fake price setting (crude fundamental value)
  [warmupActions createActionTo:     self
		 message: M(warmupStepPrice)];

//Define the actual period's actions.  
  periodActions = [ActionGroup create: [self getZone]];

//Set the new dividend.  This method is defined below. 
  [periodActions createActionTo:     self
		 message: M(periodStepDividend)];

// Tell agents to credit their earnings and pay taxes
  [periodActions createActionForEach:    agentList     
		 message: M(creditEarningsAndPayTaxes)];

// Update world -- moving averages, bits, etc
  [periodActions createActionTo:     world     
		 message: M(updateWorld)];

// Tell BFagent class to prepare for trading
  //pj:   [periodActions createActionTo:     self    
  //pj:		   message: M(prepareBFagentForTrading)];

// Tell BFagents to get ready for trading (they may run GAs here)
  [periodActions createActionForEach:     agentList
		   message: M(prepareForTrading)];

// Do the trading -- agents make bids/offers at one or more trial prices
// and price is set.  This is defined below.
  [periodActions createActionTo:     self
		 message: M(periodStepPrice)];

// Complete the trades -- change agents' position, cash, and profit
  [periodActions createActionTo:     specialist     
		 message: M(completeTrades)];

// Tell the agents to update their performance
  [periodActions createActionForEach: agentList     
		 message: M(updatePerformance)];

// Create the model schedule
  warmupSchedule = [Schedule createBegin: [self getZone]];
  [warmupSchedule setRepeatInterval: 1];
  warmupSchedule = [warmupSchedule createEnd];
  [warmupSchedule at: 0 createAction: warmupActions];

  startupSchedule = [Schedule create: [self getZone] setAutoDrop: YES];
  [startupSchedule at: 0 createActionTo: self message: M(warmUp:):warmupSchedule];
  
  initPeriodSchedule = [Schedule createBegin: [self getZone]];
  [initPeriodSchedule setRepeatInterval: 1];
  initPeriodSchedule = [initPeriodSchedule createEnd];
  [initPeriodSchedule at: 0 createAction: periodActions];
  
  [startupSchedule at: 0 createActionTo: self 
		   message: M(initPeriod:):initPeriodSchedule];
  	      
  periodSchedule = [Schedule createBegin: [self getZone]];
  [periodSchedule setRepeatInterval: 1];
  periodSchedule = [periodSchedule createEnd];
  [periodSchedule at: 0 createAction: periodActions];

  return self;
}

- (void) warmUp: x
{
  id warmupSwarm;
  id warmupActivity;
  id terminateSchedule;

  warmupSwarm = [Swarm create: globalZone];
  [warmupSwarm activateIn: nil];
  warmupActivity = [x activateIn: warmupSwarm];
  
  terminateSchedule = [Schedule create: globalZone];
  [terminateSchedule activateIn: warmupSwarm];
  [terminateSchedule at: 501 createActionTo: warmupActivity
		     message: M(terminate)];
      
  while ([[warmupSwarm getSwarmActivity] run] != Completed);
  [warmupSwarm drop];
  [terminateSchedule drop];
}


- (void)initPeriod: x
{
  id warmupSwarm;
  id initPeriodActivity;
  id terminateSchedule;

  warmupSwarm = [Swarm create: globalZone];
  [warmupSwarm activateIn: nil];
  initPeriodActivity = [x activateIn: warmupSwarm];
  
  terminateSchedule = [Schedule create: globalZone];
  [terminateSchedule activateIn: warmupSwarm];
  [terminateSchedule at: 0 createActionTo:  initPeriodActivity
		     message: M(terminate)];
      
  while ([[warmupSwarm getSwarmActivity] run] != Completed);
  [warmupSwarm drop];
  [terminateSchedule drop];
}
		



-warmupStepDividend 
{
  [world setDividend: [dividendProcess dividend]];
  return self; 
}


-warmupStepPrice 
{
  // fprintf(stderr," Dividend %f \n", [world getDividend]);
  // fprintf(stderr," setPrice %f \n", [world getDividend]/asmModelParams->intrate );

  //  fprintf(stderr, "numBFagents  %d \n intrate  %f \n baseline %f \n eta %f \n initvar %f \n",
  //  asmModelParams->numBFagents,asmModelParams->intrate, asmModelParams->baseline, asmModelParams->eta, asmModelParams->initvar);

  [world setPrice: ([world getDividend]/(double)asmModelParams->intrate )];
  return self;
}	 

/*" Have the dividendProcess calculate a new dividend. Then tell the
  world about the dividendProcess output.  Also this increment the
  modelTime variable"*/
-periodStepDividend 
{
  modelTime++;
  [world setDividend: [dividendProcess dividend]];
  return self;
}

/*"Have the Specialist perform the trading process. Then tell the world about the price that resulted from the Specialist's action."*/
-periodStepPrice 
{
  [world setPrice: [specialist performTrading]];
  return self;
}

/*"The activities of the ASMModelSwarm are brought into time-sync with
  higher level Swarm activities. Basically, each time the higher level
  takes a step, this one will too, and the higher one won't step again
  until this one is finished with its turn."*/
-activateIn: (id)swarmContext
{
  [super activateIn: swarmContext];
  [startupSchedule activateIn: self];
  [periodSchedule activateIn: self];
  return [self getSwarmActivity];
}

-(void) drop
{
  [dividendProcess drop];
  [world drop];
  [specialist drop];
  [output drop];
  [super drop];
}

@end











