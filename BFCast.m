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
  return self;
}

/*"The init is needed because BitVector has to be told how big of a
  bit vector it will need"*/
+ init
{
  [BitVector init];
 return self;
}


- init
{
  forecast= 0.0;
  count = 0;
  lastactive = lastused = 1;
  specificity = 0;
  variance = 999999999;
  if (!condwords || !condbits ){fprintf(stderr,"BFCast: Must have condwords to create BFCast."); exit(1);}
  conditions= [ BitVector createBegin: [self getZone] ];
  [conditions setCondwords: condwords];
  [conditions setCondbits: condbits];
  conditions = [conditions createEnd];
  [conditions init];
  return self;
}

/*"Free dynamically allocated memory"*/
- (void)drop
{
  [conditions drop];
  [super drop];
}

/*"Sets the number of words-worth's of conditions that are going to be used"*/       
- (void)setCondwords: (int)x
{
  condwords = x;
}

/*"Sets the number of bits. This is the number of aspect of the world that are monitored"*/
- (void)setCondbits: (int)x
{
  condbits = x;
}

/*"Null bits may be needed if the bit vector that is allocated is larger than the number of conditions being monitored. Since a bitvector allocates space in sizes of words, this might be important. Luckily, in the current design of ASM-2.0 (and after), there are no null bits."*/
- (void) setNNulls: (int) x
{
  nnulls = nnulls;
}

/*"Set the variable bitcost at x"*/
- (void) setBitcost: (double) x
{
  bitcost = x;
}
  
/*"Rather than individually set bits one by one, we might want to set
  all of them at once. That means we pass in a pointer to an array of
  words that is the "right size" for all the bits."*/
- (void) setConditions: (int *)x
{
  [conditions setConditions: x];
}

/*"Returns a pointer to an array, the integer representation of the
  conditions"*/
- (int *)getConditions
{
  return [conditions getConditions];
}

/*"Returns an object of type BitVector, the represnetation of
  conditions that is actually used inside this class or
  calculations"*/
- (BitVector *)getConditionsObject
{
  return conditions;
}


/*"For low level access to a full word's-worth of the condition"*/
- (void)setConditionsWord: (int)i To: (int)value
{
  [conditions setConditionsWord: i To: value];
}

/*"Returns the integer representation of the x'th word in the
  conditions"*/
- (int)getConditionsWord: (int)x
{
  return [conditions getConditionsWord: x];
}

/*"Sets the value of a bit in the conditions"*/
- (void)setConditionsbit: (int)bit To: (int)x
{
  [conditions setConditionsbit: bit To: x];
}

/*"If a bit is currently set to 0 ("don't care"), then change it to
  something else (1 or 2)"*/
- (void)setConditionsbit: (int)bit FromZeroTo: (int)x
{
  [conditions setConditionsbit: bit FromZeroTo: x];
}

/*"Returns 0,1,or 2, for a given bit in the conditions records"*/
- (int)getConditionsbit: (int)bit
{
  return [conditions getConditionsbit: bit];
}


- (void)maskConditionsbit: (int)bit
{
  [conditions maskConditionsbit: bit];
}


/*"Change a YES to a NO, and vice versa"*/
- (void)switchConditionsbit: (int)bit
{
  // conditions[WORD(bit)] ^= MASK[bit];
  [conditions switchConditionsbit: bit];
}

/*"Set a coefficient from demand equation"*/
- (void)setAval: (double)x
{
  a = x;
}

/*"Set b coefficient from demand equation"*/
- (void)setBval: (double)x
{
  b = x;
}

/*"Set c coefficient from demand equation"*/
- (void)setCval: (double)x
{ 
  c = x;
}

/*"Return a coefficient from demand equation"*/
- (double)getAval
{
  return a;
}

/*"Return b coefficient from demand equation"*/
- (double)getBval
{
  return b;
}

