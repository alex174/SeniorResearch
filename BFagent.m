// Code for a "bitstring forecaster" (BF) agent

/*
pj: change comments June 2, 2000

I began with the code as released by the ASM research team through
Brandon Weber in April, 2000.  Here is a summary of the vital changes
that affect the BFagent class.

0. New classes used in this version:
    A. BFCast.[hm]
    B. BFParams.[hm]
    C. BitVector.[hm]

1. I am fully aware of confusion about the meaning of bit in this
model. Bit does usually mean something that is 0 or 1, but in this
model it means something else.  In the agent, a bit is what is often
called a "trit", something that is valued 00, 01, 10, or 11. Trit
means smallest thing that can hold three values.  In these agents, a
trit has these meanings:

  binary value    integer equivalent   meaning 
  00                 0                  # or "don't care"
  01                 1                  NO
  10                 2                  YES
  11                 3                  not in use, a place holder value 

GET READY for the big surprise. In World.m, the coding is reversed, so
01 means yes and 10 means no.  This accelerates the comparision of the
agent's bit vector against the state of the world.  Look for the & in
the-updateActiveList: medthod and you'll see why.  I've written an
alternative, more transparent algorithm.  I don't think it takes much
more time, but perhaps your computer will tell differently.

2. The bit math got frustrating enough that I have segregated it in a
class I call "BitVector".  It is really a vector of "trits" but so
much of the rest of this code uses the term bit that I didn't have the
enthusiasm to change it.  When a "BitVector" instance is created, it
has to be told how many bits, er trits, of information it is supposed
to hold.  Whenever the agent needs to keep track of a bunch of bits,
er trits, it can create a BitVector object to do it, and the interface
allows values to be put in and retrieved in a relatively obvious way.

Furthermore, when agents create the "forecast objects" using the
BFCast class, then those forecast objects will contain within them
BitVector objects that keep track of that forcast's object's bits.

3. The BFCast class now has taken the place of the struct BF_cast that
was in BFagent.h.  Any bit manipulation that needs to be done can be
done by talking to an instance of that class. The bit manipulation is
hidden from this BFagent class, so at some time in the future we could
re-implement BFCast and as long as it had the right interface, the
BFagent would not care.  The BFCast class talks to the forecast object
that is inside it and tells it to set bits (er, trits) to certain
values with messages like "setConditionsbit: 5 To: 2" and BFCast can
handle the rest by passing on the news to the BitVector object.

4. The BFParams class now has taken the place of the struct BF_Params
that was in BFagent.  This change allows some significant upgrades in
functionality.  First, the BFParams class uses the Swarm
lispAppArchiver.  See the initial values in asm.scm.  Because the
BFParams object contains some variables that are derived from the
values in the archiver, it is necessary to send an "init" message
after creating a BFParams object. Second, it is now possible to
customize the agents by creating a customized BFParams object for each
agent.  In the original ASM-2.0 code, there is a "global" variable
params and all agents use that one set of parameters.  So far, I not
done much to investigate the advantages of allowing agents to use
different numbers of bits (er, trits), but I intend to.  Until I do
that, the instance variable "privateParams" simply points to the same
single BFParams object that is created by ASMModelSwarm, and
parameters retrieved from either are thus the same.  

<Apology mode> Note further, I did not write "get" methods for every
variable in the BFParams class. It just seemed onerous to do so.
There are 2 ways to get values out of BFParams.  First, use the ->.  I
declared the IVARS in BFParams to be public, so they can be retrieved
with the symbol -> as if the parameter object were a pointer to a
struct, as in: privateParams->condwords.  I hate doing that, and have
the long term plan of replacing all of these usages with get messages.
Second, for the short term, I put in the getDouble() and getInt()
functions which can be used to do get values. These will work even for
private variables, so if you get concerned about declaring all those
public IVARS in BFParams, you can get values in this way:
getInt(privateParams,"condwords").  I used that a number of times in
this file, but not everywhere, because I got tired of typing.
</Apology mode>

5. More object orientation.  The "homemade" linked lists, built with
pointers and other C concepts, are replaced by Swarm collections.
Iteration now uses Swarm index objects.  Many usages of C alloc and
calloc are eliminated.  This should approach a high level of readability.

Example: code that used to look like this for looping through a list:
   struct BF_fcast *fptr, *topfptr;
   topfptr = fcast + p->numfcasts;
   for (fptr = fcast; fptr < topfptr; fptr++) 
      {
	if (fptr->conditions[0] & real0) continue;
	*nextptr = fptr;
	nextptr = &fptr->next;
      }

Now it looks like this:
   id <Index> index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      if ( [aForecast getConditionsWord: 0] & real0 )   continue ;
      //if that's true, this does not get done:
      [activeList addLast: aForecast];
    }
    [index drop];

Example 2: What was like this:
  for (fptr = fcast; fptr < topfptr; fptr++) 
    {
      agntcond = fptr->conditions;
      for (i = 0; i < condbits; i++)
	count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
    }
Is now like this:
 index=[ fcastList begin: [self getZone] ];  
 for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
   {
     agntcond = [aForecast getConditions];
      for (i = 0; i < condbits; i++)
	{
	    count[ (int)[aForecast getConditionsbit: i]][i]++;
	}
   }
 [index drop];
 
Note the usage of Swarm lists, indexes, and methods like
"getConditionsbit" and "getConditionsWord", instead of bitmath.

Usage of pointers to arrays is now minimized as well.  There used to
be a class method called +prepareForTrading that would retrieve a copy
of all the world's information and pick out what was needed for an
agent of this class.  Then the result of that calculation would get
stored in world.  While this had the advantage of doing the
calculation once for all agents of the class, it has the disadvantage
of restricting us to having identical bit vectors in all agent
forecasts.  I've dropped this approach, instead creating a variable
myworld in the agent's -prepareForTrading method, and each agent can
look to the world and get the information it wants.


6. Think locally, act locally.  Global pointers and lists and anything
else have been replaced wherever possible by automatic variables
(inside methods) or instance variables.  I created several new methods
that take bits from bit methods/functions and do them in isolation
(see -updateActiveList or -collectWorldData.

7. Genetic Algorithm now is written in Obj-C methods that pass whatever 
arguments are needed, rather than using C functions that access a lot 
of global variables. Agent's don't share workspace for the GA, either, 
each has its own memory.  

8. Formulas to calcuate strength, specfactor, and variance in the 
forecast objects were different in the original BFagent.m than in 
the bfagent.m.  Since the bfagent.m file matched the documentation 
released with ASM-2.0, I have changed to use the bfagent.m formulas 
in this file.  Some cleanup can still be made.  */


#import "BFagent.h"
#import <random.h> 
#import "World.h"
#include <misc.h>
#import "BFParams.h"
#import "BFCast.h"
#import "BitVector.h"

extern World *worldForAgent;
//pj: wish I could get rid of that one too, since each agent could
//just have a pointer pj: to a common world object. However, there are
//serveral class methods that use it.

//pj: 
//convenience macros to replace stuff from ASM random with Swarm random stuff 
 
#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 
#define urand()  [uniformDblRand getDoubleWithMin: -1 withMax: 1] 
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1]  
 
//Macros for bit manipulation
//pj: Sometimes I use these for diagnostic checking.
//  #define WORD(bit)	(bit>>4)
//  #define MAXCONDBITS	80
//  #define extractvalue(variable, trit) ((variable[WORD(trit)] >> ((trit%16)*2))&3) 
//  #define ifnilgetzero(variable, trit)  ((variable[WORD(trit)]& (3<<((trit%16)*2))))


// Type of forecasting.  WEIGHTED forecasting is untested in its present form.
//pj: bluntly, WEIGHTED does not work and is incomplete
#define WEIGHTED 0

//static void makebittables(void); //now in BFCast.m

//pj: this is a static global declaration of the params object, shared by all instances.
//pj: note there is also a local copy which is, in current code, intitially the same thing,
//pj: and it never changes.  The original code had 3 of these, so I'm slimmer by 1/3.
static BFParams *  params;

//pj: other global variables were moved either to the performGA method where they are 
//pj: needed or into the BFParams class, where they are used to create BFParams objects

//pj:  ReadBitname moved to BFParams

//pj: This is the only global variable I still need, and I'm looking for a way go get rid of it!
  static double minstrength;	


