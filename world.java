package asm;
import java.util.ArrayList;
import java.util.Arrays;

public class world {
	
	public static void main(String[] args){
	
	int days=100;
	
	//define population parameters
	int popsize=10;
	double meansent=0.5;
	double meanrisktol=0.5;
	double meanopt=0.5;
	double meanadapt=0.5;
	double meanreact=0.5;
	double bal=100;
	double std=0.2;
	
	//market parameters
	double stockprice=28;
	double dividend=1;
	int shares=200;
	
	
	//generate agent population
	population pop = new population(popsize,meansent,meanrisktol,meanopt,meanadapt,meanreact,std,bal, shares);
	ArrayList<agent> traders = pop.returnpop();
	
	ArrayList<Double> historicalPrices = new ArrayList<Double>(0);
	

	//generate market
	market mkt = new market(stockprice,shares,dividend);
	
	
	for(int i=0; i<days; i++)
	{
		double borders=0;
		double sorders=0;
		
		double[] stockvars = mkt.returnstockvars();
		double sp=stockvars[0];
		double vola=stockvars[1];
		double volu=stockvars[2];
		double div=stockvars[3];
		double percentchange=stockvars[4];
		System.out.println(percentchange+"%");
		
		for (agent trader : traders) {
	        double order=trader.determineBehavior(sp,vola,volu,div,percentchange);
	        trader.setorder(order);
	        if(order>=0){
	        	borders=borders+order;
	        }
	        else{
	        	sorders=sorders+(-1*order);
	        }
	    }
		double[] fulfillarray=mkt.simulateTrading(borders,sorders);
		double buyorderfulfillment=fulfillarray[1];
		double sellorderfulfillment=fulfillarray[2];
		for (agent trader: traders) {
			double order=trader.returnorder();
			if(order>0){
				double sharesbought=order*buyorderfulfillment;
				double moneyspent=sharesbought*sp;
				trader.depositshares(sharesbought);
				trader.withdrawcash(moneyspent);
			}
			else{
				double sharessold=-1*order*sellorderfulfillment;
				double moneygained=sharessold*sp;
				trader.withdrawshares(sharessold);
				trader.depositcash(moneygained);
			}
		}
		System.out.println(sp+"");
		historicalPrices.add(sp);
	}
	
	for (agent trader : traders) {
		System.out.println(trader.getparameters());
    }
	
	System.out.println(historicalPrices+"");
	
	
	}
}
