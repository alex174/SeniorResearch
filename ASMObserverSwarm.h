#import <analysis.h>
#import <simtoolsgui/GUISwarm.h>
#import <simtoolsgui.h>
#import <gui.h>
#import "ASMModelSwarm.h"

@interface ASMObserverSwarm: GUISwarm
{
  int displayFrequency;

  id displayActions;
  id displaySchedule;

  ASMModelSwarm *asmModelSwarm;
  BOOL writeParams;
  BOOL writeData;

  id <Graph> priceGraph;
  id <GraphElement> priceData;
  id <GraphElement> riskNeutralData;

  id <ActiveGraph> priceGrapher;
  id <ActiveGraph> riskNeutralGrapher;

  id <Graph> volumeGraph;
  id <GraphElement> volumeData;

  id <ActiveGraph> volumeGrapher;

  id <Histogram> positionHisto;
  //Histo *cashHisto; //A histogram for agent cash holdings.
  id <Histogram> relativeWealthHisto;

  //This is for comparing different agents.  But since there is 
  //currently only one agent this is not implemented.
  id <Graph> deviationGraph;
  id <Averager> deviationAverager;
  id <GraphElement> deviationData;
  
  id <ActiveGraph> deviationGrapher;
  
  double *position;
  double *wealth;
  //double * cash;
  double *relativeWealth;
  int numagents;
}  

+ createBegin: aZone;
//Some member functions that talk straight to TKL/tk.  
//They are taken out here.
#if 0
- printPriceGraph;
- printVolumeGraph;
- printDeviationGraph;
- printRelWealthHisto;
#endif
- createEnd;
- buildObjects;
- updateHistos;
- writeSimulationParams;
- (BOOL)ifParamWrite;
- expostParamWrite;
- writeSimulationData;
- buildActions;
- activateIn: swarmContext;

@end






