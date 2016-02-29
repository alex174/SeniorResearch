// The Santa Fe Stockmarket -- Interface for the dividend process

#import <objectbase/SwarmObject.h>

@interface Dividend: SwarmObject
{
 
  double baseline; /*"The centerline around which deviations are computed.
		     //			This is equal to the mean for a symmetric process
		     //			(i.e., if asymmetry = 0).  "baseline" is set only
		     //			from the parameter file, and should NOT normally
		     //			be changed from the default value (10.0)."*/
  //

  double amplitude; /*"The amplitude of the deviations from the baseline.
		      //			Measured in units of "baseline".  The standard
		      //			deviation of the process is proportional to this."*/

  double period;  /*"The period or auto-correlation time of the process."*/

  double mindividend;  /*"floor under dividend values"*/
  double maxdividend; /*"ceiling for dividend values"*/
  double deviation;
  double rho;
  double gauss;
  double dvdnd;
  id normal; /*"A Swarm Normal Generator object"*/
}

- initNormal;

 //These member functions just take parameters set in the 
- setBaseline: (double)theBaseline;
- setmindividend: (double)minimumDividend;
- setmaxdividend: (double)maximumDividend;
- (double)setAmplitude: (double)theAmplitude;
- (int)setPeriod: (int)thePeriod;
- setDerivedParams;

- (double)dividend;
- (double) normal;

@end




