// Artificial Stock Market Swarm Version Output File Interface

#import <stdio.h>
#import <stdarg.h>
#import <time.h>
#import <objectbase.h>
#import <objectbase/SwarmObject.h>
#import "World.h"
#import "Specialist.h"
#import <simtools.h>
#import <defobj.h>

@interface Output: SwarmObject
{
  BOOL dataFileExists;

  World * outputWorld;
  Specialist * outputSpecialist;
  id archiver;
  // FILE * paramOutputFile;
  time_t runTime;

  int currentTime;
  double price;
  double dividend;
  double volume;
  FILE * dataOutputFile;
}

-setSpecialist: (Specialist *)theSpec;

-setWorld: (World *)theWorld;

- writeParams: modelParam BFAgent: bfParms Time: (long int) t;

-prepareOutputFile;

-writeData;

@end




