#import <objectbase/SwarmObject.h>
#import "BitVector.h"



@interface BFCast: SwarmObject
{
  double forecast;	/*" this forecast of return"*/
  double lforecast;	/*" previous forecast"*/
  double variance;	/*" variance of this forecast"*/
  double actvar;        /*"actual variance of this forecast"*/
  double strength;      /*"strength=maxdev - variance +specfactor.*/
  double a;		/*" (price + dividend) coefficient"*/
  double b;		/*" dividend coefficient "*/
  double c;		/*" constant term"*/
  double specfactor;	/*" specificty=(condbits - nnulls - specificity)* bitcost. "*/
  double bitcost; /*" cost of using bits in forecasts"*/
  int lastactive;  /*" last time period in which this forecast was active"*/
  int lastused; 
  int specificity; /*" specificity "*/
  int count; /*" number of times this forecast has been active"*/
  int condwords; /*"number of words of memory needed to hold the conditions"*/
  int condbits; /*"number of bits of information monitored by this forecast"*/
  int nnulls; /*"number of 'unused' bits that remain in the allocated vector after the 'condbits' bits have been used"*/
  BitVector *conditions; /*" a BitVector object that holds records on which conditions in the world are being monitored by this forecast object"*/
};

+ init;

- init;

- createEnd;

- (void)incrSpecificity;

- (void)decrSpecificity;

- (void)setSpecificity: (int)specificity;

- (int)getSpecificity;

- (void)setConditions: (int *) x;

- (int *)getConditions;

- (BitVector *)getConditionsObject;

- (void)setNNulls: (int)x;

- (void)setBitcost: (double)x;

- (void)setConditionsWord: (int)i To: (int)value;

- (int)getConditionsWord: (int)x;

- (void)setConditionsbit: (int)bit To: (int)x; //works for 0,1,2

- (void)setConditionsbit: (int)bit FromZeroTo: (int)x;//faster if cond[bit]=0

- (void)maskConditionsbit: (int)bit;

- (void)switchConditionsbit: (int)bit;

- (int) getConditionsbit: (int)bit;

- (void) setAval: (double)x;

- (void) setBval: (double)x;

- (void) setCval: (double)x;

- (double)getAval;

- (double)getBval;

- (double)getCval;

- (void)updateSpecfactor;

- (void)setSpecfactor: (double)x;

- (double)getSpecfactor;

- (void)setVariance: (double) x;
       
- (double)getVariance;

- (void)setActvar: (double) x;
       
- (double)getActvar;

- (void)setCondwords: (int)x;

- (void)setCondbits: (int)x;

- (void)setForecast: (double)x;

- (double)getForecast;

- (double)updateForecastPrice: (double)price Dividend: (double)dividend;

- (void)setLforecast: (double)x;

- (double)getLforecast;

- (void)setLastactive: (int)x;

- (int)getLastactive;

- (void)setLastused: (int)x;

- (int)getLastused;

- (void)setCnt: (int)x;

- (int)getCnt;

- (int)incrCount;

- (void)setStrength: (double)x;

- (double)getStrength;

- copyEverythingFrom: (BFCast *)from;

- print;

- printcond: (int)conditions;

- (void)drop;

@end







