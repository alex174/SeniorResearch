// Interface for LIagent -- linear predictors

#import "Forecaster.h"

#define NTYPES	5

@interface LIagent: Forecaster
{
    double oldreturn;
    double mr;
    double pa;
    double pb;
    double rho;
    double sigma;
    double dmean;
    
@public
    int predictortype[NTYPES];
}

- makePredictor:(int)f;
- (BOOL)predict:(int)f return:(double *)forecast forPrice:(double)p;

@end
