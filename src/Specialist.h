// The Santa Fe Stockmarket -- Interface for Specialist class

#import <objc/Object.h>

@class Agent;

// These numbers must match the tags of the Specialist popup list.
// Order (here or in IB) doesn't matter; it's all in the tags, which are
// set in the IB inspector panel.
typedef enum {
	SP_ETA=0,
	SP_ADAPTIVEETA=1,
	SP_RE=2,
	SP_VCVAR=3,
	SP_SLOPE=4
} SpecialistType;

@interface Specialist: Object
{
    double maxprice;
    double minprice;
    double eta;
    double etaincrement;
    double etainitial;
    double etamax;
    double etamin;
    double ldelpmax;
    double minexcess;
    double rea;
    double reb;
    double cvar;
    double var;
    double bidfrac;
    double offerfrac;
    Agent **idlist;
    int nenabled;
    int maxiterations;
    int varcount;
    SpecialistType sptype;
}

- initFromFile:(const char *)paramfile;
- writeParamsToFile:(FILE *)fp;
- (double)performTrading;
- completeTrades;
- setParamFromString:(const char *)string;
- setEta:(double)eta;
- setEtaIncrement:(double)etaIncrement;
- (double)eta;
- (double)etaIncrement;
- setSpecialistType:(SpecialistType)stype;
- (SpecialistType)specialistType;
- (const char *)specialistTypeNameFor:(SpecialistType)type;


@end

