#import "ASMObserverSwarm.h"
#import <simtoolsgui.h>
#import "Parameters.h"

#include <misc.h>


@implementation ASMObserverSwarm

/*" The ASMObserverSwarm is a Swarm with a graphical user interface
  (GUI).  It follows the prototype Swarm model, in that the Observer
  Swarm is thought of an entity that can describe or report on the
  state of a simulation, but not interact with it.  The Observer
  causes the ASMModelSwarm to be created, and it monitors various
  variables by checking directly with the agents.

  Note that the ASMObserverSwarm has a set of "standard" methods that
  Swarms have--buildObjects:, buildActions, activateIn:--and inside
  each one it makes sure that the next-lower level, the ASMModelSwarm,
  is sent the same message.

  If you don't want to watch the GUI, run the model in batch mode,
  meaning you use the -b flag on the command line.

  "*/


+ createBegin: aZone 
{
  ASMObserverSwarm *obj;
  id <ProbeMap> probeMap;

  obj = [super createBegin: aZone];
  obj->displayFrequency = 3;

  probeMap = [EmptyProbeMap createBegin: aZone];
  [probeMap setProbedClass: [self class]];
  probeMap = [probeMap createEnd];
 
  [probeMap addProbe: [probeLibrary getProbeForVariable: "displayFrequency"
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForMessage: 
		      "writeSimulationParams" inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForMessage: 
		      "toggleDataWrite" inClass: [self class]]];

  //The member functions that allow you to print a graph. 
#if 0
  [probeMap addProbe: [probeLibrary getProbeForMessage: 
		      "printPriceGraph" inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForMessage: 
		      "printVolumeGraph" inClass: [self class]]];
  //  [probeMap addProbe: [probeLibrary getProbeForMessage: 
  //	      "printDeviationGraph" inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForMessage: 
		      "printRelWealthHisto" inClass: [self class]]];
#endif
  [probeLibrary setProbeMap: probeMap For: [self class]];

  return obj;
}

#if 0

/*"This is a legacy method. We need to update Swarm if it is ever to work again"*/
- printPriceGraph
{
  [globalTkInterp eval: 
    "%s postscript output priceDump.eps -maxpect yes -decorations no",
    [priceGraph getWidgetName]];
  return self;
}


/*"This is a legacy method. We need to update Swarm if it is ever to work again"*/
- printVolumeGraph
{
  [globalTkInterp eval: 
    "%s postscript output volumeDump.eps -maxpect yes -decorations no",
    [volumeGraph getWidgetName]];
  return self;
}

/*"This is a legacy method. We need to update Swarm if it is ever to work again"*/
- printDeviationGraph
{
  [globalTkInterp eval: 
    "%s postscript output deviationDump.eps -maxpect yes -decorations no",
    [deviationGraph getWidgetName]];
  return self;
}

/*"This is a legacy method. We need to update Swarm if it is ever to work again"*/
- printRelWealthHisto
{
  [globalTkInterp eval: 
    "%s postscript output relWealthDump.eps -maxpect yes -decorations no",
    [relativeWealthHisto getWidgetName]];
  return self;
}
#endif

- createEnd 
{
  return [super createEnd];
}

/*"This creates the model swarm, and then creates a number of
  monitoring objects, such a graphs which show the price trends,
  volume of stock trade, and some excellent bar charts which show the
  holdings and wealth of the agents.  These bar charts (histograms)
  are available in very few other Swarm programs and if you want to
  know how it can be done, feel free to take a look!"*/