// PRIVATE METHODS
@interface BFagent(Private)
//pj: methods now replace previous functions:
- (BFCast *)  CopyRule:(BFCast *) to From: (BFCast *) from;
- (void) MakePool: rejects From: (id <Array>) list;
- (BOOL) Mutate: (BFCast *) new Status: (BOOL) changed;
- (BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2;
- (void) TransferFcastsFrom: newList To:  forecastList Replace: rejects; 
- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects;
- (void) Generalize: (id) list AvgStrength: (double) avgstrength;
- (BFCast *) Tournament: (id <Array>) list;

@end


@implementation BFagent
/*"The BFagent--"bit forecasting agent" is the centerpiece of the ASM
model.  The agent competes in a stock market, it buy, it sells.  It
decides to buy or sell by making predictions about what the price of
the stock is likely to do in future.  In order to make predictions, it
keeps a large list of forecast objects on hand, and each forecast
object makes a price prediction. These forecasts, which are created
from the BFCast subclass, are fairly sophisticated entities, they may
monitor many different conditions of the world.  The forecast which is
the best historical record at any given instant is used to predict the
future price, which in turn leads to the buy/sell decision. 

Inside the file BFagent.m, there is a long set of comments about the
updating that went on in the redesign of this code for ASM-2.2.  In
order to faciliate this revision, several new classes were introduced.
BFParams is an object that keeps values of the parameters for
BFagents, and BFCast is the forecast object itself.  BFCast, in turn,
keeps its conditions bits with a subclass called BitVector.

If you dig into the code of this agent, you will find a confusing
thing, so be warned. This code and articles based on it use the term
"bit" to refer to something that can be valued either 0, 1, or 2. 0
means "don't care," 1 means "NO" and 2 means "YES".  The confusing
thing is that it takes two bits to represent this amount of
information. In binary, the values would be {00,01,10},
respectively. I'm told some people call these trits to keep that in
mind that two digits are required.  As a result of the fact that it
takes "two bits" to store "one bit's" worth of information, some
relatively complicated book keeping has to be done.  That's where all
the parameters like "condbits" and "condwors" come into play.  In
ASM-2.0, that book keeping was all "manually done" right here in
BFagent.m, but in the 2.2 version, it is all hidden in the subclass
BitVector.  So, for purposes of the interface of this class, a bit is
a 3 valued piece of information, and values of bits inside forecasts
are set by messages to the forecast, like [aForecast setConditionsbit:
bit FromZeroTo: 2], for example, will set that bit to 2. If you want
to know if a forecast has YES or NO for a bit x, [aForecast
getConditionsbit: x].  "*/


/*"This tells BFagents where they should look to get values for their parameters. it shoud give the agent an object from the BFParams class."*/
+(void) setBFParameterObject: x
{
    params=x;
}

/*"This is vital to set values in the forecast class,  BFCast, which in turn initializes BitVector"*/
+(void) init
{
  [BFCast init]; 
  return;
}

// This was a big result of code cleanup!
// These class methods are not needed anymore
//  +didInitialize
//  +prepareForTrading      //called at the start of each trading period

// Also, we don't need a class method here for this. If you need something like
//it, put it in BFParams.  
//+(int)lastgatime 
//  {  pp = (struct BFparams *)params; 
//   return pp->lastgatime; 
//  }


//pj: Watch out with this one, there are pointers flying everywhere!
//It is a superflous method that is not called anymore, it scared me
//so much.  

//+setRealWorld: (int *)array { [worldForAgent getRealWorld:
//array]; return self; }

// superfluous method: never called anymore
//  +(int)setNumWorldBits
//  {
//    int numofbits;
//    numofbits = [worldForAgent getNumWorldBits];
//    return numofbits;
//  }


/*"This creates the container objects activeList and oldActiveList.  In addition, it makes sure that any initialization in the createEnd of the super class is done."*/
- createEnd
{
  activeList=[List create: [self getZone]];
  oldActiveList=[List create: [self getZone]];
  return [super createEnd];
}

/*"initForecasts. Creates BFCast objects (forecasts) and puts them
  into an array called fCastList.  These are the "meat" of this
  agent's functionality, as they are repeatedly updated, improved, and
  tested in the remainder of the class.  Note it is conceivable that,
  for some future usage, we want to keep a separate BFParams object
  for each agent. That would allow true diversity!  In the current
  setup, there is no need to do so, so the "private parameters"
  objects (see the IVAR privateParams) of all agents all refer to the
  same, common, public parameter object."*/
- initForecasts
{
  int  sumspecificity = 0;
 
  //pj:new vars
  int i;
  BFCast * aForecast; 
  int numfcasts;
  id index;

// Initialize our instance variables

  //pj: in the future, it may be good to have a separate parameter object for each BFagent.
  //pj: now it makes little sense, so I'm commenting out the creation code here and just setting
  //pj: privateParams equal to the global variable that is passed in.
  //    if ((privateParams =
  //           [lispAppArchiver getWithZone: [self getZone] key: "bfParams"]) == nil)
  //        raiseEvent(InvalidOperation,
  //                   "Can't find the BFParams parameters");
  //      [privateParams init];

  privateParams= params;

  numfcasts=getInt(privateParams,"numfcasts");

  fcastList=[Array create: [self getZone] setCount: numfcasts];

  avspecificity = 0.0;
  gacount = 0;

  variance = getDouble(privateParams, "initvar");
  [self getPriceFromWorld];
  [self getDividendFromWorld];
  global_mean = price + dividend;
  forecast = lforecast = global_mean;


// Iniitialize the forecasts, put them into Swarm Array

  //keep the 0'th forecast in a  "know nothing" condition
  [fcastList atOffset: 0 put: [self createNewForecast]];

  //create rest of forecasts with random conditions
  for ( i = 1; i < numfcasts; i++)
    {
      id aForecast =[self createNewForecast] ;
      [self setConditionsRandomly: aForecast];
      [fcastList atOffset: i put: aForecast];//pj: put aForecast into Swarm array "fcastlist"
     }

/* Compute average specificity */

  //pj: Here is the proper way to iterate over Swarm collections
  index=[ fcastList begin: [self getZone] ];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
    sumspecificity += [aForecast getSpecificity];
    //[aForecast  print];
    }
  avspecificity = (double) sumspecificity/(double)numfcasts;
  [index drop];
  return self;
}

/*"Creates a new forecast object (instance of BFCast), with all
  condition bits set to 00 here, meaning "don't care.  It also sets
  values for the other coefficients inside the BFCast.  This method is
  accessed at several points throughout the BFagent class when new
  forecasts are needed."*/
- (BFCast *) createNewForecast
{
  BFCast * aForecast;
  //needed to set values of a,b,and c
  double abase = privateParams->a_min + 0.5*(1.0-privateParams->subrange)*privateParams->a_range;
  double bbase = privateParams->b_min + 0.5*(1.0-privateParams->subrange)*privateParams->b_range;
  double cbase = privateParams->c_min + 0.5*(1.0-privateParams->subrange)*privateParams->c_range;
  double asubrange = privateParams->subrange*privateParams->a_range;
  double bsubrange = privateParams->subrange*privateParams->b_range;
  double csubrange = privateParams->subrange*privateParams->c_range;

  aForecast= [BFCast createBegin: [self getZone]]; 
  [aForecast setCondwords: privateParams->condwords];
  [aForecast setCondbits: privateParams->condbits];
  [aForecast setNNulls: privateParams->nnulls];
  [aForecast setBitcost: privateParams->bitcost];
  aForecast = [aForecast createEnd];
  [aForecast setForecast: 0.0];
  [aForecast setLforecast: global_mean];
  //note aForecast has the forecast conditions=0 by its own createEnd.
  //also inside its createEnd, lastactive =1, specificity=0, variance=99999;

  //pj: Controversy/confusion BFagent.m as originally distributed used
  //definitions for variance and strength that did not match the
  //bfagent.m file or the documentation. I'm following bfagent.m and
  //the docs, ignoring what was in BFagent.m

  [aForecast setVariance: privateParams->newfcastvar];  //same as bfagent's init  
  [aForecast setStrength: 0.0];
     
  /* Set the forecasting parameters for each fcast to random values in a
   * fraction "subrange" of their range, centered at the midpoint.  For
   * subrange=1 this is the whole range (min to max).  For subrange=0.5,
   * values lie between 1/4 and 3/4 of this range.  subrange=0 gives
   * homogeneous agents, with values at the middle of their min-max range. 
   */
  [aForecast setAval : abase + drand()*asubrange];
  [aForecast setBval : bbase + drand()*bsubrange];
  [aForecast setCval : cbase + drand()*csubrange];

  return aForecast;   
}

