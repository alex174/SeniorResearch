#import <objectbase/SwarmObject.h>

 
//Macros for bittables
#define WORD(bit)	(bit>>4)
#define MAXCONDBITS	80


id
makeProbe (id obj, const char *ivarName);

double
getDouble (id obj, const char *ivarName);

int
getInt (id obj, const char *ivarName);


@interface BFParams:  SwarmObject
{
  @public
    int numfcasts; /*"number of forecasts maintained by this agent"*/
  int condwords; /*"number of words of memory required to hold bits"*/
  int condbits; /*"number of conditions bits are monitored"*/
  int mincount; /*"minimum number of times forecast must be used to become active"*/
  int gafrequency; /*"how often is genetic algorithm done?"*/
  int firstgatime; /*"after how many time steps is the genetic algorithm done"*/
  int longtime;	/*" unused time before Generalize() in genetic algorithm"*/
  int individual;
  double tauv;
  double lambda;
  double maxbid;
  double bitprob;
  double subrange;	/*" fraction of min-max range for initial random values"*/
  double a_min,a_max;	/*" min and max for p+d coef"*/
  double b_min,b_max;	/*" min and max for div coef"*/
  double c_min,c_max;	/*" min and max for constant term"*/
  double a_range,b_range,c_range;	/*" derived: max - min" */
  double newfcastvar;	/*" variance assigned to a new forecaster"*/
  double initvar;	/*" variance of overall forecast for t<200"*/
  double bitcost;	/*" penalty parameter for specificity"*/
  double maxdev;	/*" max deviation of a forecast in variance estimation"*/
  double poolfrac;	/*" fraction of rules in replacement pool"*/
  double newfrac;	/*" fraction of rules replaced"*/
  double pcrossover;	/*" probability of running Crossover()."*/
  double psocial;       /*" probability for social behaviour of the agents."*/
  int startsocial;      /*" beginning of social behaviour."*/
  double plinear;	/*" linear combination "crossover" prob."*/
  double prandom;	/*" random from each parent crossover prob."*/
  double pmutation;	/*" per bit mutation prob."*/
  double plong;	        /*" long jump prob."*/
  double pshort;	/*" short (neighborhood) jump prob."*/
  double nhood;	        /*" size of neighborhood."*/
  double genfrac;	/*" fraction of 0/1 bits to generalize"*/
  double gaprob;	/*" derived: 1/gafrequency"*/
  int npool;		/*" derived: replacement pool size"*/
  int nnew;		/*" derived: number of new rules"*/
  int nnulls;            /*" unnused bits"*/
  int npoolmax ;		/* size of reject array */
  int nnewmax ;		/* size of newfcast array */
  int ncondmax;		/* size of newc*/
  int *bitlist;		/*" dynamic array, length condbits"*/
  double *problist;	/*" dynamic array, length condbits"*/
 
};


- init;

- (int*)getBitListPtr;
- (void)copyBitList: (int *) p Length: (int) size;


- (double *)getProbListPtr;
- (void)copyProbList: (double *) p Length: (int) size;
- (BFParams *) copy: (id <Zone>) aZone;


- (void)lispOutDeep: stream;

@end




