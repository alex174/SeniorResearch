#import <analysis.h>
#import <simtoolsgui/GUISwarm.h>
#import <simtoolsgui.h>
#import <gui.h>
#import "ASMModelSwarm.h"
#import "ASMModelParams.h"
#import "Output.h"
#import <misc.h>


@interface ASMObserverSwarm: GUISwarm
{
  int displayFrequency; /*"update frequency for graphs"*/

  id <ActionGroup> displayActions; /*"set of actions necessary to keep display up to date"*/
  id <Schedule> displaySchedule; /*"Schedule that causes the displayActions to be carried out"*/

  Output * output; /*"An output object"*/
  ASMModelSwarm *asmModelSwarm; /*"Instance of ASMModelSwarm, where agents and the world are created and scheduled"*/
  BOOL writeParams; /*"Indicator that files including parameter values should be written"*/
  BOOL writeData;/*"Indicator that files including output values should be written"*/

  id <Histogram> positionHisto;/*"Histogram showing amount of stock held by each individual agent"*/
  //Histo *cashHisto; //A histogram for agent cash holdings.
  id <Histogram> relativeWealthHisto;/*"Histogram showing wealth of agents"*/

  //This is for comparing different agents.  But since there is 
  //currently only one agent this is not implemented.
  id <Graph> deviationGraph; /*"As of ASM-2.0, this was commented out in ASMObserverSwarm.m"*/
  id <Averager> deviationAverager; /*"ditto"*/
  id <GraphElement> deviationData;/*"ditto"*/
  
  id <ActiveGraph> deviationGrapher;/*"ditto"*/
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
- lispSaveSerial: (char *)inputName;
- buildObjects;


- _positionHistoDeath_ : caller;
- _relativeWealthHistoDeath_ : caller;


- updateHistos;
- writeSimulationParams;
- (BOOL)ifParamWrite;
- expostParamWrite;

-(BOOL) toggleDataWrite;
- buildActions;
- activateIn: swarmContext;
-(void) drop;

@end






