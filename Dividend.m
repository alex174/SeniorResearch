// The Santa Fe Stockmarket -- Implementation of the dividend process.

// This object produces a stochastic sequence of dividends.  The process
// is independent of the market and agents, depending only the parameters 
// that are set for the dividend process (and on the random number generator).

// -(double)dividend;
//	Returns the next value of the dividend.  This is the core method
//	of the Dividend object, for which all else exists.  It does NOT
//	use the global time, but simply assumes that one period
//	passes between each call.
//
//	These processes are parameterized by some or all of the
//	following parameters:
//
//	baseline	The centerline around which deviations are computed.
//			This is equal to the mean for a symmetric process
//			(i.e., if asymmetry = 0).  "baseline" is set only
//			from the parameter file, and should NOT normally
//			be changed from the default value (10.0).
//
//	amplitude	The amplitude of the deviations from the baseline.
//			Measured in units of "baseline".  The standard
//			deviation of the process is proportional to this.
//
//	period		The period or auto-correlation time of the process.
//
//
// -(double)setAmplitude: (double)theAmplitude
//	Sets the "amplitude" parameter.  See "-setDivType:".  Returns the
//	value actually set, which may be clipped or rounded compared to the
//	supplied argument.
//
// -(int)setPeriod: (int)thePeriod
//	Sets the "period" parameter.  See "-setDivType:".  Returns the
//	value actually set, which may be clipped compared to the
//	supplied argument.


#import "Dividend.h"
//#import "random.h"
#import <random.h>  //swarm library to get NormalDist
#include <math.h>
#include <misc.h>

// Constants
#define PI		3.14159265


@implementation Dividend

//pj: new method 
- initNormal
{
  
  normal=[NormalDist  create: [self getZone]  setGenerator: randomGenerator setMean: 0 setVariance: 1];

  return self;
}

-setBaseline: (double)theBaseline
{

  printf(" \n \n World set baseline %f \n \n", theBaseline);

  baseline = theBaseline;
  return self;
}


-setmindividend: (double)minimumDividend
{
  mindividend = minimumDividend;
  return self;
}


-setmaxdividend: (double)maximumDividend
{
  maxdividend = maximumDividend;
  return self;
}


-(double)setAmplitude:(double)theAmplitude
{
  amplitude = theAmplitude;
  if (amplitude < 0.0) 
    amplitude = 0.0;
  if (amplitude > 1.0) 
    amplitude = 1.0;
  amplitude = 0.0001*rint(10000.0*amplitude);
  return amplitude;
}


-(int)setPeriod: (int)thePeriod
{
  period = thePeriod;
  if (period < 2) 
    period = 2;
  return period;
}


-setDerivedParams
/*
 * Sets various parameters derived from the externally-settable ones.  This
 * is called lazily, when a parameter is needed and the needsSetDerivedParams
 * flag is set.
 */
{
  deviation = baseline*amplitude;
// We round rho slightly for analytic ease
  rho = exp(-1.0/((double)period));
  rho = 0.0001*rint(10000.0*rho);	
  gauss = deviation*sqrt(1.0-rho*rho);
  //pj:
  //dvdnd = baseline + gauss*normal();
  dvdnd = baseline + gauss*[normal getDoubleSample];
  return self;
}


-(double)dividend
/*
 * Compute dividend for the current period.
 * Assumes that one period passes between each call; note that "time"
 * may not be the same as the global variable "t" because shifts are
 * introduced to maintain phase when certain parameters are changed.
 */
{
  //pj:
  // dvdnd = baseline + rho*(dvdnd - baseline) + gauss*normal();
    dvdnd = baseline + rho*(dvdnd - baseline) + gauss*[normal getDoubleSample]; 
  if (dvdnd < mindividend) 
    dvdnd = mindividend;
  if (dvdnd > maxdividend) 
    dvdnd = maxdividend;

   printf(" \n \n World dividend %f baseline %f rho %f max %f min  %f\n \n", dvdnd, baseline, rho, maxdividend, mindividend);

  return dvdnd;
}


@end







