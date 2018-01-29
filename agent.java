
import java.util.ArrayList;
import java.util.Arrays;

public class agent{
	
	//how much $$ the agent has
	public double balance;
	
	//how many shares the agent owns
	public double shares;
	
	//how much of an impact the emotional parameters have on agent behavior
	public double sentimentality;
	
	//emotional parameters, which exist on a spectrum from 0(none) to 1(maximum).  if one of these parameters
	//was 0.5, that means total neutrality
	public double riskTolerance;
	public double optimism;
	public double adaptability;
	public double reactionism;
	
	//the price/earnings ratio of the S&P500, used to determine "fundamental value" of the stock
	public double sp500PE=25.8;
	
	//trading history of the agent (a table filled with the amount of $$ the agent either won or lost on each day
	ArrayList<Double> tradingHistory = new ArrayList<Double>(0);
	
	//Initialize a new agent with the given parameter values
	public agent(double bal, double sen, double ris, double opt, double ada, double rea) {
		balance=bal;
		sentimentality=sen;
		riskTolerance=ris;
		optimism=opt;
		adaptability=ada;
		reactionism=rea;
		shares=0;
	}
	
	public double getAvg(ArrayList<Double> list) {
		double sum = 0;
		  if(!list.isEmpty()) {
		    for (double mark : list) {
		        sum += mark;
		    }
		    return sum / (double)list.size();
		  }
		  else {
			  return 0;
		  }
	}
	
	//Determine the behavior of the individual, as a function of the agent's parameters and the market conditions
	//If the output from this function is positive, it means the agent wishes to purchase stock
	//If the output is negative, it means the agent wishes to sell stock
	public double determineBehavior(double stockPrice, double volatility, double volumeYesterday, double dividend, double percentChangeInPrice) {
		
		/*First, compute what the agent would do if it were entirely rational (analyticalTransact)
		This method uses the current price/earning ratio of the S&P 500 (25.8) to determine the "fundamental value"
		of the stock, given its dividend, and compares that to the stock's current price.
		This method will be improved in the future*/
		
		double fundamentalValue=dividend*sp500PE;
		double currentPERatio=stockPrice/dividend;
		double analyticalTransact=0;
		double totalBuy=0;
		
		//calculate the total amount of stock that COULD be bought if all $$ was spent
		double couldBuy=Math.floor(balance/stockPrice);
				
		//check if stock is "undervalued"
		if(fundamentalValue<=currentPERatio) {
			//the stock is undervalued or "perfectly" valued, buy it up
			analyticalTransact=couldBuy;
		}
		else {
			//the stock is overvalued, sell it
			analyticalTransact=-1*shares;
		}
		
		/*Now, compute what the agent would do if it were entirely irrational (dependent on sentimentality)
		 * this segment is based on neuroeconomics, and will also be improved in the future
		 */
		double emotionalTransact=0;
		double trackRecord=getAvg(tradingHistory);
		//the agent's track record (average $$ won or loss) affects the agent's optimism and risk taking
		//how it precisely affects these parameters will be fine tuned in the future
		double situationalOptimism=optimism+trackRecord;
		double situationalRiskTolerance=riskTolerance+trackRecord;
		//since risk tolerance and optimism are finite parameters, they max out at 1
		if(situationalOptimism>1) {
			situationalOptimism=1;
		}
		if(situationalRiskTolerance>1) {
			situationalRiskTolerance=1;
		}
		/*calculate how much stock the agent would buy/sell based on optimism and risk tolerance (internal irrationality)
		this is done with the assumption that with an optimism of 1 (maxmimum optimism) the agent would buy as much
		stock as possible; alternatively, with an optimism of 0 (lowest optimism), the agent would sell as much stock
		as possible.  an optimism of 0.5 would result in neither buying nor selling
		*/
		double optimismBuy=0;
		
		if(situationalOptimism>0.5) {
			optimismBuy=Math.floor((situationalOptimism-0.5)*2*couldBuy);
		}
		else if(situationalOptimism<0.5) {
			optimismBuy=(situationalOptimism-0.5)*2*shares;
		}
		
		//calculate how much the stock the agent would buy/sell based on reactionism (external irrationality)
		//publicConfidence simply indicates whether the public's sentiment toward the stock is positive or negative
		int publicConfidence=0;
		double reactionaryBuy=0
		if(percentChangeInPrice>0) {
			publicConfidence=1;
			double reactionaryBuy=publicConfidence*reactionism*couldBuy;
		}
		else if(percentChangeInPrice<0) {
			publicConfidence=-1;
			double reactionaryBuy=publicConfidence*reactionism*shares;
		}
		
		
		//calculate the behavior of an enirely rational agent
	    emotionalTransact=optimismBuy+reactionaryBuy;
	    
	    //calculate the total behavior of the agent, giving weight to sentimentality
	    emotionalTransact=sentimentality*emotionalTransact;
	    analyticalTransact=(1-sentimentality)*analyticalTransact;
	    
	    totalBuy=emotionalTransact+analyticalTransact;
		return totalBuy;
		
		
		
		
		
		
		
		
		
	}
	
	public void updateTradingHistory(double gain) {
		tradingHistory.add(gain);
	}
	
	public double returnTHA() {
		return getAvg(tradingHistory);
	}
	
	public void updateRT(double n) {
		riskTolerance=n;
	}
	
	public void updateOpt(double n) {
		optimism=n;
	}
	
	public void updateRea(double n) {
		reactionism=n;
	}
	
	
}
