// The Santa Fe Stockmarket -- Interface for the dividend process

#import <objectbase/SwarmObject.h>

@interface Dividend: SwarmObject
{
  int period;
  double baseline;
  double mindividend;
  double maxdividend;
  double amplitude;

  double deviation;
  double rho;
  double gauss;

  double dvdnd;

  id normal;
}

-initNormal;

 //These member functions just take parameters set in the 
-setBaseline: (double)theBaseline;
-setmindividend: (double)minimumDividend;
-setmaxdividend: (double)maximumDividend;
-(double)setAmplitude: (double)theAmplitude;
-(int)setPeriod: (int)thePeriod;
-setDerivedParams;

-(double)dividend;

@end




