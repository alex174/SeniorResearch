#import "BFCast.h"
#import "BFParams.h"

@implementation BFCast

- createEnd
{
 if (!condwords || !condbits ){fprintf(stderr,"Must have condwords to create BFCast."); exit(1);}

  forecast= 0.0;
  count = 0;
  lastactive=1;
  specificity = 0;
  variance = 999999999;
  conditions= [ BitVector createBegin: [self getZone] ];
  [conditions setCondwords: condwords];
  [conditions setCondbits: condbits];
  conditions = [conditions createEnd];
  return self;
}

+ init
{
  [BitVector init];
 return self;
}

-(void) drop
{
  [conditions drop];
  [super drop];
}

       
-(void) setCondwords: (int) x
{
  condwords = x;
}

-(void)  setCondbits: (int) x
{
  condbits=x;
}

- (void) setNNulls: (int) x
{
  nnulls= nnulls;
}

- (void) setBitcost: (double) x
{
  bitcost = x;
}
  

-(void) setConditions: (int *) x
{
  [conditions setConditions: x];
}

-(int *) getConditions
{
  return [conditions getConditions];
}


-(BitVector *) getConditionsObject
{
  return conditions;
}


-(void) setConditionsWord: (int) i To: (int) value
{
  [conditions setConditionsWord: i To: value];
}


-(int) getConditionsWord: (int) x
{
  return [conditions getConditionsWord: x];
}


-(void) setConditionsbit: (int) bit To: (int) x
{
  [conditions setConditionsbit: bit To: x];
}


-(void) setConditionsbit: (int) bit FromZeroTo: (int) x
{
  [conditions setConditionsbit: bit FromZeroTo: x];
}


-(int) getConditionsbit: (int)bit
{
  return [conditions getConditionsbit: bit];
}


-(void) maskConditionsbit: (int) bit
{
  // conditions[WORD(bit)] &= NMASK[bit];	
  // specificity --;
  [conditions maskConditionsbit: bit];
}

-(void) switchConditionsbit: (int) bit
{
  //    conditions[WORD(bit)] ^= MASK[bit];
  [conditions switchConditionsbit: bit];
}

-(void) setAval: (double) x
{
  a=x;
}

-(void) setBval: (double) x
{
  b=x;
}

-(void) setCval: (double) x
{ 
  c=x;
}


- (double) getAval
{
  return a;
}


- (double) getBval
{
  return b;
}

- (double) getCval
{
  return c;
}

-(void) updateSpecfactor
{
  //was in BFagent: specfactor = 1.0/(1.0 + x*specificity);
  //but the bfagent.m way is so much nicer
  specfactor= (condbits - nnulls - specificity)* bitcost; //follows bfagent.m
  
}

-(void) setSpecfactor: (double) x
{
  specfactor=x;
};


- (double) getSpecfactor
{
  return specfactor;
}


-(void) incrSpecificity
{
  ++ specificity;
}


-(void) decrSpecificity
{
  --specificity;
}


-(void) setSpecificity: (int) x
{
  specificity=x;
}

-(int) getSpecificity
{
  return specificity;
}

-(void) setVariance: (double) x
{
  variance=x;
}

-(double) getVariance
{
  return variance;
}


-(void) setLastactive: (int) x
{
  lastactive=x;
}

-(int) getLastactive
{
  return lastactive;

}

- (int) getCnt
{
  return count;
}


-(void) setCnt: (int) x
{
  count = x;

}

- (int) incrCount;
{
  return ++count;
}

- (double)  getStrength
{
  return strength;
}


-(void) setStrength: (double) x
{
  strength=x;
}


-(void)  setLforecast: (double) x
{
  lforecast=x;
}

- (double) getLforecast
{
  return lforecast;
}



-(void)  setForecast: (double) x
{
  forecast=x;
}

- (double) getForecast
{
  return forecast;
}

-(double) updateForecastPrice: (double) price Dividend: (double) dividend
{
  lforecast=forecast;
  forecast= a* (price+dividend) + b*dividend + c;
  return forecast;
}


- copyEverythingFrom: (BFCast *) from
{
 forecast= [from getForecast];
 lforecast = [from getLforecast];
 variance = [from getVariance];
 strength =  [from getStrength];
 a= [from getAval];
 b=  [from getBval];
 c=  [from getCval];
 specfactor = [from getSpecfactor];
 lastactive =[from getLastactive];
 specificity = [from getSpecificity];
 count = [from getCnt];
 [self setConditions: [from getConditions]];
 return self;
}

- print
{
  int word;
  printf("BFCast print: forecast %f lforecast %f variance %f strength %f \n",forecast,lforecast,variance,strength);
  for ( word=0; word < condwords; word++)
    [self printcond: word]; 
  printf("a %f b %f c %f specfactor %f, specificity %d count %d lastactive %d \n", a,b,c,specfactor,specificity,count,lastactive);

  return self;
}

- printcond: (int) word
{
  [conditions printcond: word];
  return self;
}




@end










