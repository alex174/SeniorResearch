// The Santa Fe Stockmarket -- Interface for class World

#import <objc/Object.h>

@interface World: Object
{
    double dividendscale;
    double saveddividend;
    double savedprice;
    int *pupdown;		/* array, dimension UPDOWNLOOKBACK */
    int *dupdown;		/* array, dimension UPDOWNLOOKBACK */
    double *divhistory;		/* array, dimension maxhistory */
    double *pricehistory;	/* array, dimension maxhistory */
    double *aweight;		/* array, dimension NMAS */
    double *bweight;		/* array, dimension NMAS */
    int history_top;
    int updown_top;
    int maxhistory;
}

// PUBLIC METHODS

+ (const char *)descriptionOfBit:(unsigned int)n;
+ (const char *)nameOfBit:(unsigned int)n;
+ (int)bitNumberOf:(const char *)name;
+ writeNamesToFile:(FILE *)fp;
- (int)initWithBaseline:(double)baseline;
- setPrice:(double)p;
- setDividend:(double)d;
- updateWorld;
- (int)pricetrend:(int)n;
- check;

@end
