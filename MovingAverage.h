#import <objectbase/SwarmObject.h>


@interface MovingAverage: SwarmObject
{
  int width;
  int numInputs;
  int arrayPosition;
  double uncorrectedSum;
  double *maInputs; 
  double sumOfInputs;

  double aweight, bweight;
  double expWMA;  //exponentially weighted moving average
} 

- initWidth: (int)w;
- initWidth: (int)w Value: (double)val;

- (int)getNumInputs;

- (double)getMA;

- (double)getAverage;

- (double)getEWMA;

- (void)addValue: (double)x;

- (void)drop;

@end












