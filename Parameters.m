#import "Parameters.h"
#import <stdlib.h>

#import <objectbase.h>    //for probeMap
#import <objectbase/ProbeMap.h>
#import <simtools.h>


@implementation Parameters

+ createBegin: aZone
{
  static struct argp_option options[] = {
     {"run",            'R',"RunNumber",0,"Run is...",7},
     { 0 }
  };

  Parameters *obj = [super createBegin: aZone];
    
  [obj addOptions: options];

  return obj;
}


- (int)parseKey: (int) key arg: (const char*) arg
{
  if (key == 'R')
    {
      run = atoi(arg);
      return 0;
    }

  else
    return [super parseKey: key arg: arg];
}



- init {

  if ((asmModelParams =
       [lispAppArchiver getWithZone: [self getZone] key: "asmModelParams"]) == nil)
    raiseEvent(InvalidOperation,
               "Can't find the modelSwarm parameters");
  
  if ((bfParams =
       [lispAppArchiver getWithZone: [self getZone] key: "bfParams"]) == nil)
    raiseEvent(InvalidOperation,
               "Can't find the BFParam's parameters");
  [bfParams init];

  return self;
}


- (ASMModelParams*) getModelParams
{ 
  return asmModelParams;
}
;
- (BFParams*) getBFParams;
{
  return bfParams;
}

- (int) getRunArg
{
  return run;
}


-sayHello
{
  printf("You are a dirty scoundrel");
  return self;
}


@end














