#import "ASMModelSwarm.h"
#import <simtools.h>
#import "Output.h"
#import "BFParams.h"
#import "Parameters.h"
#import "BFagent.h"
#import <random.h>


#include <misc.h>


@implementation ASMModelSwarm
/*"The ASMModelSwarm is where the substantive work of the simulation
  is orchestrated.  The ASMModelSwarm object is told where to get its
  parameters, and then it buildsObjects (agents, markets, etc), it
  builds up a phony history of the market, and then it schedules the
  market opening and gives the agents a chance to buy and sell.
  
 This model presents an interesting scheduling challenge. We want to
  generate 501 periods of history that agents can refer to when they
  make decisions.  The warmUp schedule is a repeating schedule, and we
  want its actions done 501 times, and when that is finished, we want
  the periodSchedule to begin at time 0, the starting time of actual
  agent involvement.  When I looked at the original, I shuddered at
  the complexity of it.  I thought to myself, there must be a simpler
  way to do this [grin :)], and it turns out there is.  Now, in case
  you are comparing the new code against the old code, understand that
  the old ASM-2.0 way was like this.  First, the warmUp schedule is
  created.  Then a second nonrepeating schedule is created, called
  "startupSchedule."  At time 0 in the model, that startupSchedule
  controls the first action, and the action it executes is a method
  that causes the warmUp schedule to run 501 steps of prehistory. I
  don't know why they had 501 steps, but they did.  That's the warmUp
  method.  The warmUp method gets that done by creating a temporary
  Swarm class without any context (activateIn: nil) and then
  activating the startupSchedule in there, so it runs "doWarmupStep"
  501 steps, but none of the 501 steps count against time in the
  larger context of the model.


  As of ASM-2.2, I have gotten rid of that complicated setup. Instead
  of creating the phony swarm and activating the warmup schedule
  inside it, I created a method in ASMModelSwarm.m that carries out
  one time step's worth of warmup.  And then I dumped 501
  createActionTo methods on the startup schedule that execute the
  required startup steps.  I've verified the results are numerically
  identical to the original model.  And the scheduling is much easier
  to understand.

  After the warmUp, then an ActionGroup called "periodActions" comes
  to the forefront.  The periodSchedule is a repeating schedule, which
  causes the periodActions to happen at every time step in the larger
  model.

  In ASM-2.0, there was another initial schedule called
  initPeriodSchedule.  After looking at it for a long time, I
  concluded it was doing nothing necessary, it was basically just
  running the periodActions at time 0 only. We might as well just
  schedule that action at time 0 in the startupSchedule. I have
  verified that the model runs exactly the same (numerically
  identical).  Now, as noted below, I think this step is logically
  unnecessary, but removing it changes the numerical path of the
  simulation, so I'm leaving it in for comparison.  "*/

- createEnd
{
  modelTime=0; 

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
  fprintf(stderr,"Param object %d \n\n",asmModelParams->numBFagents);
  return self;
}

- setOutputObject: (Output *) obj
{
  output = obj;
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
- (long int)getModelTime
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

  if(asmModelParams->randomSeed != 0) 
    [randomGenerator setStateFromSeed: asmModelParams->randomSeed];
  else
    asmModelParams->randomSeed = [randomGenerator getInitialSeed];
  
  //pj: note I'm making this like other swarm apps. Same each time,
  //new seeds only if precautions taken.

 
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

  if (![(Parameters *)arguments getFilename])
   {
     world = [World createBegin: [self getZone]];
     [world setintrate: asmModelParams->intrate];
     [world setExponentialMAs: asmModelParams->exponentialMAs];
     [world initWithBaseline:asmModelParams-> baseline];
     world = [world createEnd];
   }
 else
    {
      [self lispLoadWorld: [(Parameters *)arguments getFilename]];
    }

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
  specialist = [specialist createEnd];
 


  [output setWorld: world];
  [output setSpecialist: specialist];
 

  /* Set class variables */
  [BFagent init];
  [BFagent setBFParameterObject: bfParams];
  [BFagent setWorld: world];


  if (![(Parameters *)arguments getFilename])
   {
     
     /* Initialize the agent modules and create the agents */
     agentList = [List create: [self getZone]];  //create list for agents

     [self createAgents];
   }
  
  else
    {
      [self lispLoadAgents: [(Parameters *)arguments getFilename]];
    }

  [output setAgentlist: agentList];
  return self;
}

/*"Create agents, when they are not loaded in serialized form"*/
- createAgents
{
  int i;

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
      [agent setAgentList: agentList];
      agent = [agent createEnd];
      [agentList addLast: agent];
    }
  return self;
}




- lispArchive: (char *)inputName
{
  char dataArchiveName[100];
  if (!inputName)
    snprintf(dataArchiveName,100,"%s%d-%s.scm","run",getInt(arguments,"run"),"blah");
  else
    snprintf(dataArchiveName,100,"%s%d-%s.scm","run",getInt(arguments,"run"),inputName);
  id dataArchiver = [LispArchiver create: [self getZone] setPath: dataArchiveName];

  [dataArchiver putShallow: "asmModelParams" object: asmModelParams];
  [dataArchiver putShallow: "bfParams" object: bfParams];
  [dataArchiver putDeep: "world" object: world];
  [dataArchiver putDeep: "agentList" object: agentList];

  //  [dataArchiver putShallow: "parameters" object: parameters];

  [dataArchiver sync];
  [dataArchiver drop];

  return self;
}