/*"Take a forecast and randomly change its bits.  This appears to be a piece of functionality that could move to the BFCast class itself. There were quite a few of them at one time."*/
-setConditionsRandomly: (BFCast *) fcastObject
{
  int bit;
  double *problist;
  int *bitlist;

  bitlist = [privateParams getBitListPtr];
 
  problist = [privateParams getProbListPtr];

  for(bit=0; bit< privateParams->condbits; bit++)
    {
      if (bitlist[bit] < 0)
	{
	  [fcastObject setConditionsbit: bit FromZeroTo: 3];//3=11 is a "filler"
	}
      else if (drand() < problist[bit])
	{  
	  [fcastObject setConditionsbit: bit FromZeroTo:  irand(2)+1];
	  //remember 1 means no, or binary 01, and 2 means Yes, or 10
	  [fcastObject incrSpecificity];//pj: I wish this were automatic!
	  [fcastObject updateSpecfactor];
	}
    }
  return self;
}


-prepareForTrading
  /*"
 * Set up a new active list for this agent's forecasts, and compute the
 * coefficients pdcoeff and offset in the equation
 *	forecast = pdcoeff*(trialprice+dividend) + offset
 *
 * The active list of all the fcasts matching the present conditions is saved
 * for later updates.
 "*/
{
  //register struct BF_fcast *fptr, *topfptr, **nextptr;
  //unsigned int real0, real1, real2, real3, real4 = 0 ;
  double weight, countsum, forecastvar=0.0;
  int mincount;
  int nactive;

  //pj: for getting values from world
  BitVector * myworld; 
 
  //for using indexes of forecast objects
  BFCast *  aForecast;
  id <Index> index;

#if  WEIGHTED == 1    
  static double a, b, c, sum, sumv;
#else
  //struct BF_fcast *bestfptr;
  BFCast *  bestForecast;
  double maxstrength;
#endif

 
  // First the genetic algorithm is run if due
  currentTime = getCurrentTime( );
     
  if (currentTime >= privateParams->firstgatime && drand() < privateParams->gaprob) 
    {
      [self performGA]; 
      [activeList removeAll];
    }	    

  //this saves a copy of the agent's last as lforecast.
  lforecast = forecast;
    
  myworld = [self collectWorldData: [self getZone] ];
  
  [self updateActiveList: myworld];

  [myworld drop]; //was created inside collectWorldData

 
#if WEIGHTED == 1
  // Construct weighted-average forecast
  // The individual forecasts are:  p + d = a(p+d) + b(d) + c
  // We often lock b at 0 by setting b_min = b_max = 0.

  //pj: note I started updating this code to match the rest, but then
  //pj: I realized it did not work as it was before, so I stopped
  //pj: messing with it. Don't expect the CPPFLAG WEIGHTED to do 
  //pj: anything good.

  a = 0.0;
  b = 0.0;
  c = 0.0;
  sumv = 0.0;
  sum = 0.0;
  nactive = 0;
  mincount = privateParams->mincount;

  index=[ activeList begin: [self getZone] ];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast setLastactive: t];
      if ( [aForecast incrCount] >= mincount )
	{
	  double sumstrength;
	  double strength;
	  strength=[aForecast getStrength];
	  ++nactive;

  	  a += strength*[aForecast getAval];
  	  b += strength*[aForecast getBval] ;
  	  c += strength*[aForecast getCval] ;
  	  sum += strength;
  	  sumv += [aForecast getVariance];
	}
    }
  [index drop];

  if (nactive) 
    {
      pdcoeff = a/sum;
      offset = (b/sum)*dividend + (c/sum);
      forecastvar = privateParams->individual? sumv/((double)nactive) :variance;
    }
#else
  //NOT WEIGHTED MODEL
  // Now go through the list and find best forecast
  maxstrength = -1e50;
  //bestfptf=NULL
  bestForecast = nil;
  nactive = 0;
  mincount = getInt(privateParams,"mincount");

  //pj: Kept as example of "homemade list" 
  //    for (fptr=activelist; fptr!=NULL; fptr=fptr->next) 
  //      {
  //        fptr->lastactive = currentTime;
  //        if (++fptr->count >= mincount) 
  //  	{
  //  	  ++nactive;
  //  	  if (fptr->strength > maxstrength) 
  //  	    {
  //  	      maxstrength = fptr->strength;
  //  	      bestfptr = fptr;
  //  	    }
  //  	}
  //      }
  
  index=[activeList begin: [self getZone]];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast setLastactive: currentTime];
      if([aForecast incrCount] >= mincount)
	{
	  double strength=[aForecast getStrength];
	  ++nactive;
	  if (strength > maxstrength)
	    {
	      maxstrength = strength;
	      bestForecast= aForecast;
	    }
	}
    }
  [index drop];


  //    if (nactive) 
  //      {
  //        pdcoeff = bestfptr->a;
  //        offset = bestfptr->b*dividend + bestfptr->c;
  //        forecastvar = (privateParams->individual? bestfptr->variance :variance);
  //      }

  //fprintf(stderr,"nactive = %d pjactive %d  activeList getCount is %d\n",nactive,pjactivecount, [activeList getCount]);
  if (nactive)  // meaning that at least some forecasts are active
    {
      pdcoeff = [bestForecast getAval];
      offset = [bestForecast getBval]*dividend + [bestForecast getCval];
      forecastvar = getInt(privateParams,"individual")? [bestForecast getVariance]: variance;
    }

#endif
  else  // meaning "nactive" zero, no forecasts are active 
    {
      // No forecasts are minimally adequate!!
      // Use weighted (by count) average of all rules
      countsum = 0.0;
      pdcoeff = 0.0;
      offset = 0.0;
      mincount = getInt(privateParams,"mincount");


      index=[ fcastList begin: [self getZone]];
      for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	{
	  if ([aForecast getCnt] >= mincount)
	    {  
	      countsum += weight = [aForecast getStrength];
	      offset += ([aForecast getBval]*dividend + [aForecast getCval])*weight;
	      pdcoeff += [aForecast getAval]*weight;
	    }
  
	  if (countsum > 0.0) 
	    {
	      offset /= countsum;
	      pdcoeff /= countsum;
	    }
	  else
	    {
	      offset = global_mean;
	    }
	  forecastvar = variance;
	}
      [index drop];
    }

  divisor = getDouble(privateParams,"lambda")*forecastvar;
    
  return self;
}


-(BitVector *) collectWorldData: aZone;
{ 
  int i,n,nworldbits;
  BitVector * world;
  int * bitlist;
  int * myRealWorld=NULL;

  
  world= [BitVector createBegin: aZone];
  [world setCondwords: params->condwords];
  [world setCondbits: params->condbits];
  world=[world createEnd];
    
  bitlist = [params getBitListPtr];
  nworldbits = [worldForAgent getNumWorldBits];

  myRealWorld = [aZone alloc: nworldbits*sizeof(int)];
  
  [worldForAgent getRealWorld: myRealWorld];

  for (i=0; i < params->condbits; i++) 
    {
      if ((n = bitlist[i]) >= 0)
	//myworld[WORD(i)] |= myRealWorld[n] << ((i%16)*2);
	[world setConditionsbit: i To: myRealWorld[n]]; 
    }

  [aZone free: myRealWorld];

   return world;
}


/*"This is the main inner loop over forecasters. Go through the list
  of active forecasts, compare how they did against the world.  Notice
  the switch that checks to see how big the bitvector (condwords) is
  before proceeding.  At one time, this gave a significant
  speedup. The original sfsm authors say 'Its ugly, but it
  works. Don't mess with it!'  (pj: I've messed with it, and don't
  notice much of a speed effect on modern computers with modern
  compilers :> My alternative implementation is commented out inside
  this method)"*/

