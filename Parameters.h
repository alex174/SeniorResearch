#import <defobj/Arguments.h>

#import "BFParams.h"
#import "ASMModelParams.h"


@interface Parameters: Arguments_c
{
  ASMModelParams * asmModelParams;
  BFParams * bfParams;
  int run;
}

+ createBegin: aZone;

- (ASMModelParams*) getModelParams;
- (BFParams*) getBFParams;


- sayHello;

- init;


@end