- buildObjects 
{
  int numagents;

  //need to create output and parameters so they exist from beginning
  ASMModelParams * asmModelParams = [(id)arguments getModelParams];
  BFParams * bfParams = [(id)arguments getBFParams];
  output = [[Output createBegin: self] createEnd];
  
  [super buildObjects];
  asmModelSwarm = [ASMModelSwarm create: self]; 
  [asmModelSwarm setOutputObject: output];

  CREATE_ARCHIVED_PROBE_DISPLAY (self);
  CREATE_ARCHIVED_PROBE_DISPLAY (asmModelParams);
  CREATE_ARCHIVED_PROBE_DISPLAY (bfParams);
  [controlPanel setStateStopped];

  // Don't set the parameter objects until the model starts up That
  // way, any changes typed into the gui will be taken into account by
  // the model.
  [asmModelSwarm setParamsModel: asmModelParams BF: bfParams];
  [asmModelSwarm buildObjects];

  numagents = asmModelParams->numBFagents;

  priceGraph = [EZGraph create: self setTitle: "Price v. time"
			setAxisLabelsX: "time" Y: "price"
			setWindowGeometryRecordName: "priceGraph"];
  [priceGraph enableDestroyNotification: self
	      notificationMethod: @selector (_priceGraphDeath_:)];
  [priceGraph createSequence: "actual price" 
	      withFeedFrom: [asmModelSwarm getWorld]
	      andSelector: M(getPrice)];
  [priceGraph createSequence: "risk neutral price"
	      withFeedFrom: [asmModelSwarm getWorld]
	      andSelector: M(getRiskNeutral)];
  

  volumeGraph = [EZGraph create: self setTitle: "Volume v. time"
			setAxisLabelsX: "time" Y: "volume"
			setWindowGeometryRecordName: "volumeGraph"];
  
  [volumeGraph createSequence: "actual volume"
	       withFeedFrom: [asmModelSwarm getSpecialist]
	       andSelector: M(getVolume)];
  
  [priceGraph enableDestroyNotification: self
	      notificationMethod: @selector (_volumeGraphDeath_:)];

  positionHisto = [Histogram createBegin: [self getZone]];
  SET_WINDOW_GEOMETRY_RECORD_NAME (positionHisto);
  [positionHisto setBinCount: numagents];
  positionHisto = [positionHisto createEnd];

  [positionHisto setWidth: 500 Height: 250];
  [positionHisto hideLegend];
  [positionHisto setTitle: "Agent Position"];
  [positionHisto setAxisLabelsX: "agents" Y: "position"];
  [positionHisto pack];

  [positionHisto enableDestroyNotification: self
		 notificationMethod: @selector (_positionHistoDeath_:)];


  //Again, you can add this back.
  //cashHisto = [Histo create: [self getZone]];
  //[cashHisto setWidth: 500 Height: 250];
  //[cashHisto setNumPoints: numagents  Labels: NULL  Colors: NULL];
  //[globalTkInterp eval: "%s legend configure -mapped no", 
  //		  [cashHisto getWidgetName]];
  //[cashHisto title: "Agent Cash Holdings"];
  //[cashHisto axisLabelsX: "agents" Y: "cash holding"];
  //[cashHisto pack];

  relativeWealthHisto = [Histogram createBegin: [self getZone]];
  SET_WINDOW_GEOMETRY_RECORD_NAME (relativeWealthHisto);
  [relativeWealthHisto setBinCount: numagents];
  relativeWealthHisto = [relativeWealthHisto createEnd];

  [relativeWealthHisto setWidth: 500 Height: 250];
  [relativeWealthHisto hideLegend];
  [relativeWealthHisto setTitle: "Relative Wealth of Agents"];
  [relativeWealthHisto setAxisLabelsX: "agents" Y: "relative wealth"];
  [relativeWealthHisto pack];
  
  [relativeWealthHisto enableDestroyNotification: self
		 notificationMethod: @selector (_relativeWealthHistoDeath_:)];
  //Only interesting to compare multiple agents.
  //deviationGraph = [Graph createBegin: [self getZone]];
  //SET_WINDOW_GEOMETRY_RECORD_NAME (deviationGraph);
  //deviationGraph = [deviationGraph createEnd];
 
  //[deviationGraph setTitle: "Mean Abs Dev of Different Agents"];
  //[deviationGraph setAxisLabelsX: "time" Y: "mean abs dev/actual p+d"];
  //[deviationGraph setRangesYMin: 0.0 Max: 200.0];
  //[deviationGraph pack];

  
  //deviationData = [deviationGraph createElement];
  //[[deviationData setLabel: "BF"] setColor: "green"];

  //deviationAverager = [Averager createBegin: [self getZone]];
  //[deviationAverager setCollection: [asmModelSwarm getAgentList]];
  //[deviationAverager setProbedSelector: M(getDeviation)];
  //deviationAverager = [deviationAverager createEnd];
      
  //deviationGrapher = [ActiveGraph createBegin: [self getZone]];
  //[deviationGrapher setElement: deviationData];
  //[deviationGrapher setDataFeed: deviationAverager];
  //[deviationGrapher setProbedSelector: M(getAverage)];
  //deviationGrapher = [deviationGrapher createEnd];
    
  return self;
}


/*"This method is needed to stop run-time hangs when users close graph windows by clicking on their system's window close button"*/
- _priceGraphDeath_ : caller
{
  [priceGraph drop];
  priceGraph = nil;
  return self;
}

/*"This method is needed to stop run-time hangs when users close graph windows by clicking on their system's window close button"*/
- _volumeGraphDeath_ : caller
{
  [volumeGraph drop];
  volumeGraph = nil;
  return self;
}



- _positionHistoDeath_ : caller
{
  [positionHisto drop];
  positionHisto = nil;
  return self;
}



- _relativeWealthHistoDeath_ : caller
{
  [relativeWealthHisto drop];
  relativeWealthHisto = nil;
  return self;
}