-updateActiveList: (BitVector *) worldvalues
{
  id index;
  BFCast * aForecast;
 
  [self copyList: activeList To: oldActiveList]; 
  //pj: note, if activeList is empty, then oldActiveList will be empty.
  
  [activeList removeAll];


  //pj:copy forecasted values from objects in active to oldActiveList
  index=[ oldActiveList begin: [self getZone] ];
    for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
      {
      [aForecast setLforecast: [aForecast getForecast]];
      }
    [index drop];


  switch (privateParams->condwords) {
  case 1:

    index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      if ( [aForecast getConditionsWord: 0] & [worldvalues getConditionsWord: 0] ) 
	 {
 	   continue ;
	 }
      [activeList addLast: aForecast];
    }
    [index drop];

    break;
  
    case 2:
      //pj: here is how it used to be
//      real1 = worldvalues[1];

//      for (fptr = fcast; fptr < topfptr; fptr++) 
//        {
//  	if (fptr->conditions[0] & real0) continue;
//  	if (fptr->conditions[1] & real1) continue;
//  	*nextptr = fptr;
//  	nextptr = &fptr->next;
//        }

   index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & [worldvalues getConditionsWord: 0] ) continue ;
       if ( [aForecast getConditionsWord: 1] & [worldvalues getConditionsWord: 1] ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];

      break;
   
 case 3:
    
  index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & [worldvalues getConditionsWord: 0] ) continue ;
       if ( [aForecast getConditionsWord: 1] & [worldvalues getConditionsWord: 1] ) continue ;
       if ( [aForecast getConditionsWord: 2] & [worldvalues getConditionsWord: 2] ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];
     break;
    case 4:
 
    index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      if ( [aForecast getConditionsWord: 0] & [worldvalues getConditionsWord: 0]) continue ;
      if ( [aForecast getConditionsWord: 1] &  [worldvalues getConditionsWord: 1] ) continue ;
      if ( [aForecast getConditionsWord: 2] &  [worldvalues getConditionsWord: 2] ) continue ;
      if ( [aForecast getConditionsWord: 3] &  [worldvalues getConditionsWord: 3] ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];

      break;
    case 5:
 
    index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
       if ( [aForecast getConditionsWord: 0] & [worldvalues getConditionsWord: 0] ) continue ;
       if ( [aForecast getConditionsWord: 1] & [worldvalues getConditionsWord: 1] ) continue ;
       if ( [aForecast getConditionsWord: 2] & [worldvalues getConditionsWord: 2] ) continue ;
       if ( [aForecast getConditionsWord: 3] & [worldvalues getConditionsWord: 3] ) continue ;
       if ( [aForecast getConditionsWord: 4] & [worldvalues getConditionsWord: 4] ) continue ;
       [activeList addLast: aForecast];
    }
    [index drop];
      break;
        }

#if MAXCONDBITS > 5*16
#error Too many condition bits (MAXCONDBITS)
#endif

  
   //pj??? There ought to be a "default" action here for other cases.


  /*This is an alternative implementation of the same as preceeding.  Its so much cuter.
I write it before I understood the fact that the World gives back 10 for yes and agent has 01 for yes. 
  
    index=[ fcastList begin: [self getZone]];
    for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      unsigned int flag=0;
      unsigned int trit;
      unsigned int predictedvalue=999;
     
      trit=-1;
      while ( flag == 0 && ++trit < privateParams-> condbits )
	    {
	      if ( (predictedvalue=[aForecast getConditionsbit: trit]) != 0 )
		{
		  //if ( predictedvalue == ((worldvalues[WORD(trit)] >> ((trit%16)*2))&3) )
		  if (  predictedvalue == [worldvalues getConditionsbit: trit] )
		    {
		      flag=1;
		    }
		}
	        		
	   //       fprintf(stderr,"trit:%d flag: %d  predictionl=%d,  world=%d\n", 
	      //  			trit, flag, predictedvalue,
	      //  			extractvalue(worldvalues,trit) );  
	         }
     
	    if ( flag!=1 )  [activeList addLast: aForecast];
    
        }
    [index drop];
  */

  return self;
}

/*"Currently does nothing, used only if their are ANNagents"*/
-getInputValues     
{
  return self;
}

/*"Currently does nothing, used only if their are ANNagents"*/
-feedForward        
{
  return self;
}


-(double)getDemandAndSlope: (double *)slope forPrice: (double)trialprice
  /*" Returns the agent's requested bid (if >0) or offer (if <0) using
* best (or mean) linear forecast chosen by -prepareForTrading The
* forecast is given by 

   forecast = pdcoeff*(trialprice+dividend) + offset 

* where pdcoeff and offset are set by -prepareForTrading.

A risk aversion computation gives a target holding, and its
derivative ("slope") with respect to price.  The slope is calculated
as the linear approximated response of a change in price on the
traders' demand at time t, based on the change in the forecast
according to the currently active linear rule. "*/

{
 
  forecast = (trialprice + dividend)*pdcoeff + offset;


  if (forecast >= 0.0) 
    {
      demand = -((trialprice*intratep1 - forecast)/divisor + position);
      *slope = (pdcoeff-intratep1)/divisor;
    }
  else 
    {
      forecast = 0.0;
      demand = - (trialprice*intratep1/divisor + position);
      *slope = -intratep1/divisor;
    }

  // Clip bid or offer at "maxbid".  This is done to avoid problems when
  // the variance of the forecast becomes very small, thought it's not clear
  // that this is the best solution.
  if (demand > privateParams->maxbid) 
    { 
      demand = privateParams->maxbid;
      *slope = 0.0;
    }
  else if (demand < -privateParams->maxbid) 
    {
      demand = -privateParams->maxbid;
      *slope = 0.0;
    }
    
  [super constrainDemand:slope:trialprice];
  return demand;
}


/*"Return agent's forecast"*/
-(double)getRealForecast
{
  return forecast;
}


/*" Now update the variance and strength of all the forecasts that
  were active in the previous period, since now we know how they
  performed. This method causes an update of price/dividend
  information from the world, then it measures how far off each
  forecast was and puts the square of that "deviance" measure into the
  forecast with the forecast's setVariance: method. Each forecast in
  the active list is told to update its forecast.  It also updates the
  instance variable variance, which is calculated here as an
  exponentially weignted moving average of that forecast's
  squared-error (variance).  Inside the code of updatePerformance,
  there is a description of the strength formula that is used, and how
  the formula now matches the formula used in the original sfsm,
  rather than ASM-2.0. "*/

-updatePerformance
{
  //pj: register struct BF_fcast *fptr;
  BFCast *  aForecast;
  id <Index> index = nil;
  double deviation, ftarget, tauv, a, b, c, av, bv, maxdev;

  // Precompute things for speed
  tauv = privateParams->tauv;
  a = 1.0/tauv;
  b = 1.0-a;
  // special rates for variance
  // We often want this to be different from tauv
  // PARAM:  100. should be a parameter  BL
  av = 1.0/(double)100.0;
  bv = 1.0-av;

    /* fixed variance if tauv at max */
  if (tauv == 100000) 
    {
      a = 0.0;
      b = 1.0;
      av = 0.0;
      bv = 1.0;
    }
  maxdev = privateParams->maxdev;

// Update global mean (p+d) and our variance
  [self getPriceFromWorld];
  ftarget = price + dividend;

// Update global mean (p+d) and our variance
    
  realDeviation = deviation = ftarget - lforecast;
  if (fabs(deviation) > maxdev) deviation = maxdev;
  global_mean = b*global_mean + a*ftarget;
  // Use default for initial variances - for stability at startup
  currentTime = getCurrentTime( );
  if (currentTime < 1)
    variance = privateParams->initvar;
  else
    variance = bv*variance + av*deviation*deviation;

 //I cant find anywhere in ASM-2.0's BFagent.m an update of the forecast's
 //forecast. but it is clearly needed if you look at bfagent from the
 //objc version. Including the next loop
 //fixes the strange time series properties too
 
  //printf("active list has %d \n",[activeList getCount] );

  index = [ activeList begin: [self getZone]];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast updateForecastPrice: price Dividend: dividend];
    }
  [index drop];
   
  //pj: Here is the way it was
// Update all the forecasters that were activated.
//    if (currentTime > 0)
//      for (fptr=lactivelist; fptr!=NULL; fptr=fptr->lnext) 
//        {
//          deviation = (ftarget - fptr->lforecast)*(ftarget - fptr->lforecast);

//  // 	Benchmark test line - replace true deviation with random one
//  //      PARAM: Might be coded as a parameter sometime 
//  //      deviation = drand(); 

//  //      Only necessary for absolute deviations
//  //      if (deviation < 0.0) deviation = -deviation;

