#import "ASMModelSwarm.h"
#import <simtools.h>
#import "Output.h"
//#import "random.h"
#import "BFParams.h"
#import "BFCast.h"
#import <random.h>

#include <misc.h>
#include <defobj.h>  //for archiver



@implementation ASMModelSwarm

//  +createBegin: (id)aZone
//  {
//    ASMModelSwarm * obj;
//    //  id <ProbeMap> probeMap;

//    obj = [super createBegin: aZone];
 

   
//    return obj;
//  }  

- setParamObject: (ASMModelParams *) modelParams
{
  asmModelParams=modelParams;
  fprintf(stderr,"Param object %d ",asmModelParams->numBFagents);
  return self;
}


-createEnd
{
  return [super createEnd];
}


-(int)getNumBFagents
{
  return asmModelParams->numBFagents;
}


-(double)getInitialCash
{
  return asmModelParams->initialcash;
}
  

-getAgentList
{
  return agentList;
}


-(World *)getWorld
{
  if (world == nil) printf("Empty world!");
  return world;
}


-(Specialist *)getSpecialist
{
  return specialist;
}


-(Output *)getOutput
{
  return output;
}


-setBatchRandomSeed: (int)newSeed
{
  
  asmModelParams->randomSeed = newSeed;
  return self;
}


-buildObjects        //Build and initialize all objects
{
  int i;
  id bfParams;

  //pj
  //randomSeed = randset(randomSeed);	// returns actual seed if 0

  fprintf(stderr, "numBFagents  %d \n intrate  %f \n baseline %f \n eta %f \n initvar %f \n",
	  asmModelParams->numBFagents,asmModelParams->intrate, asmModelParams->baseline, asmModelParams->eta, asmModelParams->initvar);

 
#ifndef USE_LISP
  unlink ("output.hdf");
  archiver = [HDF5Archiver create: self setPath: "output.hdf"];
#else
  unlink ("output.scm");
  archiver = [LispArchiver create: self setPath: "output.scm"];
#endif

  asmModelParams->exponentialMAs = 1; 

   if(asmModelParams->randomSeed != 0) [randomGenerator setStateFromSeed: asmModelParams->randomSeed];
   //pj: note I'm making this like other swarm apps. Same each time, new seeds only if precautions taken.


   [archiver putShallow: "someModelOutput" object: asmModelParams];
#ifdef USE_LISP
   [archiver sync];
#endif

  
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
  //  [specialist setETAmin: asmModelParams-> etamin]; pj: was unused
  //   [specialist setETAmax: asmModelParams->etamax]; pj: was unused
  [specialist setREA: asmModelParams-> rea];
  [specialist setREB: asmModelParams->reb];
  // [specialist init];
  [specialist setWorld: world];
  specialist = [specialist createEnd];

  output = [Output create: [self getZone]];
  if (asmModelParams->setOutputForData == 1) 
    {
      [output setWorld: world];
      [output setSpecialist: specialist];
      [output prepareOutputFile];
    }
/* Initialize the agent modules and create the agents */
  agentList = [List create: [self getZone]];  //create list for agents
  
  if ((bfParams =
       [lispAppArchiver getWithZone: self key: "bfParams"]) == nil)
    raiseEvent(InvalidOperation,
               "Can't find the BFParam's parameters");
   [bfParams init];

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
	  fprintf(stderr,"birthed %d",i);
	}
      
      //  [BFagent didInitialize];
    
  
//Give the specialist access to the agentList
  [specialist setAgentList: agentList];
  return self;
}


-initOutputForDataWrite
{
  setOutputForData = 1;
  return self;
}


//Create the model actions, separating into two different action groups, the 
//warmup period and the actual period.  Note that time is not calculated
//by a t counter but internally within Swarm.  Time is recovered by the 
//getTime message
-buildActions
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

  startupSchedule = [Schedule create: [self getZone]];
  [startupSchedule at: 0 createActionCall: 
		     (func_t)warmUp: warmupSchedule];
  
  initPeriodSchedule = [Schedule createBegin: [self getZone]];
  [initPeriodSchedule setRepeatInterval: 1];
  initPeriodSchedule = [initPeriodSchedule createEnd];
  [initPeriodSchedule at: 0 createAction: periodActions];
  
  [startupSchedule at: 0 createActionCall: 
  	     (func_t)initPeriod: initPeriodSchedule];
  
  periodSchedule = [Schedule createBegin: [self getZone]];
  [periodSchedule setRepeatInterval: 1];
  periodSchedule = [periodSchedule createEnd];
  [periodSchedule at: 0 createAction: periodActions];

  return self;
}


void warmUp (id warmupSchedule)
{
  id warmupSwarm;
  id warmupActivity;
  id terminateSchedule;

  warmupSwarm = [Swarm create: globalZone];
  [warmupSwarm activateIn: nil];
  warmupActivity = [warmupSchedule activateIn: warmupSwarm];
  
  terminateSchedule = [Schedule create: globalZone];
  [terminateSchedule activateIn: warmupSwarm];
  [terminateSchedule at: 501 createActionTo: warmupActivity
		     message: M(terminate)];
      
  while ([[warmupSwarm getSwarmActivity] run] != Completed);
}

void initPeriod (id initPeriodSchedule)
{
  id warmupSwarm;
  id initPeriodActivity;
  id terminateSchedule;

  warmupSwarm = [Swarm create: globalZone];
  [warmupSwarm activateIn: nil];
  initPeriodActivity = [initPeriodSchedule activateIn: warmupSwarm];
  
  terminateSchedule = [Schedule create: globalZone];
  [terminateSchedule activateIn: warmupSwarm];
  [terminateSchedule at: 0 createActionTo:  initPeriodActivity
		     message: M(terminate)];
      
  while ([[warmupSwarm getSwarmActivity] run] != Completed);
}
		

-warmupStepDividend 
{
  [world setDividend: [dividendProcess dividend]];
  return self; 
}


-warmupStepPrice 
{
  fprintf(stderr," Dividend %f \n", [world getDividend]);
  fprintf(stderr," setPrice %f \n", [world getDividend]/asmModelParams->intrate );

  fprintf(stderr, "numBFagents  %d \n intrate  %f \n baseline %f \n eta %f \n initvar %f \n",
	  asmModelParams->numBFagents,asmModelParams->intrate, asmModelParams->baseline, asmModelParams->eta, asmModelParams->initvar);

  [world setPrice: ([world getDividend]/(double)asmModelParams->intrate )];
  return self;
}	 

	 
-periodStepDividend 
{
  [world setDividend: [dividendProcess dividend]];
  return self;
}


//-prepareBFagentForTrading
//pj:{
  //pj:[BFagent prepareForTrading];
//pj:  return self;
//pj:}


-periodStepPrice 
{
  [world setPrice: [specialist performTrading]];
  return self;
}


-activateIn: (id)swarmContext
{
  [super activateIn: swarmContext];
  [startupSchedule activateIn: self];
  [periodSchedule activateIn: self];
  return [self getSwarmActivity];
}

@end











