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
#import <analysis.h>

@interface Output: SwarmObject
{
  @private
  BOOL dataFileExists;

  World * outputWorld;
  Specialist * outputSpecialist;
  id archiver, dataArchiver;
  
  // FILE * paramOutputFile;
  time_t runTime;
  char timeString[100];

  FILE * dataOutputFile;
  id <EZGraph> hdfWriter;
  id <HDF5> hdf5container;

  @public
  int currentTime;
  double price;
  double dividend;
  double volume;

}

-setSpecialist: (Specialist *)theSpec;

-setWorld: (World *)theWorld;

- writeParams: modelParam BFAgent: bfParms Time: (long int) t;

-prepareOutputFile;

-writeData;

-(void) drop;

@end




