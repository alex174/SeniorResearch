#import "ASMModelSwarm.h"
#import <simtools.h>
#import "Output.h"
//#import "random.h"
#import "BFParams.h"
#import "BFCast.h"

#import <random.h>

#include <misc.h>



@implementation ASMModelSwarm

+createBegin: (id)aZone
{
  ASMModelSwarm * obj;
  id <ProbeMap> probeMap;

  obj = [super createBegin: aZone];

  obj->numBFagents = 30;
  obj->initholding = 1;
  obj->initialcash = 10000;
  obj->minholding = 0;
  obj->mincash = 0;
  obj->intrate = 0.1;
  obj->baseline = 10;
  obj->mindividend = 0.00005;
  obj->maxdividend = 100;
  obj->amplitude = 0.14178;
  obj->period = .99;
  obj->maxprice = 500;
  obj->minprice = 0.001;
  obj->taup = 50.0;
  obj->exponentialMAs = 1;
  obj->sptype = 2;                   //0 = REE, 1 = SLOPE, 2 = ETA
  obj->maxiterations = 10;
  obj->minexcess = 0.01;
  obj->eta = 0.0005;
  obj->etamax = 0.05;
  obj->etamin = 0.00001;
  obj->rea = 9.0;
  obj->reb = 2.0;
  obj->randomSeed = 0;
 
  //BFagent lambda and initvar set internally
  obj->tauv = 50.0;
  obj->lambda = 0.3;               
  obj->maxbid = 10.0;
  obj->initvar = .4000212;
  obj->maxdev = 100;
    
// Build probes here.
  probeMap = [EmptyProbeMap createBegin: aZone];
  [probeMap setProbedClass: [self class]];
  probeMap = [probeMap createEnd];
  
  [probeMap addProbe: [probeLibrary getProbeForVariable: "numBFagents"
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "initholding"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "initialcash"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "minholding"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "mincash"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "intrate"
  			            inClass: [self class]]];

  [probeMap addProbe: [probeLibrary getProbeForVariable: "baseline"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "mindividend"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxdividend"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "amplitude"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "period"
  			            inClass: [self class]]];

  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxprice"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "minprice"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "taup"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "exponentialMAs" 
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "sptype"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxiterations" 
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "minexcess"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "eta"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "etamin"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "etamax"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "rea"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "reb"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "randomSeed"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "tauv"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "lambda"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxbid"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "initvar"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxdev"
  			            inClass: [self class]]];
  [probeLibrary setProbeMap: probeMap For: [self class]];
   
  return obj;
}  


-initOutputForParamWrite
{
  [output setNumBFagents: numBFagents];
  [output setInitHolding: initholding];
  [output setInitialCash: initialcash];
  [output setminHolding: minholding   minCash: mincash];
  [output setIntRate: intrate];

  [output setBaseline: baseline];
  [output setmindividend: mindividend];
  [output setmaxdividend: maxdividend];
  [output setTheAmplitude: amplitude];
  [output setThePeriod: period];

  [output setExponentialMAs: exponentialMAs];

  [output setMaxPrice: maxprice];
  [output setMinPrice: minprice];
  [output setTaup: taup];
  [output setSPtype: sptype];
  [output setMaxIterations: maxiterations];
  [output setMinExcess: minexcess];
  [output setETA: eta];
  [output setETAmin: etamin];
  [output setETAmax: etamax];
  [output setREA: rea];
  [output setREB: reb];
  [output setSeed: randomSeed];

  [output setTauv: tauv];
  [output setLambda: lambda];
  [output setMaxBid: maxbid];
  [output setInitVar: initvar];
  [output setMaxDev: maxdev];
  
  return self;
}
  

-createEnd
{
  return [super createEnd];
}


-(int)getNumBFagents
{
  return numBFagents;
}


-(double)getInitialCash
{
  return initialcash;
}
  

-getAgentList
{
  return agentList;
}


-(World *)getWorld
{
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
  randomSeed = newSeed;
  return self;
}


-buildObjects        //Build and initialize all objects
{
  int i;
  id bfParams;

/* Initialise random number stream (0 means set randomly) */
  //pj
  //randomSeed = randset(randomSeed);	// returns actual seed if 0

   if(randomSeed != 0) [randomGenerator setStateFromSeed: randomSeed];
   //pj: note I'm making this like other swarm apps. Same each time, new seeds only if precautions taken.

  
/* Initialize the dividend, specialist, and world (order is crucial) */
  dividendProcess = [Dividend createBegin: [self getZone]];
  [dividendProcess initNormal];
  [dividendProcess setBaseline: baseline];
  [dividendProcess setmindividend: mindividend];
  [dividendProcess setmaxdividend: maxdividend];
  [dividendProcess setAmplitude: amplitude];
  [dividendProcess setPeriod: period];
  [dividendProcess setDerivedParams];
  dividendProcess = [dividendProcess createEnd];

  world = [World createBegin: [self getZone]];
  [world setintrate: intrate];
  [world setExponentialMAs: exponentialMAs];
  [world initWithBaseline: baseline];
  world = [world createEnd];

  specialist = [Specialist createBegin: [self getZone]];
  [specialist setMaxPrice: maxprice];
  [specialist setMinPrice: minprice];
  [specialist setTaup: taup];
  [specialist setSPtype: sptype];
  [specialist setMaxIterations: maxiterations];
  [specialist setMinExcess: minexcess];
  [specialist setETA: eta];
  [specialist setETAmin: etamin];
  [specialist setETAmax: etamax];
  [specialist setREA: rea];
  [specialist setREB: reb];
  [specialist init];
  [specialist setWorld: world];
  specialist = [specialist createEnd];

  output = [Output create: [self getZone]];
  if (setOutputForData == 1) 
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
               "Can't find the modelSwarm parameters");
   [bfParams init];

   [BFCast init];

   [BFagent setBFParameterObject: bfParams];
   //[BFagent init];
   [BFagent setWorld: world];
    
//nowObject create the agents themselves
      for (i = 0; i < numBFagents; i++) 
	{
	  BFagent * agent;
	  agent = [BFagent createBegin: [self getZone]];
	  [agent setID: i];
	  [agent setintrate: intrate];
	  [agent setminHolding: minholding   minCash: mincash];
	  [agent setInitialCash: initialcash];
	  [agent setInitialHoldings];
	  [agent setPosition: initholding];
	  [agent initForecasts];
	  agent = [agent createEnd];
	  [agentList addLast: agent];
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
  [periodActions createActionTo:     self    
		   message: M(prepareBFagentForTrading)];

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
  [periodActions createActionForEach:     agentList     
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
  [world setPrice: [world getDividend]/intrate];
  return self;
}	 

	 
-periodStepDividend 
{
  [world setDividend: [dividendProcess dividend]];
  return self;
}


-prepareBFagentForTrading
{
  [BFagent prepareForTrading];
  return self;
}


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