//  	if (deviation > maxdev) deviation = maxdev;
//    	if (fptr->count > tauv)
//  	  fptr->variance = b*fptr->variance + a*deviation;
//  	else 
//  	  {
//  	    c = 1.0/(1.+fptr->count);
//  	    fptr->variance = (1.0 - c)*fptr->variance +
//  						c*deviation;
//  	  }
//          fptr->strength = fptr->specfactor/fptr->variance;
//        }

  if (currentTime > 0)
    {
      index = [ oldActiveList begin: [self getZone]];
      for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	{
	  double  lastForecast=[aForecast getLforecast];
	  deviation = (ftarget - lastForecast)*(ftarget - lastForecast);

	  if (deviation > maxdev) deviation = maxdev;
	  if ([aForecast getCnt] > tauv)
	    [aForecast setVariance : b*[aForecast getVariance] + a*deviation];
	  else 
	    {
	      c = 1.0/(double) (1.0 +[aForecast getCnt]);  //??bfagent had no 1+ here ??
	      [aForecast setVariance: (1.0 - c)*[aForecast getVariance] +
			 c*deviation];
	    }
	  
	  [aForecast setStrength: privateParams->maxdev 
		     - [aForecast getVariance]
		     + [aForecast getSpecfactor]];
	  // ****************************************/
	  // pj: The preceeding is based on sfsm's bfagent.m
	  // 
	  // original bfagent has this: rptr->strength = p->maxdev -
	  // rptr->variance + rptr->specfactor; 

	  // BFagent had this: fptr->strength =
	  // fptr->specfactor/fptr->variance; I've spoken to Blake
	  // LeBaron and we both like the old way and don't know why it
	  // was changed. 

	  // I hasten to say that maxdev is the benchmark for
	  // variance, and I wonder if maxdev would not be better
	  // renamed maxdev-squared or maxvar.
	  //******************************************/
	}

      [index drop];
    }
 
  return self;
}

/*"Returns the absolute value of realDeviation"*/
-(double)getDeviation
{
  return fabs(realDeviation);
}

/*"Currently, does nothing, used only if their are ANNagents"*/
-updateWeights        
{
  return self;
}


/*"Returns the "condbits" variable from parameters: the number of
  condition bits that are monitored in the world, or 0 if
  condition bits aren't used.
  "*/
-(int)nbits
{
  return privateParams->condbits;
}

/*"Returns the number of forecasts that are used. In the original
  design, this was a constant set in the parameters, although revision
  of the code for ASM-2.2 conceivably should allow agents to alter the
  number of forecasts they maintain."*/
-(int)nrules
{
  return privateParams->numfcasts;
}

/*"Return the last time the Genetic Algorithm was run.
//	Agents that don't use a genetic algorithm return MININT.  This
//	may be used to see if the bit distribution might have changed,
//	since a change can only occur through a genetic algorithm."*/
-(int)lastgatime
{
  return lastgatime;
}


/*"Currently, this method is not called anywhere in ASM-2.2. It might
  serve some purpose, past or present, I don't know (pj:
  2001-11-26)"*/
//   Original docs from ASM-2.0
//	Places in (*countptr)[0] -- (*countptr)[3] the addresses of 4
//	arrays, (*countptr)[0][i] -- (*countptr)[3][i], which are filled
//	with the number of bits that are 00, 01, 10, or 11 respectively,
//	for each condition bit i= 0, 1, nbits-1, summed over all rules or
//	forecasters.  Returns nbits, the number of condition bits.  If
//	cum is YES, adds the new counts to whatever is in the (*coutptr)
//	arrays already.  Agents that don't use condition bits return -1.
//	The 4-element array (*countptr)[4] must already exist, but the
//	arrays to which its element point are supplied dynamically.  This
//	method must be provided by each subclass that has condition bits.
-(int)bitDistribution: (int *(*)[4])countptr cumulative: (BOOL)cum
{
  BFCast * aForecast;
  unsigned int *agntcond;
  int i;
  int condbits;
  id index;
 
  static int *count[4];	// Dynamically allocated 2-d array
  static int countsize = -1;	// Current size/4 of count[]
  static int prevsize = -1;

  condbits = getInt (privateParams, "condbits");

  if (cum && condbits != prevsize)
    printf("There is an error with an agent's condbits.");
  prevsize = condbits;

// For efficiency the static array can grow but never shrink
  if (condbits > countsize) 
    {
      if (countsize > 0) free(count[0]);
      count[0] = calloc(4*condbits,sizeof(int));
      if(!count[0])
	printf("There was an error allocating space for count[0].");
      count[1] = count[0] + condbits;
      count[2] = count[1] + condbits;
      count[3] = count[2] + condbits;
      countsize = condbits;
    }
  
  (*countptr)[0] = count[0];
  (*countptr)[1] = count[1];
  (*countptr)[2] = count[2];
  (*countptr)[3] = count[3];

  if (!cum)
    for(i=0;i<condbits;i++)
      count[0][i] = count[1][i] = count[2][i] = count[3][i] = 0;

 index=[ fcastList begin: [self getZone] ];  
 for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
   {
     agntcond = [aForecast getConditions];
      for (i = 0; i < condbits; i++)
	{
	    count[ (int)[aForecast getConditionsbit: i]][i]++;
	}
   }
 [index drop];
 //pj: it was like this:
//    for (fptr = fcast; fptr < topfptr; fptr++) 
//      {
//        agntcond = fptr->conditions;
//        for (i = 0; i < condbits; i++)
//  	count[(int)((agntcond[WORD(i)]>>SHIFT[i])&3)][i]++;
//      }

  return condbits;
}


//pj: this method was never called anywhere

/*"Currently, this method is not called anywhere in ASM-2.2. It might
  serve some purpose, past or present, I don't know (pj:
  2001-11-26)"*/
-(int)fMoments: (double *)moment cumulative: (BOOL)cum
{
  BFCast *aForecast ;
  int i;
  int condbits;

  id index;
  
  condbits = getInt (privateParams, "condbits");
  
  if (!cum)
	for(i=0;i<6;i++)
	  moment[i] = 0;
  
 index=[ fcastList begin: [self getZone] ];  
 for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
   {
     moment[0] +=  [aForecast getAval];
      moment[1] += [aForecast getAval]*[aForecast getAval];
      moment[2] += [aForecast getBval];
      moment[3] += [aForecast getBval]*[aForecast getBval];
      moment[4] += [aForecast getCval];
      moment[5] += [aForecast getAval]*[aForecast getAval];
   }
 [index drop];  
  return privateParams->numfcasts;
}

//pj: this method is not called anywhere

/*"Currently, this method is not called anywhere in ASM-2.2. It might serve some purpose, past or present, I don't know (pj: 2001-11-26)"*/
// ASM-2.0 documentation:
//	If the agent uses condition bits, returns a description of the
//	specified bit.  Invalid bit numbers return an explanatory message.
//	Agents that don't use condition bits return NULL.
//
-(const char *)descriptionOfBit: (int)bit
{
  if (bit < 0 || bit > getInt(privateParams,"condbits"))
    return "(Invalid condition bit)";
  else
    return [World descriptionOfBit:privateParams->bitlist[bit]];
}


