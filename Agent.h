#import <objectbase.h>               //Agent is a SwarmObject
#import "World.h"

@interface Agent:SwarmObject          
{
  @public
  double demand;	// bid or -offer 
  double profit;	// exp-weighted moving average
  double wealth;	// total agent wealth
  double position;	// total shares of stock
  double cash;	        // total agent cash position 
  double initialcash;
  double minholding;
  double mincash;
  double intrate;
  double intratep1;
  double price;         // price is maintained by World
  double dividend;      // dividend is maintained by World
  int myID;
}


+setWorld: (World *)aWorld;

-setID: (int)iD;
-setPosition: (double)aDouble;
-setintrate: (double)rate;
-setminHolding: (double)holding   minCash: (double)minimumcash;
-setInitialCash: (double)initcash;
-setInitialHoldings;
-getPriceFromWorld;
-getDividendFromWorld;

-creditEarningsAndPayTaxes;
-(double)constrainDemand: (double *)slope : (double)trialprice;
-(double)getAgentPosition;
-(double)getWealth;
-(double)getCash;

//Methods specified by each agent type
-prepareForTrading;   
-(double)getDemandAndSlope: (double *)slope forPrice: (double)trialprce;
-updatePerformance;

@end





