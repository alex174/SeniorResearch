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
    BOOL dataFileExists; /*"Indicator that dataFile initialization has alreadyoccurred"*/

  World * outputWorld;  /*"Reference to the world, where we can get data!"*/
  Specialist * outputSpecialist; /*" Reference to the Specialist object, where we can get data!"*/
  id archiver, dataArchiver; /*"hdf5 or LISP objects, depending on the CPP flags"*/
  
  time_t runTime; /*"Return from the systems time() function"*/
  char timeString[100];/*"a verbose description of current time"*/
  
  FILE * dataOutputFile; /*"FILE handle for output from C style fprintf"*/
  id <EZGraph> hdfWriter; /*"EZGraph object that is used only to create hdf5 formatted output"*/
  id <HDF5> hdf5container; /*"HDF5 data container object used by hdfWriter"*/
  
  @public
    int currentTime; /*"current time of simulation"*/
  double price; /*"current price"*/
  double dividend; /*"current dividend"*/
  double volume; /*"current volume"*/

}

-setSpecialist: (Specialist *)theSpec;

-setWorld: (World *)theWorld;

- writeParams: modelParam BFAgent: bfParms Time: (long int) t;

-prepareOutputFile;

-writeData;

-(void) drop;

@end