/*" Genetic algorithm. It relies on the following separate methods.  (pj: 2001-11-25. I still see some room for improvement here, but the emphasis is to eliminate all global variables and explicitly pass return values instead.)
//
//  1. MakePool makes a list of the weakest forecasts:
//  rejectList. That is the "npool" weakest rules.
//
//  2. "nnew" new rules are created. They are put into a Swarm list
//  called newList. Their bit settings are taken from either crossover
//  (using tournament selection to get parents), or mutation.
//  "Tournament selection" means picking two candidates purely at
//  random and then choosing the one with the higher strength.  See
//  the Crossover and Mutate methods for more details about how they
//  work.
//
//  3. The nnew new rules replace weakest old ones found in step
//  1. This is done by the method "TransferFcastsFrom:To:" It pays no
//  attention to strength, but looks at similarity of the bitstrings
//  -- rather like tournament selection, we pick two candidates from
//  the rejectList at random and choose the one with the MORE similar
//  bitstring to be replaced.  This maintains more diversity.
//
//  4. Generalize looks for rules that haven't been triggered for
//  "longtime" and generalizes them by changing a randomly chosen
//  fraction "genfrac" of 0/1 bits to "don't care".  It does this
//  independently of strength to all rules in the population.
//
//  There are several private methods that take care of this
//  work. They don't show up in the public interface, but here they
//  are:

-(BFCast *)  CopyRule:(BFCast *) to From: (BFCast *) from

-(void) MakePool: rejects From: (id <Array>) list

-(BOOL) Mutate: (BFCast *) new Status: (BOOL) changed

-(BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2

- (void) TransferFcastsFrom: newlist To:  forecastList Replace: rejects 

- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects

-(void) Generalize: (id) list AvgStrength: (double) avgstrength

// Parameter list:

_{npool	-- size of pool of weakest rules for possible relacement;
		   specified as a fraction of numfcasts by "poolfrac"}

_{nnew	-- number of new rules produced
		   specified as a fraction of numfcasts by "newfrac"}

_{ pcrossover -- probability of running Crossover.}

_{plinear    -- linear combination "crossover" prob.}

//  _{ prandom    -- random from each parent crossover prob.}

//  _{ pmutation  -- per bit mutation prob.}

//  _{ plong      -- long jump prob.}

//   _{pshort     -- short (neighborhood) jump prob.}

//  _{nhood      -- size of neighborhood.}

//   _{longtime	-- generalize if rule unused for this length of time}

//  _{ genfrac	-- fraction of 0/1 bits to make don't-care when generalising}
"*/
- performGA
{
  // register struct BF_fcast *fptr;
  //  struct BF_fcast *nr;
  register int f;
  int  new;
  BFCast * parent1, * parent2;
 
  double ava,avb,avc,sumc;
  double madv=0.0; 
  double meanv = 0.0;
  double temp;  //for holding values needed shortly
  //pj: previously declared as globals
  int * bitlist;
 //pj: could be only in perforGA, but then would be recreated every time.
  id newList = [List create: [self getZone]]; //to collect the new forecasts; 
  id rejectList = [Array create: [self getZone] setCount: getInt(privateParams,"npoolmax")];
 

  static double avstrength;


  ++gacount;
  currentTime = getCurrentTime();

  privateParams->lastgatime= params->lastgatime = lastgatime = currentTime;

  bitlist = privateParams->bitlist;

  // Find the npool weakest rules, for later use in TrnasferFcasts
  //MakePool(fcastList);
  [self  MakePool: rejectList From: fcastList];


  // Compute average strength (for assignment to new rules)
  avstrength = ava = avb = avc = sumc = 0.0;
  minstrength = 1.0e20;

  for (f=0; f < privateParams->numfcasts; f++) 
    {
      BFCast * aForecast = [fcastList atOffset: f];
      double varvalue = 0;

      varvalue= [ aForecast getVariance];
      meanv += varvalue;
      if ( [aForecast  getCnt] > 0)
	{
	  if ( varvalue !=0  )
	    {
	      avstrength += [ [ fcastList atOffset: f] getStrength];
	      sumc += 1.0/ varvalue ;
	      ava +=  [ aForecast getAval ] / varvalue ;
	      avb +=  [ aForecast getBval ] / varvalue;
	      avc +=  [ aForecast getCval ] / varvalue ;
	    }
	  if( (temp = [ aForecast getStrength ]) < minstrength)
	    minstrength = temp;
	}
    }

  meanv = meanv/ privateParams->numfcasts;

  for (f=0; f < privateParams->numfcasts; f++) 
    {
      madv += fabs( [[fcastList atOffset:f] getVariance] - meanv); 
    }

  madv = madv/privateParams->numfcasts;

  //    ava /= sumc;
  //    avb /= sumc;
  //    avc /= sumc;
  /*
   * Set rule 0 (always all don't care) to inverse variance weight 
   * of the forecast parameters.  A somewhat Bayesian way for selecting 
   * the params for the unconditional forecast.  Remember, rule 0 is imune to
   * all mutations and crossovers.  It is the default rule.
   */
  [[fcastList atOffset: 0] setAval: ava/ sumc ];
  [[fcastList atOffset: 0] setBval: avb/ sumc ];
  [[fcastList atOffset: 0] setCval: avc/ sumc ];
  
  avstrength /= privateParams->numfcasts;
    
// Loop to construct nnew new rules
  for (new = 0; new < privateParams->nnew; new++) 
    {
      BOOL changed;
 
      changed = NO;
      // Loop used if we force diversity
      do 
	{
	  double varvalue, altvarvalue = 999999999;
	  BFCast * aNewForecast=nil;

	  aNewForecast = [ self createNewForecast ];
	  [aNewForecast updateSpecfactor];
	  [aNewForecast setStrength: avstrength];
   
	  //BFagent.m had equivalent of:  [aNewForecast setVariance: [aNewForecast getSpecfactor]/[aNewForecast getStrength]];
          [aNewForecast setLastactive: currentTime];
            //following bfagent.m:
	  varvalue =  privateParams->maxdev-avstrength+[aNewForecast getSpecfactor];
	  if (varvalue < 0 ) raiseEvent(WarningMessage, "varvalue  less than zero");
	  [aNewForecast setVariance: varvalue];
	  altvarvalue = [[fcastList atOffset: 0] getVariance]- madv;
	  if ( varvalue < altvarvalue )
	  {
	    [aNewForecast setVariance: altvarvalue];
	    [aNewForecast setStrength: privateParams->maxdev - altvarvalue + [aNewForecast getSpecfactor]];
	   }
	  [aNewForecast setLastactive: currentTime];
	  
	  [newList addLast: aNewForecast]; //?? were these not initialized in original?//
          
	  //[aNewForecast print];

	  // Pick first parent using touranment selection
	  //pj: ??should this operate on all or only active forecasts???
	  do
	    parent1 = [ self Tournament: fcastList ] ;
	  while (parent1 == nil);

	  // Perhaps pick second parent and do crossover; otherwise just copy
	  if (drand() < privateParams->pcrossover) 
	    {
	      do
		parent2 = [self  Tournament: fcastList];
	      while (parent2 == parent1 || parent2 == nil) ;

	      //  Crossover(aNewForecast,parent1, parent2);
	      [self Crossover:  aNewForecast Parent1:  parent1 Parent2:  parent2];
	      if (aNewForecast==nil) {raiseEvent(WarningMessage,"got nil back from crossover");}
	      changed = YES;
	    }
	  else
	    {
	      //pj: CopyRule(aNewForecast,parent1);
	      [self CopyRule: aNewForecast From: parent1];
	      if(!aNewForecast)raiseEvent(WarningMessage,"got nil back from CopyRule");
	
	      changed = [self Mutate: aNewForecast Status: changed];
	    }
	  //It used to only do this if changed, but why not all??
	 
	    
	  // [aNewForecast print];
	} while (0);
      /* Replace while(0) with while(!changed) to force diversity */
    }

  // Replace nnew of the weakest old rules by the new ones
  //pj: TransferFcasts ( newList, fcastList , rejectList);

  [self  TransferFcastsFrom: newList To: fcastList Replace: rejectList];

// Generalize any rules that haven't been used for a long time
  [self Generalize: fcastList AvgStrength: avstrength ];

  // Compute average specificity
  {
    int specificity = 0;
    //note here a "raw" for loop around the fcastList. I could create an index
    //and do the swarm thing, but I leave this here to keep myself humble.

    for (f = 0; f < privateParams->numfcasts; f++) 
      {
	parent1 = [fcastList atOffset:0];
	specificity += [parent1 getSpecificity];
      }
    avspecificity = ((double) specificity)/(double)privateParams->numfcasts;

  }

  [newList deleteAll]; 
  [newList drop];

  [rejectList drop]; 

  return self;
}



/*------------------------------------------------------*/
/*	CopyRule					*/
/*------------------------------------------------------*/
-(BFCast *)  CopyRule:(BFCast *) to From: (BFCast *) from
{
  [to setForecast: [from getForecast]];
  [to setLforecast: [from getLforecast]];
  [to setVariance: [from getVariance]];
  [to setStrength: [from getStrength]];
  [to setAval: [from getAval]];
  [to setBval: [from getBval]];
  [to setCval: [from getCval]];
  [to setSpecfactor: [from getSpecfactor]];
  [to setLastactive: [from getLastactive]];
  [to setSpecificity: [from getSpecificity]];
  [to setConditions: [from getConditions]];
  [to setCnt: [from getCnt]];
  if ( [from getCnt] ==0)
    [to setStrength: minstrength];
  return to;
}


/*------------------------------------------------------*/
/*	MakePool					*/
/*------------------------------------------------------*/
-(void) MakePool: rejects From: (id <Array>) list
{

  register int top;
  int i,j = 0 ;
  BFCast * aForecast;
  BFCast * aReject;
  
  top = -1;
  //pj: why not just start at 1 so we never worry about putting forecast 0 into the mix?
  for ( i=1; i < getInt(privateParams,"npool" ); i++ )
    {
      aForecast=[list atOffset: i];
      for ( j=top;  j >= 0 && (aReject=[rejects atOffset:j])&& ([aForecast getStrength] < [aReject  getStrength] ); j--)
	{
	  [rejects atOffset: j+1 put: aReject ];
	}  //note j decrements at the end of this loop
      [rejects atOffset: j+1 put: aForecast];
      top++;
    }
	  
  for ( ; i < getInt(privateParams,"numfcasts"); i++)
    {
      aForecast=[list atOffset: i];
      if ( [aForecast  getStrength]  < [[ rejects atOffset: top] getStrength ] ) 
	{
	  for ( j = top-1; j >= 0 && (aReject=[rejects atOffset:j]) && [aForecast getStrength] < [aReject  getStrength]; j--)
	    {
	      [rejects atOffset: j+1 put: aReject];
	    }
	}
      [rejects atOffset: j+1 put: aForecast];
    }
  //pj:note: we are not checking to see if forecast 0 is in here
}




