package asm;
import java.util.ArrayList;
import java.util.Arrays;

public class agent{
	
	//how much $$ the agent has
	public double balance;
	
	public double networth=0;
	
	//how many shares the agent owns
	public double shares;
	int id=0;
	public double order=0;
	
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
	
	Double[] nwHistory = new Double[2];
	
	//Initialize a new agent with the given parameter values
	public agent(double bal, double sen, double ris, double opt, double ada, double rea, int idd, double shrs, double sp) {
		balance=bal;
		sentimentality=sen;
		riskTolerance=ris;
		optimism=opt;
		adaptability=ada;
		reactionism=rea;
		shares=shrs;
		id=idd;
		networth=shares*sp+bal;
		nwHistory[0]=networth;
		nwHistory[1]=networth;
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
		
		//calculate net worth
		networth=stockPrice*shares+balance;
		nwHistory[1]=networth;
		
		//calculate change in networth
		double nwDif=nwHistory[1]-nwHistory[0];
		double nwDifPer=nwDif/nwHistory[0];
		
		//calculate change in agent parameters
		this.updateOpt(optimism+nwDifPer*optimism*adaptability);
		this.updateRT(riskTolerance+nwDifPer*riskTolerance*adaptability);
		
		if(reactionism>=0.5)
		{
			this.updateRea(reactionism+nwDifPer*reactionism*adaptability);
		}
		else{
			this.updateRea(reactionism-nwDifPer*reactionism*adaptability);
		}
		
		//if(sentimentality>=0.5){
		//	this.updatesen(sentimentality+nwDifPer*sentimentality*adaptability);
		//}
		//else{
		//	this.updatesen(sentimentality-nwDifPer*sentimentality*adaptability);
		//}
		
		
		
		this.updatesen(riskTolerance=riskTolerance+nwDifPer*riskTolerance*adaptability);
		
		//since risk tolerance and optimism are finite parameters, they max out at 1
		if(optimism>1) {
			optimism=1;
		}
		if(riskTolerance>1) {
			riskTolerance=1;
		}
		if(sentimentality>1) {
			sentimentality=1;
		}
		if(sentimentality<0) {
			sentimentality=0;
		}
		if(optimism<0) {
			optimism=0;
		}
		if(riskTolerance<0) {
			riskTolerance=0;
		}
		
		//update networth history
		nwHistory[0]=nwHistory[1];
		
		//calculate the total amount of stock that COULD be bought if all $$ was spent
		double couldBuy=Math.floor(balance/stockPrice);
		if(couldBuy<0){
			couldBuy=0;
		}
		
		
		//calculate dif in fundamental value
		double fvDif=Math.abs(stockPrice-fundamentalValue);
		double fvDifPer=fvDif/fundamentalValue;
				
		//check if stock is "undervalued"
		if(stockPrice<fundamentalValue) {
			//the stock is undervalued, buy it up
			analyticalTransact=couldBuy*fvDifPer;
		}
		else if(stockPrice>fundamentalValue){
			//the stock is overvalued, sell it
			analyticalTransact=-1*shares*fvDifPer;
		}
		else{
			analyticalTransact=0;
		}
		
		/*Now, compute what the agent would do if it were entirely irrational (dependent on sentimentality)
		 * this segment is based on neuroeconomics, and will also be improved in the future
		 */
		double emotionalTransact=0;
		
		
		
		/*calculate how much stock the agent would buy/sell based on optimism and risk tolerance (internal irrationality)
		this is done with the assumption that with an optimism of 1 (maxmimum optimism) the agent would buy as much
		stock as possible; alternatively, with an optimism of 0 (lowest optimism), the agent would sell as much stock
		as possible.  an optimism of 0.5 would result in neither buying nor selling
		*/
		double optimismBuy=0;
		
		if(optimism>0.5) {
			optimismBuy=Math.floor((optimism-0.5)*2*couldBuy);
		}
		else if(optimism<0.5) {
			optimismBuy=(optimism-0.5)*2*shares;
		}
		
		//calculate how much the stock the agent would buy/sell based on reactionism (external irrationality)
		//publicConfidence simply indicates whether the public's sentiment toward the stock is positive or negative
		
		double reactionaryBuy=0;
		if(percentChangeInPrice>0) {
			reactionaryBuy=shares*reactionism;
		}
		else if(percentChangeInPrice<0) {
			reactionaryBuy=couldBuy*reactionism;
		}
	
		
		
	    emotionalTransact=(optimismBuy+reactionaryBuy);
	    if(emotionalTransact>couldBuy){
	    	emotionalTransact=couldBuy;
	    }
	    //calculate the total behavior of the agent, giving weight to sentimentality
	    emotionalTransact=sentimentality*emotionalTransact;
	    analyticalTransact=(1-sentimentality)*analyticalTransact;
	    
	    System.out.println(id + " em: " + emotionalTransact+"");
	    System.out.println(id + " an: " + analyticalTransact+"");
	    
	    totalBuy=(emotionalTransact+analyticalTransact)/2;
	    System.out.println(id + " tot: " + totalBuy+"");
	    
	    return totalBuy;
		
		
		
		
		
		
		
		
		
	}
	
	public double returnorder(){
		return order;
	}
	
	public void updateTradingHistory(double gain) {
		tradingHistory.add(gain);
	}
	
	public double returnTHA() {
		return getAvg(tradingHistory);
	}
	
	public double returnopt() {
		return optimism;
	}
	
	public double returnsen() {
		return sentimentality;
	}
	
	public void updatesen(double n) {
		sentimentality=n;
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
	
	public void depositcash(double amt){
		balance=balance+amt;
	}
	
	public void depositshares(double amt){
		shares=shares+amt;
	}
	
	public void withdrawcash(double amt){
		balance=balance-amt;
	}
	
	public void withdrawshares(double amt){
		shares=shares-amt;
	}
	
	public void setorder(double ord){
		order=ord;
	}

	public String getparameters() {
		return "ID: " + id + " Balance: " + balance + " Shares: " + shares + " Sentimentality: " + sentimentality + " Risk Tolerance: " + riskTolerance + " Optimism: " + optimism + " Adaptability: " + adaptability + " Reactionism: " + reactionism;
	}
}