/*"Return c coefficient from demand equation"*/
- (double)getCval
{
  return c;
}

/*"Update the spec factor of this forecast. That means calculate:
specfactor= (condbits - specificity)* bitcost
"*/
- (void)updateSpecfactor
{
  specfactor = (condbits - specificity)* bitcost;
}

/*"Set the specfactor value of this forecast"*/
- (void)setSpecfactor: (double)x
{
  specfactor = x;
}

/*"Return the specfactor value of this forecast"*/
- (double)getSpecfactor
{
  return specfactor;
}

/*"Raise the specificity value of this forecast by one unit"*/
- (void)incrSpecificity
{
  ++ specificity;
}

/*"Reduce the specificity value of this forecast by one unit"*/
- (void)decrSpecificity
{
  --specificity;
}

/*"Set the specificity of this forecast"*/
- (void)setSpecificity: (int) x
{
  specificity = x;
}

/*"Return the specificity of this forecast"*/
- (int)getSpecificity
{
  return specificity;
}

/*"Set the variance of this forecast"*/
- (void)setVariance: (double)x
{
  variance=x;
}

/*"Return the variance of this forecast"*/
- (double)getVariance
{
  return variance;
}

/*"Set the actual variance of this forecast"*/
- (void)setActvar: (double)x
{
  actvar=x;
}

/*"Return the variance of this forecast"*/
- (double)getActvar
{
  return actvar;
}


/*"Set the time on which this forecast was last active to an input value"*/
- (void)setLastactive: (int)x
{
  lastactive = x;
}

/*"Return the time on which this forecast was last active"*/
- (int)getLastactive
{
  return lastactive;

}

/*"Set the time on which this forecast was last active to an input value"*/
- (void)setLastused: (int)x
{
  lastused = x;
}

/*"Return the time on which this forecast was last active"*/
- (int)getLastused
{
  return lastused;

}

/*"Return the value of count"*/
- (int)getCnt
{
  return count;
}


/*"Set the count variable to an inputted value"*/
- (void)setCnt: (int)x
{
  count = x;

}

/*"Increment this forecast's count variable"*/
- (int)incrCount;
{
  return ++count;
}

/*"Return strength of this forecast"*/
- (double)getStrength
{
  return strength;
}


/*"Set the strength value to an inputted value"*/
- (void) setStrength: (double)x
{
  strength = x;
}

/*"Set the previous forecast of this object to an inputted value"*/
- (void)setLforecast: (double)x
{
  lforecast = x;
}

/*"Get forecast from the previous time period"*/
- (double)getLforecast
{
  return lforecast;
}


/*"Set the forecast of this object to an inputted value"*/
- (void)  setForecast: (double) x
{
  forecast = x;
}

/*"Return forecast from this object"*/
- (double)getForecast
{
  return forecast;
}

/*"Calculate new forecast on basis of price and dividend information"*/
- (double) updateForecastPrice: (double)price Dividend: (double)dividend
{
  lforecast = forecast;
  forecast = a* (price+dividend) + b*dividend + c;
  return forecast;
}


/*"Given an input forecast object, systematically ask it for
  all its IVARs and replace current settings with them."*/
- copyEverythingFrom: (BFCast *)from
{
 forecast = [from getForecast];
 lforecast = [from getLforecast];
 variance = [from getVariance];
 actvar = [from getActvar];
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

/*"Return some disgnostic information about the status of
  variables inside this forecast to the terminal"*/
- print
{
  int word;
  printf("BFCast print: forecast %f lforecast %f variance %f strength %f \n",forecast,lforecast,variance,strength);
  for ( word=0; word < condwords; word++)
    [self printcond: word]; 
  printf("a %f b %f c %f specfactor %f, specificity %d count %d lastactive %d \n", a,b,c,specfactor,specificity,count,lastactive);

  return self;
}

- printcond: (int)word
{
  [conditions printcond: word];
  return self;
}


@end