/*------------------------------------------------------*/
/*	Tournament					*/
/*------------------------------------------------------*/
- (BFCast *) Tournament: (id <Array>) list
{
  
  int  numfcasts=[list getCount];
  BFCast * candidate1 = [list atOffset: irand(numfcasts)];
  BFCast *  candidate2;
    
  do
    candidate2 = [list atOffset: irand(numfcasts)];
  while (candidate2 == candidate1);

  if ([candidate1 getStrength] > [candidate2 getStrength])
    return candidate1;
  else
    return candidate2;
}




/*------------------------------------------------------*/
/*	Mutate						*/
/*------------------------------------------------------*/
-(BOOL) Mutate: (BFCast *) new Status: (BOOL) changed
  /*
     * For the condition bits, Mutate() looks at each bit with
     * probability pmutation.  If chosen, a bit is changed as follows:
     *    0  ->  * with probability 2/3, 1 with probability 1/3
     *    1  ->  * with probability 2/3, 0 with probability 1/3
     *    *  ->  0 with probability 1/3, 1 with probability 1/3,
     *           unchanged with probability 1/3
     * This maintains specificity on average.
     *VERY CONFUSING, because the values are actually 0,1, and 2
     CONVERTED LIKE SO

     0      1    1/3          2       1/3
     1      0    2/3          2       1/3
     2      0    2/3          1       1/3

     *
     * For the forecasting parameters, Mutate() may do one of two things,
     * independently for each parameter.
     * 1. "Long jump": the parameter is chosen randomly from its min-max
     *    range.
     * 2. "Short jump": the parameter is chosen randomly from a uniform
     *    distribution from oldvalue-nhood*range to oldvalue+nhood*range,
     *    where range = max-min.  Values outside the min-max range are
     *    mapped to the endpoint.
     * Method 1 is used with probability plong, method 2 is used with
     * probability pshort, and the parameter is left unchanged with
     * probability 1-plong-pshort.
     *
     * Returns YES if it actually changed anything, otherwise NO.
     */
{
  register int bit;
  double choice, temp;
  BOOL bitchanged = NO;
  int * bitlist= NULL;
  
  bitlist= [privateParams getBitListPtr];
  //pj: dont know why BFagents introduced bitchanged.??
  bitchanged = changed;
  if (privateParams->pmutation > 0) 
    {
      for (bit = 0; bit < privateParams->condbits; bit++) 
	{
	  if (bitlist[bit] < 0) continue;
	  if (drand() < privateParams->pmutation) 
	    {
	      //cond = cond0 + WORD(bit);
	      //if (*cond & MASK[bit])
	      if ([new getConditionsbit: bit] > 0 ) 
		{
		  if (irand(3) > 0) 
		    {
		      // *cond &= NMASK[bit];
		      //nr->specificity--;
		      [new maskConditionsbit: bit];
		      [new decrSpecificity];
		    }
		  else
		    //   *cond ^= MASK[bit];
		    [new switchConditionsbit: bit];
		    
		  bitchanged = changed = YES;
		}
	      else if (irand(3) > 0) 
		{
		 
		  //  *cond |= (irand(2)+1) << SHIFT[bit];
		  //  nr->specificity++;
		  [new setConditionsbit: bit FromZeroTo: (irand(2)+1)];
		  [new incrSpecificity];
		  bitchanged = changed = YES;
		}
	    }
	}
    }

  /* mutate p+d coefficient */
  choice = drand();
  if (choice < privateParams->plong) 
    {
      /* long jump = uniform distribution between min and max */
      [new setAval:   privateParams->a_min + privateParams->a_range*drand()] ;
      changed = YES;
    }
  else if (choice < privateParams->plong + privateParams->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = [new getAval] + privateParams->a_range*privateParams->nhood*urand();
      [new setAval: (temp > privateParams->a_max? privateParams->a_max:
		     (temp < privateParams->a_min? privateParams->a_min: temp))];
      changed = YES;
    }
  /* else leave alone */

  /* mutate dividend coefficient */
  choice = drand();
  if (choice < privateParams->plong) 
    {
      /* long jump = uniform distribution between min and max */
      [new setBval:  privateParams->b_min + privateParams->b_range*drand() ];
      changed = YES;
    }
  else if (choice < privateParams->plong + privateParams->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = [new getBval] + privateParams->b_range*privateParams->nhood*urand();
      [new setBval: (temp > privateParams->b_max? privateParams->b_max:
		     (temp < privateParams->b_min? privateParams->b_min: temp))];
      changed = YES;
    }
  /* else leave alone */

  /* mutate constant term */
  choice = drand();
  if (choice < privateParams->plong) 
    {
      /* long jump = uniform distribution between min and max */
      [new setCval:  privateParams->c_min + privateParams->c_range*drand()];
      changed = YES;
    }
  else if (choice < privateParams->plong + privateParams->pshort) 
    {
      /* short jump  = uniform within fraction nhood of range */
      temp = [new getCval] + privateParams->c_range*privateParams->nhood*urand();
      [new setCval: (temp > privateParams->c_max? privateParams->c_max:
		     (temp < privateParams->c_min? privateParams->c_min: temp))];
      changed = YES;
    }
  /* else leave alone */

  [new setCnt: 0];

  if (changed) 
    { 
      [new updateSpecfactor];
    }
  return(changed);
}



