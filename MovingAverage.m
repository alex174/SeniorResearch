#import "MovingAverage.h"
#include <math.h>

@implementation MovingAverage
/*"This is a general purpose class for creating Moving Averages, either flat "equally weighted" moving averages or exponentially weighted moving averages"*/

- initWidth: (int)w
{
  int i;
  width=w;
  maInputs=[[self getZone] allocBlock: w * sizeof(double) ];
  for(i=0; i < w; i++)
    {
      maInputs[i] = 0;
    }
  numInputs=0;
  sumOfInputs=0;
  arrayPosition=0;
  uncorrectedSum=0;
 
  bweight = -expm1(-1.0/w);  //weight for expWMA
  aweight = 1.0 - bweight;   //weight for expWMA; ma=a*ma(x)+b*x

  return self;			   
}



- initWidth: (int)w Value: (double)val
{
  int i;
  width=w;
  maInputs=[[self getZone] allocBlock: w * sizeof(double) ];
  for(i=0; i < w; i++)
    {
      maInputs[i] = val;
    }
  numInputs=w;
  sumOfInputs=w*val;
  arrayPosition=0;
  uncorrectedSum=w*val;
 
  bweight = -expm1(-1.0/w);  //weight for expWMA
  aweight = 1.0 - bweight;   //weight for expWMA; ma=a*ma(x)+b*x
  expWMA = val;

  return self;			   
}


- (int)getNumInputs
{
  return numInputs;
}


- (double)getMA;
{
  double movingAverage;
  if (numInputs == 0) return 0;

  else if (numInputs < width)
    {
      movingAverage=  (double)sumOfInputs / (double)  numInputs;
    }
  else
    {
      movingAverage = (double)sumOfInputs / (double) width;
    }

  return movingAverage;
}

- (double)getAverage
{
  if (numInputs ==0) return 0;
  else return (double)uncorrectedSum/numInputs;
}

-(double) getEWMA
{
  return expWMA; 	
}

- (void)addValue: (double)x;
{
  arrayPosition = (width + numInputs) % width;

  if(numInputs < width)
    {
    sumOfInputs+=x;
    maInputs[arrayPosition]=x;
    }
  else
    {
      sumOfInputs=sumOfInputs - maInputs[arrayPosition] + x ;
      maInputs[arrayPosition]=x;
    }
  numInputs++;

  uncorrectedSum+=x;

  expWMA = aweight*expWMA + bweight*x;
}


- (void)drop
{
  
  [[self getZone] freeBlock: maInputs  blockSize: width*sizeof(double)];
  [super drop];
}




- (void)lispOutDeep: stream
{
  [stream catStartMakeInstance: "MovingAverage"];
  [super lispOutVars: stream deep: YES];//Important to note this!!

  [super lispStoreDoubleArray: maInputs Keyword: "maInputs" Rank: 1 Dims: &width Stream: stream];

  [stream catEndMakeInstance];
}




@end


