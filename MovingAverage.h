#import <objectbase/SwarmObject.h>


@interface MovingAverage: SwarmObject
{
  int width;  /*"number of observations used for a fixed interval moving average"*/
  int numInputs; /*"number of observations that have already been inserted"*/
 
  
  double *maInputs; /*"historical inputs are kept in this array."*/
  int arrayPosition; /*"element of maInputs that has been most recently inserted"*/
  double sumOfInputs;/*"sum of the last 'width' inputs"*/
  double uncorrectedSum; /*"sum of all inputs since object was created"*/
 
  double expWMA;  //exponentially weighted moving average
  double aweight, bweight; /*"Weights used to calculate exponentially weighted moving averages.  These depend on the specified 'width' according to: bweight = -expm1(-1.0/w);aweight = 1.0 - bweight; ewma=aweight*ma(x)+bweight*x"*/

} 

- initWidth: (int)w;
- initWidth: (int)w Value: (double)val;

- (int)getNumInputs;

- (double)getMA;

- (double)getAverage;

- (double)getEWMA;

- (void)addValue: (double)x;

- (void)drop;


- (void)lispOutDeep: stream;

@end












