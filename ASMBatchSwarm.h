#import <objectbase.h>
#import <activity.h>
#import <collections.h>
#import <simtools.h>
#import <stdio.h>
#import <activity/Schedule.h>
#import "ASMModelSwarm.h"


@interface ASMBatchSwarm: Swarm
{
  int loggingFrequency;
  int experimentDuration;

  id displayActions;
  id displaySchedule;
  id stopSchedule;

  ASMModelSwarm * asmModelSwarm;
  id output;
}

+createBegin: (id)aZone;
-buildObjects;
-buildActions;
-activateIn: (id)swarmContext;
-go;
-stopRunning;

@end

