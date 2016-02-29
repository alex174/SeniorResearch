import swarm.objectbase.SwarmObject;
import swarm.objectbase.SwarmObjectImpl;
import swarm.defobj.Zone;
import swarm.Globals;

public class Agent extends SwarmObjectImpl {

public double demand;	/*" bid or -offer"*/
public double profit;	/*" exp-weighted moving average "*/
public double wealth;	/*" total agent wealth "*/
public double position;	/*" total shares of stock "*/
public double cash;	        /*" total agent cash position "*/
public double initialcash;
public double minholding;
public double mincash;
public double intrate;
public double intratep1;
public double price;         // price is maintained by World
public double dividend;      // dividend is maintained by World
public int myID;

// CLASS METHODS
// +setWorld: (World *)aWorld


public static World worldForAgent;

/*" This is the abstract superclass of all agent classes; all agent classes
// must be direct or indirect descendants of this one.
"*/

Agent(Zone aZone){
  super(aZone);
}

/*" Sets a world for an agent.  It is a class method as it is used in
both class and instance methods in BFagent."*/
public static void setWorld(World aWorld)
{
  worldForAgent = aWorld;
  return;
}

/*" Gives an integer name to an agent during creation. Sometimes it
 * helps with debugging to have a unique id for each agent "*/
public Object setID(int iD)
{
  myID = iD;
  return this;
}


/*" Sets the agent's position (holding) to "aDouble"."*/
public Object setPosition(double aDouble)
{
  position = aDouble;
  return this;
}


/*"  Sets the IVAR intrate and uses that to calculate intratep1 (intrate + 1)."*/
public Object setintrate(double rate)
{
  intrate = rate;
  intratep1 = intrate + 1.0;
  return this;
}


/*" Sets the borrowing and short selling constraints, i.e., the
  //      values can be negative. It sets values of the IVARS minholding and mincash"*/
public Object setminHolding$minCash(double holding,double minimumcash)
{
  minholding = holding;
  mincash = minimumcash;
  return this;
}


/*" Sets the initial cash holdings of each agent."*/
public Object setInitialCash(double initcash)
{
  initialcash = initcash;
  return this;
}

/*" Sets the initial stock holdings of each agent. It is the
 * designated initializer.  Most agent classes will have additional
 * initialization, but should do [super setInitialHoldings] to run
 * this first. It will initialize instance variables common to all
 * agents, setting profit,wealth, and position equal to 0, and it sets
 * the variable cash equal to initialcash "*/
public Object setInitialHoldings()
{
  profit = 0.0;
  wealth = 0.0;
  cash = initialcash;
  position = 0.0;

  return this;
}

/*" Sets an instance variable of agent, price, to the current price
  which is controlled by the object known as "world". Please note this
  assumes world is already set. "*/
public Object getPriceFromWorld()
{
  price = worldForAgent.getPrice();
  return this;
}

/*"Sets an instance variable of agent, dividend, to the current dividend. That information is retrieved from the object known as "world"."*/
public Object getDividendFromWorld()
{
  dividend = worldForAgent.getDividend();
  return this;
}


public Object creditEarningsAndPayTaxes()
/*"Sent to each agent after a dividend is declared.  The agents
 * receive the dividend for each unit of stock they hold.  Their cash"
 * in the fixed asset account also receives its interest.  Then taxes
 * are charged on the previous total wealth, at a rate that balances
 * the interest on cash -- so if the agent had everything in cash it
 * would end up at the same place.

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
" */
{
  getPriceFromWorld();
  getDividendFromWorld();

// Update cash
  cash -= (price*intrate - dividend)*position;
  if (cash < mincash)
    cash = mincash;

// Update wealth
  wealth = cash + price*position;

  return this;
}


public double constrainDemand(double slope,double trialprice)
/*" Method used by agents to constrain their demand according to the
 * mincash and minholding constraints.

 * It checks "demand" against the
 * mincash and minholding constraints and clips it if necessary, then
 * also setting *slope.  For use within subclass implementations of
 * getDemandAndSlope: forPrice:.  Used only by agents that work with

 * the Slope Specialist."*/

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
	  slope = -demand/trialprice;
	}
	else
	  {
	    demand = 0.0;
	    slope = 0.0;
	  }
      }
  }


// If selling, we check to make sure we have enough stock to sell
  else if (demand < 0.0 && demand + position < minholding)
    {

      demand = minholding - position;
      slope = 0.0;
    }


  return demand;
}

/*" Return the agent's current position "*/
public double getAgentPosition()
{
  return position;
}

/*" Return the agent's current wealth "*/
public double getWealth()
{
  return wealth;
}


/*" Return the agent's current cash level "*/
public double getCash()
{
  return cash;
}

/*"Sent to each enabled agent at the start of each trading period,
 * before the first -getDemandAndSlope:forPrice: message for that
 * agent.  The class method +prepareForTrading: is sent to each type
 * before any of these messages.  This probably should have some
 * subclassMustImplement code here, because the default code does
 * nothing. It must be overridden"*/
public Object prepareForTrading()
{
  return this;
}

/*" This message is sent to each agent during bidding to ask for its bid
//	(demand > 0) or offer (demand < 0) at price p.  The agent may
//	also return a value for d(demand)/d(price) through "slope",
//	but this is not required; *slope may be left unchanged.  This
//	method may be called one or more times in each period,
//	depending on the specialist method.  The last such call is at
//	the final trading price.  The -prepareForTrading message is
//	sent to each agent before the first such call in each period.
//	Note that agents without demand functions return zero slope,
//	but the Slope specialist is never used with these agents.
//
//	There is no default for this method in the Agent class; the
//	agent subclasses MUST provide it."*/



public double getDemandAndSlope$forPrice(double slope,double p)
{

  return 0.0;		// not reached
}

/*"Sent to each enabled agent at the end of each period to tell it to
  // update its performance meaures, forecasts, etc.  The default code
  does nothing, this method must be specified by each agent type.
  Probably needs a subclass responsibility statement"*/
public Object updatePerformance()
{
  return this;
}









}