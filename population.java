package asm;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Random;

public class population {
	
	
	Random rand = new Random();
	
	
	//define population parameters
	int popsize;
	double meansent;
	double meanrisktol;
	double meanopt;
	double meanadapt;
	double meanreact;
	
	double stdsent;
	double stdrisk;
	double stdopt;
	double stdadapt;
	double stdreact;
	
	double balance;
	
	ArrayList<agent> pop = new ArrayList<agent>(0);
	
	
	public population(int ps, double ms, double mr, double mo, double ma, double mre, double std, double bal, double shares) {
		popsize=ps;
		meansent=ms;
		meanrisktol=mr;
		meanopt=mo;
		meanadapt=ma;
		meanreact=mre;
		
		stdsent=std;
		stdrisk=std;
		stdopt=std;
		stdadapt=std;
		stdreact=std;
		
		balance=bal;
		double indshares=shares/ps;
		for(int i=0; i<popsize; i++){
			double sen=rand.nextGaussian()*stdsent+meansent;
			if(sen>1){
				sen=1;
			}
			if(sen<0){
				sen=0;
			}
			double ris=rand.nextGaussian()*stdrisk+meanrisktol;
			if(ris>1){
				ris=1;
			}
			if(ris<0){
				ris=0;
			}
			double opt=rand.nextGaussian()*stdopt+meanopt;
			if(opt>1){
				opt=1;
			}
			if(opt<0){
				opt=0;
			}
			double ada=rand.nextGaussian()*stdadapt+meanadapt;
			if(ada>1){
				ada=1;
			}
			if(ada<0){
				ada=0;
			}
			double rea=rand.nextGaussian()*stdreact+meanreact;
			if(rea>1){
				rea=1;
			}
			if(rea<0){
				rea=0;
			}
			agent trader= new agent(balance,sen,ris,opt,ada,rea,i,indshares);
			pop.add(trader);
		}
	}
	
	public ArrayList<agent> returnpop(){
		return pop;
	}
	
}
