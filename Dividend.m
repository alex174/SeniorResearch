// The Santa Fe Stockmarket -- Implementation of the dividend process.

// -(int)setPeriod: (int)thePeriod
//	


#import "Dividend.h"
#import <random.h>  //swarm library to get NormalDist
#include <math.h>
#include <misc.h>



@implementation Dividend
/*"
// This object produces a stochastic sequence of dividends.  The process
// is independent of the market and agents, depending only the parameters 
// that are set for the dividend process (and on the random number generator).
"*/

/*"Creates a Swarm Normal Distribution object"*/
- initNormal
{
  
  id myMTgen = [MT19937gen create: [self getZone]  setStateFromSeed: [randomGenerator getInitialSeed] + 5];

  normal = [NormalDist  create: [self getZone]  setGenerator: myMTgen setMean: 0 setVariance: 1];

  return self;
}

-setBaseline: (double)theBaseline
{
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


/*" Sets the "amplitude" parameter.    Returns the
//	value actually set, which may be clipped or rounded compared to the
//	supplied argument. See "-setDivType:".
"*/
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

/*" Sets the "period" parameter.   Returns the
// value actually set, which may be clipped compared to the supplied
// argument. See "-setDivType:". "*/

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
  dvdnd = baseline + gauss*[normal getDoubleSample];
  return self;
}

/*" Returns the next value of the dividend.  This is the core method
  of the Dividend object, for which all else exists.  It does NOT use
  the global time, but simply assumes that one period passes between
  each call.  Note that "time" may not be the same as the global
  variable "t" because shifts are introduced to maintain phase when
  certain parameters are changed."*/

-(double)dividend
{
    dvdnd = baseline + rho*(dvdnd - baseline) + gauss*[normal getDoubleSample]; 
  if (dvdnd < mindividend) 
    dvdnd = mindividend;
  if (dvdnd > maxdividend) 
    dvdnd = maxdividend;

  return dvdnd;
}


@end







