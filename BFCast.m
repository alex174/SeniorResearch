#import "BFCast.h"
#import <misc.h>  //for limits.h in print method

#define WORD(bit)	(bit>>4)
#define MAXCONDBITS	80

//needed for bit math. same as in BFAgent.
static int SHIFT[MAXCONDBITS];
static unsigned int MASK[MAXCONDBITS];
static unsigned int NMASK[MAXCONDBITS];

static void makebittables(void);

@implementation BFCast

- createEnd
{
 
  int i;
 if (!condwords ){fprintf(stderr,"Must have condwords to create BFCast."); exit(1);}

  forecast= 0.0;
  count = 0;
  lastactive=1;
  specificity = 0;
  variance = 999999999;
  conditions=[[self getZone] allocBlock: condwords*sizeof(unsigned int)];
  for(i=0;i<condwords;i++)
    conditions[i]=0;
  printf("\n created new forecast \n");

  return self;
}

+ init
{
 makebittables();
 return self;
}

-(void) drop
  {
    [[self getZone] freeBlock: conditions blockSize: condwords*sizeof(unsigned int) ]; 
    printf("Stop you are killing me");
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


-(void) setConditions: (int *) x
{
  int i;
  for(i=0;i<condwords;i++)
      conditions[i]=x[i];
}

-(int *) getConditions
{
  return conditions;
}

-(void) setConditionsWord: (int) i To: (int) value
{
  conditions[i]= value;
}

-(int) getConditionsWord: (int) x
{
  return conditions[x];
}


-(void) setConditionsbit: (int) bit To: (int) x
{
  
  conditions[WORD(bit)] = (conditions[WORD(bit)] & NMASK[bit]) | (x << SHIFT[bit]);
}

-(void) setConditionsbit: (int) bit FromZeroTo: (int) x
{
  conditions[WORD(bit)] |= x <<SHIFT[bit];
}


-(int) getConditionsbit: (int)bit
{
  int value;
  value= (conditions[WORD(bit)] >> SHIFT[bit]) &3;
  return  value;
}

-(void) setConditionsbitToThree: (int) bit
{
  conditions[WORD(bit)] |= MASK[bit];
}


-(void) maskConditionsbit: (int) bit
{
  conditions[WORD(bit)] &= NMASK[bit];	
  // specificity --;
}

-(void) switchConditionsbit: (int) bit
{
    conditions[WORD(bit)] ^= MASK[bit];
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

-(void) setSpecFactorParam: (int) x
{
  specfactor = 1.0/(1.0 + x*specificity);
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
    [self printcond: conditions[word]]; 
  printf("a %f b %f c %f specfactor %f, specificity %d count %d lastactive %d \n", a,b,c,specfactor,specificity,count,lastactive);

  return self;
}

- printcond: (int) cond
{
  int i;
  int n = sizeof(int) * CHAR_BIT;
  int mask = 1 << (n-1);
  int  input=cond;


  for ( i=1; i <= n; ++i)
    {
      putchar(((input & mask) == 0) ? '0' : '1');
      input <<= 1;
      if (i % CHAR_BIT == 0 && i < n)
	putchar(' ');
   }
  return self;
}


static void makebittables()    //declared in BFagent.m
/*
 * Construct tables for fast bit packing and condition checking for
 * classifier systems.  Assumes 32 bit words, and storage of 16 ternary
 * values (0, 1, or *) per word, with one of the following codings:
 * Value       Message-board coding         Rule coding
 *   0			2			1
 *   1			1			2
 *   *			-			0
 * Thus rule satisfaction can be checked with a simple AND between
 * the two types of codings.
 *
 * Sets up the tables to store MAXCONDBITS ternary values in
 * CONDWORDS = ceiling(MAXCONDBITS/16) words.
 *
 * After calling this routine, given an array declared as
 *		int array[CONDWORDS];
 * you can do the following:
 *
 * a. Store "value" (0, 1, 2, using one of the codings above) for bit n with
 *	array[WORD(n)] |= value << SHIFT[n];
 *    if the stored value was previously 0; or
 * 
 * b. Store "value" (0, 1, 2, using one of the codings above) for bit n with
 *	array[WORD(n)] = (array[WORD(n)] & NMASK[n]) | (value << SHIFT[n]);
 *    if the initial state is unknown.
 *
 * c. Store value 0 for bit n with
 *	array[WORD(n)] &= NMASK[n];
 * 
 * d. Extract the value of bit n (0, 1, 2, or possibly 3) with
 *	value = (array[WORD(n)] >> SHIFT[n]) & 3;
 *
 * e. Test for value 0 for bit n with
 *	if ((array[WORD(n)] & MASK[n]) == 0) ...
 *
 * f. Check whether a condition is fulfilled (using the two codings) with
 *	for (i=0; i<CONDWORDS; i++)
 *	    if (condition[i] & array[i]) break;
 *	if (i != CONDWORDS) ...
 *
 */
{
  register int bit;

  for (bit=0; bit < MAXCONDBITS; bit++) 
    {
      SHIFT[bit] = (bit%16)*2;
      MASK[bit] = 3 << SHIFT[bit];
      NMASK[bit] = ~MASK[bit];
    }
}


@end