/*" This method gathers data about the agents, puts it into arrays,
  and then passes those arrays to the histogram objects. As soon as we
  tell the histograms to draw themselves, we will see the result"*/
- updateHistos
{
  id index;
  id agent;
  int i;
  int numagents = [[asmModelSwarm getAgentList] getCount];
  double position[numagents];
  double relativeWealth[numagents];
  //double cash[numagents];

  index = [[asmModelSwarm getAgentList] begin: [self getZone]];
    
  for(i=0; (agent = [index next]); i++)
    {
      double initcash=[(id)arguments getModelParams]->initialcash;
      position[i] = [agent getAgentPosition];
      relativeWealth[i] = [agent getWealth]/initcash;
      //cash[i] = [agent getCash];
    }
  [index drop];
  [positionHisto drawHistogramWithDouble: position];
  [relativeWealthHisto drawHistogramWithDouble: relativeWealth];
  //[cashHisto drawHistoWithDouble: cash];

  return self;
}
   
/*"This causes the system to save a copy of the current parameter
  settings.  It can be turned on by hitting a button in the probe
  display that shows at the outset of the model run, or any time
  thereafter."*/
- writeSimulationParams
{
  writeParams = 1;
  [output writeParams: [(id) arguments getModelParams] BFAgent: [(id) arguments getBFParams] Time: [asmModelSwarm getModelTime]];
  
  return self;
}

/*"If the writeParams variable is set to YES, then this method cause
  the system to save a snapshot of the parameters after the system's
  run ends."*/
- expostParamWrite
{
  if (writeParams == 1)
    [output writeParams: [(id) arguments getModelParams] BFAgent: [(id) arguments getBFParams] Time:[asmModelSwarm getModelTime]]; 
  return self;
}

/*"Returns the condition of the writeParams variable, an indicator
  that parameters should be written to files"*/
- (BOOL)ifParamWrite
{
  return writeParams;
}

/*"This toggles data writing features. It can be accessed by punching
  a button in a probe display that is shown on the screen when the simulation begins"*/

-(BOOL)toggleDataWrite { 
  if(writeData != YES) 
    { 
      [output  prepareOutputFile]; 
      writeData = YES; 
    } 
  else writeData = NO;

  return writeData;
}


/*"If data logging is turned on, this cause data to be written whenever it is called"*/
- _writeRawData_
{
  id agentlist; //BaT 10.09.2002
  agentlist = [asmModelSwarm getAgentList];//BaT 10.09.2002
  if (writeData == YES)
    [output writeData:agentlist];  //BaT 10.09.2002
  return self;
}


/*" Create actions and schedules onto which the actions are put.
  Since this is an observer, the actions are intended to make sure
  data is collected, displayed to the screen, and written to files
  where appropriate"*/
- buildActions 
{
  [super buildActions];

  [asmModelSwarm buildActions];

  displayActions = [ActionGroup create: [self getZone]];

  [displayActions createActionTo: self 
		    message: M(_writeRawData_)];
  [displayActions createActionTo: self             message: M(updateHistos)];
  [displayActions createActionTo: priceGraph    message: M(step)];
  //  [displayActions createActionTo: riskNeutralGrapher     message: M(step)];
  [displayActions createActionTo: volumeGraph    message: M(step)];
  //[displayActions createActionTo: deviationAverager     message: M(update)];
  //[displayActions createActionTo: deviationGrapher     message: M(step)];
  [displayActions createActionTo: probeDisplayManager      
		  message: M(update)];
  [displayActions createActionTo: actionCache message: M(doTkEvents)];

  displaySchedule = [Schedule createBegin: [self getZone]];
  [displaySchedule setRepeatInterval: displayFrequency];
  displaySchedule = [displaySchedule createEnd];
  [displaySchedule at: 0 createAction: displayActions];
 
  return self;
}


/*"This method activates the model swarm within the context of this
  observer, and then it activated the observer's schedules.  This
  makes sure that the actions inserted at time t inside the model are
  placed into the overall time sequence before the observer scheduled
  actions that update graphs which describe the results"*/
- activateIn: swarmContext 
{
  [super activateIn: swarmContext];
  [asmModelSwarm activateIn: self];

  [displaySchedule activateIn: self];

  return [self getSwarmActivity];
}


/*"In order to make sure that the data is actually written to disk, it
  is necessary to pass a "drop" message down the hierarchy so that all
  data writers know it is time to finish up their work. This drop
  method is called at the end of the main.m file and it propogates
  down to all objects created in asmModelSwarm"*/
-(void) drop
{
  [self expostParamWrite];
  [asmModelSwarm drop];
  [super drop];
}


@end
