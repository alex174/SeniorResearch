// The Santa Fe Stockmarket -- Interface for class World

#import <objectbase/SwarmObject.h>

@interface World: SwarmObject
{
  double intrate;
  double dividendscale;
  double saveddividend;
  double savedprice;
  int * pupdown;		/* array, dimension UPDOWNLOOKBACK */
  int * dupdown;		/* array, dimension UPDOWNLOOKBACK */
  double * divhistory;		/* array, dimension maxhistory */
  double * pricehistory;	/* array, dimension maxhistory */
  double * aweight;		/* array, dimension NMAS */
  double * bweight;		/* array, dimension NMAS */
  int history_top;
  int updown_top;
  int maxhistory;
  double price;
  double oldprice;
  double dividend;
  double olddividend;
  double riskNeutral;
  double profitperunit;
  double returnratio;

  int nmas;
  int * matime;
  double * pmav;
  double * oldpmav;
  double * dmav;
  double * olddmav;
  int nworldbits;
  int * realworld;
  BOOL exponentialMAs;
}

+(const char *)descriptionOfBit: (int)n;
+(const char *)nameOfBit: (int)n;
+(int)bitNumberOf: (const char *)name;

-setintrate: (double)rate;
-setExponentialMAs: (BOOL)aBool;
-(int)getNumWorldBits;

-initWithBaseline: (double)base;
-setPrice: (double)p;
-(double)getPrice;
-(double)getProfitPerUnit;
-setDividend: (double)d;
-(double)getDividend;
-(double)getRiskNeutral;
-updateWorld;
-getRealWorld: (int *)anArray;
-(int)pricetrend: (int)n;

@end