/*------------------------------------------------------*/
/*	Crossover					*/
/*------------------------------------------------------*/
-(BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2
  /*
     * On the condition bits, Crossover() uses uniform crossover -- each
     * bit is chosen randomly from one parent or the other.
     * For the real-valued forecasting parameters, Crossover() does
     * one of three things:
     * 1. Choose a linear combination of the parents' parameters,
     *    weighted by strength.
     * 2. Choose each parameter randomly from each parent.
     * 3. Choose one of the parents' parameters (all from one or all
     *    from the other).
     * Method 1 is chosen with probability plinear, method 2 with
     * probability prandom, method 3 with probability 1-plinear-prandom.
     */
{
  /* Uniform crossover of condition bits */
  register int bit;
  // unsigned int *cond1, *cond2, *newcond;
  int word;
  double weight1, weight2, choice;
      
  [newForecast setSpecificity: 0];

  for (word = 0; word <privateParams->condwords; word++)
    [newForecast setConditionsWord: word To: 0];

  for (bit = 0; bit < privateParams->condbits; bit++)
    {
     if ( irand(2) == 0)
	{
	  int value=[parent1 getConditionsbit: bit];
	  [newForecast setConditionsbit: bit FromZeroTo: value];
	  if (value > 0) [newForecast incrSpecificity]; 
	}
      else
	{
	  int value= [parent2 getConditionsbit: bit];
	  [newForecast setConditionsbit: bit FromZeroTo: value ];
	  if (value > 0) [newForecast incrSpecificity]; 
	}
    }
  //pj:???wont those changes automatically show up in newForecast??//
    
  // checked with Blake: this was a remnant, only need first if, as above
  //   if(irand(1)==0) 
  //      {
  //        for (word = 0; word <condwords; word++)
  //  	newcond[word] = 0;
  //        for (bit = 0; bit < condbits; bit++)
  //  	newcond[WORD(bit)] |= (irand(2)?cond1:cond2)[WORD(bit)]&MASK[bit];
  //      }

  //    else 
  //      {
  //        bitparent = irand(2);
  //        for (word = 0; word <condwords; word++)
  //  	newcond[word] = 0;
  //        for (bit = 0; bit < condbits; bit++)
  //  	newcond[WORD(bit)] |= (bitparent?cond1:cond2)[WORD(bit)]&MASK[bit];
  //      }

  /* Select one crossover method for the forecasting parameters */
  choice = drand();
  if (choice < privateParams->plinear) 
    {
      /* Crossover method 1 -- linear combination */
      weight1 = [parent1 getStrength] / ([parent1 getStrength] +
					 [parent2 getStrength]);
      weight2 = 1.0-weight1;
      [ newForecast setAval:  weight1*[parent1 getAval] + weight2*[parent2 getAval] ]; 
      [ newForecast setBval:  weight1*[parent1 getBval] + weight2*[parent2 getBval] ];
      [ newForecast setCval:  weight1*[parent1 getCval] + weight2*[parent2 getCval]] ;
    }
  else if (choice < privateParams->plinear + privateParams->prandom) 
    {
      /* Crossover method 2 -- randomly from each parent */
      if(irand(2))
	[newForecast setAval: [parent1 getAval]] ; else [newForecast setAval: [parent2 getAval]];
      if(irand(2))
	[newForecast setBval: [parent1 getBval]] ; else [newForecast setBval: [parent2 getBval]];   
      if(irand(2))
	[newForecast setCval: [parent1 getCval]] ; else [newForecast setCval: [parent2 getCval]];
    }
  else 
    {
      /* Crossover method 3 -- all from one parent */
      if (irand(2))
	{
	  [newForecast setAval: [parent1 getAval]] ;  
	  [newForecast setBval: [parent1 getBval]] ;    
	  [newForecast setCval: [parent1 getCval]] ;
	}
      else
	{
	  [newForecast setAval: [parent2 getAval]] ;  
	  [newForecast setBval: [parent2 getBval]] ;    
	  [newForecast setCval: [parent2 getCval]] ;
	}
    }

  {  //This is just error checking!
    BitVector * newcond;
    int specificity=0;
    [newForecast setCnt: 0 ];	// call it new in any case
    
  [newForecast updateSpecfactor];

  [newForecast setStrength :  0.5*([parent1 getStrength] + [parent2 getStrength])];


 //pj: next steps are purely diagnostic!
   newcond = [newForecast getConditionsObject];

    for (bit = 0; bit < privateParams->condbits; bit++)
 
    //if ((newcond[WORD(bit)]& ( 3 << ((bit%16)*2))) != 0)
    if ( [newcond getConditionsbit: bit] != 0 )
	{
	  specificity++;
	}
    //printf("CrossoverDiagnostic: newforecast Specificity %d should equal %d \n", [newForecast getSpecificity],specificity);
  }
   return newForecast;
}


/*------------------------------------------------------*/
/*	TransferFcasts					*/
/*------------------------------------------------------*/
- (void) TransferFcastsFrom: newlist To:  forecastList Replace: rejects 
{
  //register struct BF_fcast *fptr, *nr;
  //register int new;
  //      int nnew;
  id ind;
  BFCast * aForecast;
  BFCast * toDieForecast;

      //nnew = pp->nnew;
 
  ind = [newlist begin: [self getZone]];
  for ( aForecast = [ind next]; [ind getLoc]==Member; aForecast=[ind next] )
    {
      //toDieForecast = GetMort(aForecast, rejects);
      toDieForecast = [self GetMort: aForecast Rejects: rejects];
      toDieForecast = [self CopyRule: toDieForecast From: aForecast];
    }
  [ind drop];
	
  ///      for (new = 0; new < nnew; new++) 
  //  	{
  //  	  nr = newfcast + new;
  //  	  fptr = GetMort(nr);
      
  //  	  // Copy the whole structure and conditions
  //  	  CopyRule(fptr, nr);
  //	}
}



/*------------------------------------------------------*/
/*	GetMort						*/
/*------------------------------------------------------*/
- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects
  /* GetMort() selects one of the npool weak old fcasts to replace
     * with a newly generated rule.  It pays no attention to strength,
     * but looks at similarity of the condition bits -- like tournament
     * selection, we pick two candidates at random and choose the one
     * with the MORE similar bitstring to be replaced.  This maintains
     * more diversity.
     */
{
  //register int bit, temp1, temp2, different1, different2;
  // struct BF_fcast *fptr;
  //unsigned int *cond1, *cond2, *newcond;
  //int npool, r1, r2, word, bitmax;

  unsigned int *cond1; unsigned int *cond2; unsigned int * newcond;
  int numrejects, r1, r2, word, bitmax = 0;
  int bit, different1, different2, temp1, temp2;
  BFCast * aReject;
  
  numrejects = privateParams->npool;
  //npool=[reject getCount];

  do 
    {
      r1 = irand(numrejects);
    }
  while ( [rejects atOffset: r1] == nil );
  

  do
    {
      r2 = irand(numrejects);
    }
  while (r1 == r2 || [rejects atOffset: r2] == nil);
      

  cond1 = [[rejects atOffset: r1] getConditions];
  cond2 = [[rejects atOffset: r2] getConditions];

  newcond = [new getConditions];

  different1 = 0;
  different2 = 0;
  bitmax = 16;
  for (word = 0; word < privateParams->condwords; word++) 
    {
      temp1 = cond1[word] ^ newcond[word];
      temp2 = cond2[word] ^ newcond[word];
      if (word == privateParams->condwords-1)
	bitmax = ((privateParams->condbits-1)&15) + 1;
      for (bit = 0; bit < bitmax; temp1 >>= 2, temp2 >>= 2, bit++) 
	{
	  if (temp1 & 3)
	    different1++;
	  if (temp2 & 3)
	    different2++;
	}
    }

  /*
   *  This is the big decision whether to push diversity by selecting rules
   *  to leave.  Original version is 1 which choses the least different rules
   *  to leave.  Version 2 choses at random, and version 3 choses the least
   *  frequently used rule.  
   */
  if (different1 < different2) 
    {
      aReject = [rejects atOffset: r1];
      [ rejects atOffset: r1  put: nil] ;
    }
  else 
    {
      aReject = [rejects atOffset: r2];
      [ rejects atOffset: r2 put:  nil] ;
    }
  /*
    fptr = reject[r1];
    reject[r1] = NULL;
  */
  /*
    if(reject[r1]->count < reject[r2]->count) {
    fptr = reject[r1];
    reject[r1] = NULL;
    }
    else {
    fptr = reject[r2];
    reject[r1] = NULL;
    }
  */
  
  return aReject;
}



/*------------------------------------------------------*/
/*	Generalize					*/
/*------------------------------------------------------*/
-(void) Generalize: (id) list AvgStrength: (double) avgstrength
  /*
     * Each forecast that hasn't be used for longtime is generalized by
     * turning a fraction genfrac of the 0/1 bits to don't-cares.
     */
{
  register struct BFCast *aForecast;
  register int f;
  int bit, j;
  BOOL changed;
  // int currentTime;
 int * bitlist=NULL;

 bitlist = [privateParams getBitListPtr];

  currentTime = getCurrentTime();

  for (f = 0; f < privateParams->numfcasts; f++) 
    {
      aForecast = [ list atOffset: f ] ;
      if (currentTime - [aForecast getLastactive] > privateParams->longtime) 
	{
	  changed = NO;
	  j = (int)ceil([aForecast getSpecificity]*privateParams->genfrac);
	  for (;j>0;) 
	    {
	      bit = irand(privateParams->condbits);
	      if (bitlist[bit] < 0) continue;
	      // if ((aForecast->conditions[WORD(bit)]&MASK[bit])) 
	      if ( [aForecast getConditionsbit: bit] > 0)
		{
		  // aForecast->conditions[WORD(bit)] &= NMASK[bit];
		  [aForecast maskConditionsbit: bit];
		  [aForecast decrSpecificity];
		  changed = YES;
		  j--;
		}
	    }
	  if (changed) 
	    {
	      [aForecast setCnt: 0];
	      [aForecast setLastactive: currentTime];
	      [aForecast updateSpecfactor];
	      [aForecast setVariance: [aForecast getSpecfactor] / avgstrength];
	      [aForecast setStrength: [aForecast getSpecfactor]/[aForecast getVariance]];
	      //???????????????????????
	      //??bfagent has:   
	      /*  rptr->specfactor = (condbits - pp->nnulls - rptr->specificity)*
		  pp->bitcost;
		  medvar = pp->maxdev-medianstrength+rptr->specfactor;
		  if (medvar >= 0.0)
		  rptr->variance = medvar;
		  rptr->strength = medianstrength;*/

	    }
	}
    }
}


/*"in case you want to see the 0101 representation of an integer. Sometimes this comes in handy if you are looking at a particular forecast's value as an int and you need to convert it to the 0's and 1's"*/
- printcond: (int) word
{
  int i;
  int n = sizeof(int) * CHAR_BIT;
  int mask = 1 << (n-1);
  int  input=word;

  for ( i=1; i <= n; ++i)
    {
      putchar(((input & mask) == 0) ? '0' : '1');
      input <<= 1;
      if (i % CHAR_BIT == 0 && i < n)
  	putchar(' ');
    }
  return self;
}

/*"This is a general utility method for Swarm lists. It removes all objects form the "outputList" and copies the elements from list into it.  It does not actually destroy any elements from either list, it just updates references."*/
- copyList: list To: outputList
{
  id index, anObject;

 [outputList removeAll];
  index = [ list begin: [self getZone] ];
  for( anObject = [index next]; [index getLoc]==Member; anObject=[index next] )
    {
      [outputList addLast: anObject];
    }
  [index drop];
  return self;
}


@end













