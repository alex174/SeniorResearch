#import <objectbase.h>
#import <activity.h>
#import <collections.h>
#import <simtools.h>
#import "ASMModelSwarm.h"

@interface ASMBatchSwarm: Swarm
{
  int loggingFrequency; /*"how often to write data "*/
  int experimentDuration;/*"how long should a run last"*/

  id <ActionGroup> displayActions;/*"Set of actions that update output"*/
  id <Schedule> displaySchedule;/*"Schedule for periodic actions"*/
  id <Schedule> stopSchedule; /*"Schedule which checks to see if the simulation has completed its requisite number of timesteps"*/

  ASMModelSwarm * asmModelSwarm;/*"Instance of ASMModelSwarm, where agents and the world are created and scheduled"*/
 
  id output; /*"Reference to instance of Output class, the place where data file output is controlled"*/
}

+ createBegin: aZone;
- buildObjects;
- buildActions;
- activateIn: swarmContext;

- expostParamWrite;
- go;
- stopRunning;
-(void) drop;
@end

