#import <objectbase/SwarmObject.h>


@interface BFCast: SwarmObject
{
  double forecast;	// this forecast of return
  double lforecast;	// previous forecast
  double variance;	// variance of this forecast
  double strength;
  double a;		// (price + dividend) coefficient
  double b;		// dividend coefficient
  double c;		// constant term
  double specfactor;	// specificity factor; strength=specfactor/variance
  double bitcost;

//    struct BF_fcast *next;	// linked list of ACTIVE forecasts
//    struct BF_fcast *lnext;
  unsigned int *conditions;
  int lastactive;
  int specificity;
  int count;
  int condwords;
  int condbits;
  int nnulls;
};


- createEnd;

-(void) incrSpecificity;

-(void) decrSpecificity;

-(void) setSpecificity: (int) specificity;

-(int) getSpecificity;

-(void) setConditions: (int *) x;

-(int *) getConditions;


- (void) setNNulls: (int) x;

- (void) setBitcost: (double) x;

-(void) setConditionsWord: (int) i To: (int) value;

-(int) getConditionsWord: (int) x;

-(void) setConditionsbit: (int) bit To: (int) x; //works for 0,1,2

-(void) setConditionsbit: (int) bit FromZeroTo: (int) x;//faster if cond[bit]=0

-(void) setConditionsbitToThree: (int) bit;

-(void) maskConditionsbit: (int) bit;

-(void) switchConditionsbit: (int) bit;

-(int) getConditionsbit: (int)bit;

-(void) setAval: (double) x;

-(void) setBval: (double) x;

-(void) setCval: (double) x;

- (double) getAval;

- (double) getBval;

- (double) getCval;

-(void) updateSpecfactor;

-(void) setSpecfactor: (double) x;

- (double) getSpecfactor;

- (void) setVariance: (double) x;
       
-(double) getVariance;

-(void) setCondwords: (int) x;

-(void)  setCondbits: (int) x;

-(void)  setForecast: (double) x;

- (double) getForecast;

-(double) updateForecastPrice: (double) price Dividend: (double) dividend;

-(void)  setLforecast: (double) x;

- (double) getLforecast;

-(void) setLastactive: (int) x;

-(int) getLastactive;

-(void) setCnt: (int) x;

-(int) getCnt;

- (int) incrCount;

-(void) setStrength: (double) x;

- (double)  getStrength;

- copyEverythingFrom: (BFCast *) from;

- print;

- printcond: (int) conditions;

-(void) drop;

@end







