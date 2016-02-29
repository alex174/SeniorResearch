// The Santa Fe Stockmarket -- Interface for class World

#import <objectbase/SwarmObject.h>
#import <collections.h>


/*" Macro: number of world bits. Must match setup in World.m"*/
#define NWORLDBITS 61


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
@public
  double intrate; /*" interest rate"*/
  double dividendscale; /*" The baseline dividend that is set by initWithBaseline: "*/

  int pupdown[UPDOWNLOOKBACK];	       /*" array, dimension UPDOWNLOOKBACK "*/
  int dupdown[UPDOWNLOOKBACK];	       /*" array, dimension UPDOWNLOOKBACK "*/
 
  int history_top;                     /*" index value of current input into history arrays "*/
  int updown_top;     /*"number of time steps to look back to form pupdown and dupdown bits"*/
  double price;     /*"market clearning price"*/
  double oldprice;  /*" previous price "*/
  double dividend;   /*" dividend "*/ 
  double olddividend; /*"previous dividend"*/
  double saveddividend; /* copy of olddividend, used for some
                           double-checking on object integrity"*/
  double savedprice; /* copy of oldprice, used for some
                        double-checking on object integrity"*/
  double riskNeutral;   /*"dividend/intrate"*/;
  double profitperunit; /*"price - oldprice + dividend"*/
  double returnratio;   /*"profitperunit/oldprice"*/

  int malength[NMAS];     /*" For each MA, we must specify the length over which the average is calculated. This array has one integer for each of the moving averages we plan to keep, and it is used to set the widths covered by the moving averages."*/
 
  int nworldbits; /*"The number of aspects of the world that are recorded as bits"*/
  int realworld[NWORLDBITS];
  // int * realworld; /*"An array (dynamically allocated, sorry) of ints, one for each bit being monitored. This is kept up-to-date. There's a lot of pointer math going on with this and I don't feel so glad about it (PJ: 2001-11-01)"*/
  BOOL exponentialMAs; /*"Indicator variable, YES if the World is supposed to report back exponentially weighted moving averages"*/
  id <Array> priceMA;  /*" MovingAverage objects which hold price information. There are NMAS of these, and have various widths for the moving averages "*/
  id <Array> divMA;   /*"  MovingAverage objects which hold dividend moving averages. "*/
  id <Array> oldpriceMA; /*" MovingAverage objects which hold lagged price moving averages "*/
  id <Array> olddivMA;/*" MovingAverage objects which hold lagged dividend moving averages "*/
  @private
    //double * divhistory;       /*" dividend history array, goes back MAXHISTORY points"*/
    //double * pricehistory;     /*" price history array "*/
    double divhistory[MAXHISTORY] ;
  double pricehistory[MAXHISTORY] ;
}

+ (const char *)descriptionOfBit: (int)n;
+ (const char *)nameOfBit: (int)n;
+ (int)bitNumberOf: (const char *)name;

- setintrate: (double)rate;
- setExponentialMAs: (BOOL)aBool;
- (int)getNumWorldBits;

- initWithBaseline: (double)base;
- setPrice: (double)p;
- (double)getPrice;
- (double)getProfitPerUnit;
- setDividend: (double)d;
- (double)getDividend;
- (double)getRiskNeutral;
- updateWorld;
- getRealWorld: (int *)anArray;
- (int)pricetrend: (int)n;

@end