- lispLoadAgents: (const char *)lispfile
{
  id <Index> index;
  id anAgent;
  id archiver = [LispArchiver create: [self getZone] setPath: lispfile];
  agentList = [archiver getObject: "agentList"];
  
  [archiver drop];
  
  index = [agentList begin: self];
  for (anAgent=[index next]; [index getLoc]==Member; anAgent= [index next])
    {
      [anAgent setAgentList: agentList];
      printf ("ID IS %d", [anAgent getID]);
    }

  return self;
}


- lispLoadWorld: (const char *)lispfile
{
  id archiver = [LispArchiver create: [self getZone] setPath: lispfile];
  world = [archiver getObject: "world"];
  
  [archiver drop];
  
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

  //Define the actual period's actions.  
  periodActions = [ActionGroup create: [self getZone]];

  //Set the new dividend.  This method is defined below. 
  [periodActions createActionTo: self  
		 message: M(periodStepDividend)];

  // Tell agents to credit their earnings and pay taxes.
  [periodActions createActionTo: self 
		 message: M(creditAgentEarningsAndPayTaxes)];

  [periodActions createActionTo: world  
		 message: M(updateWorld)];

  // Tell BFagents to get ready for trading (they may run GAs here)
  [periodActions createActionTo: self 
		 message: M(prepareAgentsForTrading)];

  // Do the trading -- agents make bids/offers at one or more trial
  // prices and price is set.  This is defined below.
  [periodActions createActionTo:     self
		 message: M(periodStepPrice)];

  // Complete the trades -- change agents' position, cash, and profit
  [periodActions createActionTo:     specialist     
		 message: M(completeTrades:Market:):agentList:world];

  
  // Another way to tell agents to update their performance, equally fast
  [periodActions createActionTo: self 
		 message: M(updateAgentPerformance)];


     startupSchedule = [Schedule create: [self getZone] setAutoDrop: YES];


  if (![(Parameters *)arguments getFilename])
   {
     //force the system to do 501 "warmup steps" at the beginning of the
     //startup Schedule.  Note that, since these phony steps are just
     //handled by telling classes to do the required steps, nothing fancy
     //is required.
     {
       int i;
       for (i = 0; i < 501; i++)
	 [startupSchedule at: 0 createActionTo: self message:M(doWarmupStep)];
     }
   } 
  
  periodSchedule = [Schedule createBegin: [self getZone]];
  [periodSchedule setRepeatInterval: 1];
  periodSchedule = [periodSchedule createEnd];
  [periodSchedule at: 0 createAction: periodActions];
  
  return self;
}



- (void)updateAgentPerformance
{
  id index = [agentList begin: self];
  id anAgent;
  for (anAgent = [index next]; [index getLoc]==Member; anAgent= [index next])
    {
      [anAgent updatePerformance];
    }
   [index drop];
}


- (void)prepareAgentsForTrading
{
  id index = [agentList begin: self];
  id anAgent;
  for (anAgent = [index next]; [index getLoc]==Member; anAgent= [index next])
    {
      [anAgent prepareForTrading];
    }
  [index drop];
}



- (void)creditAgentEarningsAndPayTaxes
{
  id index = [agentList begin: self];
  id anAgent;
  for (anAgent = [index next]; [index getLoc]==Member; anAgent= [index next])
    {
      [anAgent creditEarningsAndPayTaxes ];
    }
  [index drop];
}


/*"Ask the dividend object for a draw from the dividend distribution, then tell the world about it. Tell the world to do an update of to respond to the dividend. Then calculate the price the divident implies and insert it into the world"*/
- doWarmupStep
{
  double div = [dividendProcess dividend];
  [world setDividend: div];
  [world updateWorld];
  [world setPrice: (div/(double)asmModelParams->intrate )];
  return self;
}

/*" Have the dividendProcess calculate a new dividend. Then tell the
  world about the dividendProcess output.  Also this increment the
  modelTime variable"*/
- periodStepDividend 
{
  modelTime++;
  [world setDividend: [dividendProcess dividend]];
  return self;
}

/*"Have the Specialist perform the trading process. Then tell the world about the price that resulted from the Specialist's action."*/
- periodStepPrice 
{
  [world setPrice: [specialist performTrading: agentList Market: world]];
  return self;
}

/*"The activities of the ASMModelSwarm are brought into time-sync with
  higher level Swarm activities. Basically, each time the higher level
  takes a step, this one will too, and the higher one won't step again
  until this one is finished with its turn."*/
- activateIn: (id)swarmContext
{
  [super activateIn: swarmContext];
  [startupSchedule activateIn: self];
  [periodSchedule activateIn: self];
  return [self getSwarmActivity];
}

- (void)drop
{
  [dividendProcess drop];
  [world drop];
  [specialist drop];
  [output drop];
  [super drop];
}




@end











