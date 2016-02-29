// The Santa Fe Stockmarket -- Interface for Agent class

#import <objc/Object.h>

@interface Agent:Object
{
@public
    double demand;	/* bid or -offer */
    double profit;	/* exp-weighted moving average */
    double wealth;	/* total agent wealth */
    double position;	/* total shares of stock */
    double cash;	/* total agent cash position */
    int tag;		/* agent number (index into AgentManager's alist[]) */
    int lastgatime;	/* last time a GA was run, or MININT if none */
}

// CLASS METHODS
+ initClass:(int)myclass;
+ (void *)createType:(int)mytype :(const char *)filename;
+ writeParams:(void *)theParams ToFile:(FILE *)fp;
+ didInitialize;
+ prepareForTrading:(void *)theParams;
+ (int)lastgatime:(void *)params;

// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN
- init;		// dummy, to catch misuse (use initAgent:type:)
- setTag:(int)mytag;
- (const char *)shortname;
- (const char *)fullname;
- setPosition:(double)aDouble;
- creditEarningsAndPayTaxes;
- (double)constrainDemand:(double *)slope :(double)trialprice;
- (int *(*)[4])bitDistribution;

// PUBLIC INSTANCE METHODS, OFTEN OVERRIDDEN BY SUBCLASSES
- initAgent:(int)mytag;
- check;
- prepareForTrading;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;
- updatePerformance;
- enabledStatus:(BOOL)flag;
- (int)nbits;
- (const char *)descriptionOfBit:(int)bit;
- (int)nrules;
- (int)lastgatime;
- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
- (int)fMoments:(double *)moment cumulative:(BOOL)cum;
- pAgentStatus:(FILE *) fp;

@end
