#import <defobj/Arguments.h>

#import "BFParams.h"
#import "ASMModelParams.h"


@interface Parameters: Arguments_c
{
  ASMModelParams * asmModelParams; /*"parameter object used by ASMModelSwarm"*/
  BFParams * bfParams;/*"parameter object used by BFagent and its various objects, such as BFCast "*/
  int run; /*an integer indicating the run number of the current simulation. This is passed in as a command line parameter, as in --run=666 or such."*/
  char *filename;

}

+ createBegin: aZone;

- (ASMModelParams*) getModelParams;
- (BFParams*) getBFParams;


- sayHello;

- init;

- (int) getRunArg;

- (char *)getFilename; 

@end


