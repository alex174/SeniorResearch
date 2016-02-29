// Interface for BSagent class

#import "Agent.h"

// Structure for list of individual rules
struct rules {
	double		strength;
	double		cumulative;
	int		lastactive;
	int		count;
	int		specificity;
	int		action;
	unsigned int	*conditions;
	struct rules	*next;
};

// Parameters common to all agents in a BS type
struct BSparams {
    int class;
    int type;
    int numrules;
    int condwords;
    int condbits;
    int gafrequency;
    int firstgatime;
    int longtime;	// unused time before Generalize()
    double bidsize;
    double maxrstrength;
    double minrstrength;
    double initrstrength;
    double taus;
    double tausdecay;
    double tausnew;
    double bitprob;
    double poolfrac;	// fraction of rules in replacement pool
    double newfrac;	// fraction of rules replaced
    double pcrossover;	// probability of running Crossover() at all.
    double pmutation;	// per bit mutation prob.
    double preverse;	// weak rule reversal prob.
    double genfrac;	// fraction of 0/1 bits to generalize
    double gaprob;	// derived: 1/gafrequency
    int npool;		// derived: replacement pool size
    int nnew;		// derived: number of new rules
    int nnulls;
    int lastgatime;
    int *bitlist;		// dynamic array, length condbits
    double *problist;		// dynamic array, length condbits
    unsigned int *myworld;	// dynamic array, length condwords
} ;


@interface BSagent:Agent
{
@public
    double		avspecificity;
    double		avstrength;
    struct rules	*rule;
    struct rules	*activelist;
    struct rules	*chosenrule;
    struct BSparams	*p;
    int			gacount;
    int			nactive;
}

// CLASS METHODS OVERRIDDEN FROM Agent CLASS
+ initClass:(int)mytype;
+ (void *)createType:(int)mytype :(const char *)filename;
+ writeParams:(void *)theParams ToFile:(FILE *)fp;
+ didInitialize;
+ prepareForTrading:(void *)theParams;
+ (int)lastgatime:(void *)params;

// INSTANCE METHODS OVERRIDDEN FROM Agent CLASS
- initAgent:(int)mytag;
- check;
- (double)getDemandAndSlope:(double *)slope forPrice:(double)trialprce;
- updatePerformance;
- enabledStatus:(BOOL)flag;
- (int)nbits;
- (int)nrules;
- (int)lastgatime;
- (int)bitDistribution:(int *(*)[4])countptr cumulative:(BOOL)cum;
- (const char *)descriptionOfBit:(int)bit;

// INSTANCE METHODS OVERRIDDEN FROM Object CLASS
- free;
#ifdef NEXTSTEP
- copyFromZone:(NXZone *)zone;
#else
- copy;
#endif

@end
