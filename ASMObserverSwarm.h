#import <analysis.h>
#import <simtoolsgui/GUISwarm.h>
#import <simtoolsgui.h>
#import <gui.h>
#import "ASMModelSwarm.h"
#import "ASMModelParams.h"
#import <misc.h>


@interface ASMObserverSwarm: GUISwarm
{
  int displayFrequency;

  id displayActions;
  id displaySchedule;

  ASMModelSwarm *asmModelSwarm;
  BOOL writeParams;
  BOOL writeData;

  id <EZGraph> priceGraph;
 
  id <EZGraph> volumeGraph;
 

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
- _writeRawData_;

- buildObjects;

- priceGraphDeath_ : caller;
- volumeGraphDeath_ : caller;
- updateHistos;
- writeSimulationParams;
- (BOOL)ifParamWrite;
- expostParamWrite;

-(BOOL) toggleDataWrite;
- buildActions;
- activateIn: swarmContext;

@end






