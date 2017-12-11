
import java.util.ArrayList;
import java.util.Arrays;

public class market{
	
	//the price of the simulated stock
	public double stockPrice;
	
	//orders to buy the stock
	public double buyOrders;
	
	//orders to sell the stock
	public double sellOrders;
	
	//market constant, determines how price is affected by supply and demand
	public double marketConstant=0.1;
	
	//how many shares have been issued
	public int sharesIssued;
	
	//the dividend paid by the stock every 365 days
	public double dividend=10;
	
	//Initialize a new market with the given parameter values
	public market(double sp, int si) {
		stockPrice=sp;
		buyOrders=0;
		sellOrders=0;
		sharesIssued=si;
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
	
	public double[] simulateTrading(double bOrders, double sOrders) {
		
		//this array will contain the information regarding how the buy and sell orders are paid out
		double[] resultsArray;
		resultsArray = new double[5];

	    
		buyOrders=bOrders;
		sellOrders=sOrders;
		
		//calculate the results array if demand>supply and vice versa
		if(buyOrders>sellOrders) {
			//the amount of shares which are transacted is equal to the amount of sell orders submitted
			resultsArray[0]=sellOrders;
			//sell orders will be entirely fulfilled
			resultsArray[2]=1;
			//calculate the degree to which the buy orders will be fulfilled
			resultsArray[1]=sellOrders/buyOrders;
		}
		else if(sellOrders>buyOrders) {
			//the amount of shares which are transacted is equal to the amount of buy orders submitted
			resultsArray[0]=buyOrders;
			//buy orders will be entirely fulfilled
			resultsArray[1]=1;
			//calculate the degree to which the sell orders will be fulfilled
			resultsArray[2]=buyOrders/sellOrders;
		}
		else {
			//if the amount of buy and sell orders are equal, then all orders are fulfilled ocmpletely
			resultsArray[0]=1;
			resultsArray[1]=1;
			resultsArray[2]=1;
		}
		
		//calculate the change in price of the stock
		stockPrice=stockPrice+marketConstant*(buyOrders-sellOrders);
		resultsArray[4]=stockPrice;
		
		//calculate the new dividend for the stock
		
		
		return(resultsArray); 
	      
		
	}
	
	
	
	
}
