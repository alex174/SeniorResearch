// This is the abstract superclass of all agent classes; all agent classes
// must be direct or indirect descendants of this one.

// CLASS METHODS
// +setWorld: (World *)aWorld
//      Sets a world for each type of agent.  It is a class method as it
//      is used in both class and instance methods in BFagent.
//
// PUBLIC INSTANCE METHODS, NOT USUALLY OVERRIDDEN
// -setID: (int)iD
//      Gives an integer name to an agent during creation.
//   
// -setPosition: (double)aDouble
//	Sets the agent's position (holding) to "aDouble".
//
// -setintrate: (double)rate
//      Sets intrate and intratep1 (intrate + 1).
//
// -setminHolding: (double)holding minCash: (double)minimumcash
//      Sets the borrowing and short selling constraints, i.e., the 
//      values can be negative.
//
// -setInitialCash
//      Sets the initial cash holdings of each agent.
//
// -setInitialHoldings
//      Sets the initial stock holdings of each agent.
//
// -getPriceFromWorld
//      Sets an instance variable of agent, price, to the current price
//      which is controlled by the World.
//
// -getDividendFromWorld
//      Same deal as getPriceFromWorld but with dividend.
//
// -creditEarningsAndPayTaxes
//	Sent to each agent after a dividend is declared.  The
//	agents receive the dividend for each unit of stock they hold.
//	Their "cash" in the fixed asset account also receives its
//	interest.  Then taxes are charged on the previous total wealth,
//	at a rate that balances the interest on cash -- so if the agent
//	had everything in cash it would end up at the same place.
//
// -(double)constrainDemand: (double *)slope : (double)trialprice
//	Checks "demand" against the mincash and minholding constraints
//	and clips it if necessary, then also setting *slope.  For use
//	within subclass implementations of getDemandAndSlope: forPrice:.
//      Used only by agents that work with the Slope Specialist.
//
// -(double)getAgentPosition, -(double)getWealth, -(double)getCash
//      Returns an agent's stock holding, wealth, and cash.  These are 
//      updated in Specialist.
//
// PUBLIC INSTANCE METHODS, SPECIFIED BY SUBCLASSES
// -prepareForTrading
//	Sent to each enabled agent at the start of each trading period,
//	before the first -getDemandAndSlope:forPrice: message for that
//	agent.  The class method +prepareForTrading: is sent to each type
//	before any of these messages.
//
// -(double)getDemandandSlope: (double *)slope forPrice: (double)p
//	Sent to each agent during bidding to ask for its bid
//	(demand > 0) or offer (demand < 0) at price p.  The agent may
//	also return a value for d(demand)/d(price) through "slope", but
//	this is not required; *slope may be left unchanged.  This method
//	may be called one or more times in each period, depending on the
//	specialist method.  The last such call is at the final trading
//	price.  The -prepareForTrading message is sent to each agent
//	before the first such call in each period.  Note that agents without
//      demand functions return zero slope, but the Slope specialist is never 
//      used with these agents.
//
//	There is no default for this method in the Agent class; the agent
//	subclasses MUST provide it.
//
// -updatePerformance
//	Sent to each enabled agent at the end of each period to tell it to
//	update its performance meaures, forecasts, etc.
//
// VARIABLES AND PARAMETERS CALLED FROM OTHER OBJECTS
//
// double price, dividend
//	Market variables from World.
//
// double intrate, mincash, initialcash, minholding
//	Market constants from ASMModelSwarm.
//
// Variables Called by others from the agent
//    double demand;	/* bid or -offer */
//    double profit;	/* exp-weighted moving average */
//    double wealth;	/* total agent wealth */
//    double position;  /* total shares of stock */
//    double cash;	/* total agent cash position */


#import "Agent.h"

World * worldForAgent;

@implementation Agent

+setWorld: (World *)aWorld;
{
  worldForAgent = aWorld;
  return self;
}


-setID: (int)iD
{
  myID = iD;
  return self;
}


-setPosition: (double)aDouble
{
  position = aDouble;
  return self;
}


-setintrate: (double)rate;
{
  intrate = rate;
  intratep1 = intrate + 1.0;
  return self;
}


-setminHolding: (double)holding   minCash: (double)minimumcash
{
  minholding = holding;
  mincash = minimumcash;
  return self;
}


-setInitialCash: (double)initcash;
{
  initialcash = initcash;
  return self;
}


-setInitialHoldings
/*
 * Designated initializer.  Most agent classes will have additional
 * initialization, but should do [super setInitialHoldings] to run this first.
 */
{
// Initialize instance variables common to all agents
  profit = 0.0;
  wealth = 0.0;
  cash = initialcash;
  position = 0.0;

  return self;
}


-getPriceFromWorld
{
  price = [worldForAgent getPrice];
  return self;
}


-getDividendFromWorld
{
  dividend = [worldForAgent getDividend];
  return self;
}


-creditEarningsAndPayTaxes
/*
 * This is done in each period after the new dividend is declared.  It is
 * not normally overridden by subclases.  The taxes are assessed on the
 * previous wealth at a rate so that there's no net effect on an agent
 * with position = 0.
 *
 * In principle we do:
 *	wealth = cash + price*position;			// previous wealth
 *	cash += intrate * cash + position*dividend;	// earnings
 *	cash -= wealth*intrate;				// taxes
 * but we cut directly to the cash:
 *	cash -= (price*intrate - dividend)*position
 */
{
  [self getPriceFromWorld];
  [self getDividendFromWorld];
  
// Update cash
  cash -= (price*intrate - dividend)*position;
  if (cash < mincash) 
    cash = mincash;
  
// Update wealth
  wealth = cash + price*position;
  
  return self;
}


-(double)constrainDemand: (double *)slope : (double)trialprice
/*
 * Method used by agents to constrain their demand according to the
 * mincash and minholding constraints.
 */
{
// If buying, we check to see if we're within borrowing limits,
// remembering to handle the problem of negative dividends  -
// cash might already be less than the min.  In that case we
// freeze the trader.
  if (demand > 0.0) {
    if (demand*trialprice > (cash - mincash)) 
      {
	if (cash - mincash > 0.0) {
	  demand = (cash - mincash)/trialprice;
	  *slope = -demand/trialprice;
	}
	else 
	  {
	    demand = 0.0;
	    *slope = 0.0;
	  }
      }
  }

// If selling, we check to make sure we have enough stock to sell
  else if (demand < 0.0 && demand + position < minholding) 
    {
      demand = minholding - position;
      *slope = 0.0;
    }
  return demand;
}


-(double)getAgentPosition
{ 
  return position;
}


-(double)getWealth
{
  return wealth;
}


-(double)getCash
{
  return cash;
}


-prepareForTrading
{
  return self;	// default code does nothing
}


-(double)getDemandAndSlope: (double *)slope forPrice: (double)p
{
  [self subclassResponsibility:_cmd];
  return 0.0;		// not reached
}


-updatePerformance
{
  return self;	// default code does nothing, specified by each agent type
}


@end













