#import "BFCast.h"
#import "BFParams.h"
#import <misc.h>

@implementation BFCast
/*"A BFCast is an object that holds all the forcecasting components of
  a bit forecast.  That means it has a BitVector (a thing called
  "conditions" in the code that keeps track of which world bits are
  being monitored) as well as other coefficients that are used to
  calculate forecasts. It has instance variables that record when the
  rule was last used, how many times it has been used, how accururate
  its predictions are, and so forth."*/


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

/*"The init is needed because BitVector has to be told how bit of a
  bit vector it will need"*/
+ init
{
  [BitVector init];
 return self;
}

/*"Free dynamically allocated memory"*/
-(void) drop
{
  [conditions drop];
  [super drop];
}

/*"Sets the number of words-worth's of conditions that are going to be used"*/       
-(void) setCondwords: (int) x
{
  condwords = x;
}

/*"Sets the number of bits. This is the number of aspect of the world that are monitored"*/
-(void)  setCondbits: (int) x
{
  condbits=x;
}

/*"Null bits may be needed if the bit vector that is allocated is larger than the number of conditions being monitored. Since a bitvector allocates space in sizes of words, this might be important. Luckily, in the current design of ASM-2.0 (and after), there are no null bits."*/
- (void) setNNulls: (int) x
{
  nnulls= nnulls;
}

/*"Set the variable bitcost at x"*/
- (void) setBitcost: (double) x
{
  bitcost = x;
}
  
/*"Rather than individually set bits one by one, we might want to set
  all of them at once. That means we pass in a pointer to an array of
  words that is the "right size" for all the bits."*/
-(void) setConditions: (int *) x
{
  [conditions setConditions: x];
}

/*"Returns a pointer to an array, the integer representation of the
  conditions"*/
-(int *) getConditions
{
  return [conditions getConditions];
}

/*"Returns an object of type BitVector, the represnetation of
  conditions that is actually used inside this class or
  calculations"*/
-(BitVector *) getConditionsObject
{
  return conditions;
}


/*"For low level access to a full word's-worth of the condition"*/
-(void) setConditionsWord: (int) i To: (int) value
{
  [conditions setConditionsWord: i To: value];
}

/*"Returns the integer representation of the x'th word in the
  conditions"*/
-(int) getConditionsWord: (int) x
{
  return [conditions getConditionsWord: x];
}

/*"Sets the value of a bit in the conditions"*/
-(void) setConditionsbit: (int) bit To: (int) x
{
  [conditions setConditionsbit: bit To: x];
}

/*"If a bit is currently set to 0 ("don't care"), then change it to
  something else (1 or 2)"*/
-(void) setConditionsbit: (int) bit FromZeroTo: (int) x
{
  [conditions setConditionsbit: bit FromZeroTo: x];
}

/*"Returns 0,1,or 2, for a given bit in the conditions records"*/
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


/*"Change a YES to a NO, and vice versa"*/
-(void) switchConditionsbit: (int) bit
{
  // conditions[WORD(bit)] ^= MASK[bit];
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










