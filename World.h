// The Santa Fe Stockmarket -- Interface for class World

#import <objectbase/SwarmObject.h>

/*" Macro: Number of up/down movements to store for price and dividend,
 including the current values.  Used for pup, pup1,
 ... pup[UPDOWNLOOKBACK-1], and similarly for dup[n], and for
 -pricetrend:.  The argument to -pricetrend: must be UPDOWNLOOKBACK
 or less. "*/
#define	UPDOWNLOOKBACK	5

/*" Macro: Number of moving averages "*/
#define NMAS	4
/*" Macro: The longest allowed Moving Average "*/
#define MAXHISTORY 500        

@interface World: SwarmObject
{
  double intrate;
  double dividendscale;
  double saveddividend;
  double savedprice;
  int pupdown[UPDOWNLOOKBACK];	       /*" array, dimension UPDOWNLOOKBACK "*/
  int dupdown[UPDOWNLOOKBACK];	       /*" array, dimension UPDOWNLOOKBACK "*/
  double divhistory[MAXHISTORY];       /*" dividend history array, goes back MAXHISTORY points"*/
  double pricehistory[MAXHISTORY];     /*" price history array "*/
 
  int history_top;                     /*" index value of current input into history arrays "*/
  int updown_top;
  double price;
  double oldprice;
  double dividend;
  double olddividend;
  double riskNeutral;
  double profitperunit;
  double returnratio;

  int nmas;
  int malength[NMAS];     /*" For each MA, we must specify the length. This array has one integer for each of the moving averages we plan to keep, and it is used to set the widths covered by the moving averages."*/
 
  int nworldbits;
  int * realworld;
  BOOL exponentialMAs;
  id priceMA[NMAS];  /*" MovingAverage objects which hold price information. There are NMAS of these, and have various widths for the moving averages "*/
  id divMA[NMAS];   /*"  MovingAverage objects which hold dividend moving averages. "*/
  id oldpriceMA[NMAS]; /*" MovingAverage objects which hold lagged price moving averages "*/
  id olddivMA[NMAS];/*" MovingAverage objects which hold lagged dividend moving averages "*/
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













