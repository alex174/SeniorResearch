// The Santa Fe Stockmarket -- Implementation of Specialist class


#import "Specialist.h"
#import "BFagent.h"
#import "collections.h"    // for the index

#include <math.h>

@implementation Specialist


/*" One instance of this class is used to manage the trading and
  set the stock price.  It also manages the market-level parameters."*/


- setMaxPrice: (double)maximumPrice
{
  maxprice = maximumPrice;
  return self;
}


- setMinPrice: (double)minimumPrice
{
  minprice = minimumPrice;
  return self;
}


- setTaup: (double)aTaup
{
  taupnew = -expm1(-1.0/aTaup); //pj: moved here from init method
  taupdecay = 1.0 - taupnew;   // moved to simplify!
  return self;
}



/*"The specialist can be set to type 0, 1, or 2. If this variable is
set to any other value, the model will set the Specialist to type 1
and give a warning in the terminal"*/
- setSPtype: (int)i
{
  if(i != 0 && i != 1 && i != 2)
    { 
      printf("The specialist type chosen is invalid.  Only 0, 1, or 2 are acceptable.  The Specialist will be set to Slope (i.e., 1).");
      i = 1;
    }
  sptype = (SpecialistType)i;

  return self;
}

/*" Set the maximum number of interations to be done while looking for a market clearing price"*/
- setMaxIterations: (int)someIterations
{
  maxiterations = someIterations;
  return self;
}


- setMinExcess: (double)minimumExcess
{
  minexcess = minimumExcess;
  return self;
}


- setETA: (double)ETA
{
  eta = ETA;
  return self;
}

- setREA: (double)REA
{
  rea = REA;
  return self;
}


- setREB: (double)REB
{
  reb = REB;
  return self;
}

//pj: init method is now unnecessary. Moved IVARS inside methods, or
//reset values when needed.
//  -init


- (double)performTrading: (id) agentList Market: (id) worldForSpec
/*" This is the core method that sets a succession of trial prices and
 *  asks the agents for their bids or offer at each, generally
 *  adjusting the price towards reducing |bids - offers|.  * It gets
 *  bids and offers from the agents and * adjuss the price.  Returns
 *  the final trading price, which becomes * the next market price.
 *  Various methods are implemented, but all * have the structure:
 *  1. Set a trial price 

    2. Send each agent a -getDemandAndSlope:forPrice: message and accumulate the total
 *  number of bids and offers at that price.  

    3. [In some cases] go to  1.  

    4. Return the last trial price.  "*/
{
  int mcount;
  BOOL done;
  double demand, slope, imbalance, dividend;
  double slopetotal = 0.0;
  double trialprice = 0.0;
  double offertotal = 0.0;  //was IVAR
  double bidtotal = 0.0; //was IVAR

  id agent;  id index;

  volume = 0.0;

  dividend = [worldForSpec getDividend];
// Main loop on {set price, get demand}
  for (mcount = 0, done = NO; mcount < maxiterations && !done; mcount++) 
    {
      // Set trial price -- various methods
      switch (sptype) 
	{
	case SP_RE:
	  // Rational expectations benchmark:  The rea and reb parameters must
	  // be calculated by hand (highly dependent on agent and dividend).
	  trialprice = rea*dividend + reb;
	  done = YES;		// One pass
	  break;
	  
	case SP_SLOPE:
	  if (mcount == 0)
	    trialprice = [worldForSpec getPrice];
	  else 
	    {
	      // Use demand and slope information from the agent to set a new
	      // price where the market should clear if the slopes are all
	      // present and correct.  Iterate until it's close or until
	      // maxiterations is reached.
	      imbalance = bidtotal - offertotal;
	      if (imbalance <= minexcess && imbalance >= -minexcess) 
		{
		  done = YES;
		  continue;
		}
	      // Update price using demand curve slope information
	      if (slopetotal != 0)
		trialprice -= imbalance/slopetotal;
	      else
		trialprice *= 1 + eta*imbalance;
	    }
	  break;
	
	case SP_ETA:
	  //Need to use this for ANNagent.
	  if (mcount == 0)
	    {
	      trialprice = [worldForSpec getPrice];
	    }	  
	  else 
	    {
	      trialprice = ([worldForSpec getPrice])*(1.0 + 
                                                   eta*(bidtotal-offertotal));
	      done = YES;	// Two passes
	    }
	  break;
	}

      // Clip trial price
      if (trialprice < minprice) 
	trialprice = minprice;
      if (trialprice > maxprice) 
	trialprice = maxprice;
      
      // Get each agent's requests and sum up bids, offers, and slopes
      bidtotal = 0.0;
      offertotal = 0.0;
      slopetotal = 0.0;
      index = [agentList begin: [self getZone]];
      while ((agent = [index next])) 
	{
	  slope = 0.0;
	  demand = [agent getDemandAndSlope: &slope forPrice: trialprice];
	  slopetotal += slope;
	  if (demand > 0.0)      
	    bidtotal += demand;
	  else if (demand < 0.0) 
	    offertotal -= demand;
	  //printf("bidtotal is %f and offertotal is %f.\n",bidtotal,offertotal);
	}
      [index drop];

      // Match up the bids and offers
      volume = (bidtotal > offertotal ? offertotal : bidtotal);
      bidfrac = (bidtotal > 0.0 ? volume / bidtotal : 0.0);
      offerfrac = (offertotal > 0.0 ? volume / offertotal : 0.0);
    }
  
  return trialprice;
}

/*"Returns the volume of trade to anybody that wants, such as the observer or output objects"*/
- (double)getVolume
{
  return volume;
}


- completeTrades: agentList Market: worldForSpec
/*"Updates the agents cash and position to consummate the trades
  previously negotiated in -performTrading, with rationing if
  necessary.

 * Makes the actual trades at the last trial price (which is now the
 * market price), by adjusting the agents' holdings and cash.  The
 * actual purchase/sale my be less than that requested if rationing
 * is imposed by the specialist -- usually one of "bidfrac" and
 * "offerfrac" will be less than 1.0.
 *
 * This could easiliy be done by the agents themselves, but we let
 * the specialist do it for efficiency.
 "*/
{
  Agent * agent;
  id index;
  double bfp, ofp, tp, profitperunit;
  double price = 0.0; //pj: was IVAR


  price = [worldForSpec getPrice];
  profitperunit = [worldForSpec getProfitPerUnit];

// Intermediates, for speed
  bfp = bidfrac*price;
  ofp = offerfrac*price;
  tp = taupnew*profitperunit;

// Loop over enabled agents
  index = [agentList begin: [self getZone]];

  while ((agent = [index next])) 
    {
      // Update profit (moving average) using previous position
      agent->profit = taupdecay*agent->profit + tp*agent->position;

      // Make the actual trades
      if (agent->demand > 0.0) 
	{
	  agent->position += agent->demand*bidfrac;
	  agent->cash     -= agent->demand*bfp;
	}
      else if (agent->demand < 0.0) 
	{
	  agent->position += agent->demand*offerfrac;
	  agent->cash     -= agent->demand*ofp;
	}
    }

  [index drop];
  return self;
}


@end











