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
  id agentList;

  id archiver; /*"LISP archiver object"*/

  int bs[12]; //*"counter array, size of number of bits in use"*/
  double csfreq[4];
  double moments[8];

  time_t runTime; /*"Return from the systems time() function"*/
  time_t now;
  char timeString[100];/*"a verbose description of current time"*/
  
  FILE * dataOutputFile; /*"FILE handle for output from C style fprintf"*/

  id <HDF5> hdf5container; /*"HDF5 data container object used by hdfWriter"*/

  id <EZGraph> priceGraph; /*"Time plot of risk neutral and observed market price"*/
 
  id <EZGraph> volumeGraph; /*"Time plot of market trading volume"*/
  id <EZGraph> bitGraph; /*"Time plot of risk neutral and observed market price"*/
  
  id volsequence;  //sequences for data on volume
  id prsequence[2]; //sequences for data price (observed and expected)
  id cssequence[3];
  id bssequence[16];

  @public
    int currentTime; /*"current time of simulation"*/
 

}

- setSpecialist: (Specialist *)theSpec;

- setWorld: (World *)theWorld;

- (void)setAgentlist: list;

- _priceGraphDeath_ : caller;

- _volumeGraphDeath_ : caller;

- writeParams: modelParam BFAgent: bfParms Time: (long int) t;

- prepareCOutputFile;

- createTimePlots;

- calculateBitData;

- (double)getCSfreq: (unsigned) i;

- stepPlots;

- writeCData;

- (void)drop;

@end




