// Code for a "bitstring forecaster" (BF) agent

/*
pj: change comments Nov. 2, 2001.

In 2000 comments, I said I was leaving the privateParams object as
a shared thing used by all BFagents.  Well, I just could not stand
that anymore and so now I have the global BFParams object, the one
for which the GUI shows and it is the default for all instances,
but now each BFagent gets its own instance of BFParams and it is
a copy of BFParams, at least to start. That object privateParams
can now be individualized for each agent. In particular, one thing
on the TODO list has to be the individualization of bitlists.

Other changes described from last year are all still fine.


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
//just have a pointer to a common world object. However, there are
//serveral class methods that use it.

//pj: 
//convenience macros to replace stuff from ASM random with Swarm random stuff 
 
#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 
#define urand()  [uniformDblRand getDoubleWithMin: -1 withMax: 1] 
#define irand(x)  [uniformIntRand getIntegerWithMin: 0 withMax: x-1]  

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
- (void) MakePool: (id <List>)rejects From: (id <Array>) list;
- (BOOL) Mutate: (BFCast *) new Status: (BOOL) changed;
- (BFCast *) Crossover:(BFCast *) newForecast Parent1: (BFCast *) parent1 Parent2: (BFCast *) parent2;
- (void) TransferFcastsFrom: newList To:  forecastList Replace: rejects; 
- (BFCast *)  GetMort: (BFCast *) new Rejects: (id <List>) rejects;
- (void) Generalize: (id) list AvgStrength: (double) avgstrength;
- (BFCast *) Tournament: (id <Array>) list;

@end


@implementation BFagent
/*"The BFagent--"bitstring forecasting agent" is the centerpiece of
the ASM model.  The agent competes in a stock market, it buy, it
sells.  It decides to buy or sell by making predictions about what the
price of the stock is likely to do in future.  In order to make
predictions, it keeps a large list of forecast objects on hand, and
each forecast object makes a price prediction. These forecasts, which
are created from the BFCast subclass, are fairly sophisticated
entities, they may monitor many different conditions of the world.
The forecast which has the best performance record at any given
instant is used to predict the future price, which in turn leads to
the buy/sell decision.

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


/*"This tells BFagents where they should look to get the default
  parameters. it should give the agent an object from the BFParams
  class."*/
+ (void)setBFParameterObject: x
{
    params=x;
}

/*"This is vital to set values in the forecast class, BFCast, which in
  turn initializes BitVector class"*/
+ (void)init
{
  [BFCast init]; 
  return;
}

/*"This creates the container objects activeList and oldActiveList.
  In addition, it makes sure that any initialization in the createEnd
  of the super class is done."*/
- createEnd
{
  activeList=[List create: [self getZone]];
  oldActiveList=[List create: [self getZone]];
  return [super createEnd];
}

/*"initForecasts. Creates BFCast objects (forecasts) and puts them
  into an array called fCastList.  These are the "meat" of this
  agent's functionality, as they are repeatedly updated, improved, and
  tested in the remainder of the class.  Please note each BFagent has
  a copy of the default params object called privateParams.  It can be
  used to set individualized values of settings in BFParams for each
  agent. That would allow true diversity! I don't see how that diversity
  would be allowed for in the ASM-2.0."*/
- initForecasts
{
  int  sumspecificity = 0;
  int i;
  BFCast * aForecast; 
  int numfcasts;
  id index;

// Initialize our instance variables

  // All instances of BFagent have a copy of the same BFParams object
  // that each agent can individualize.
  privateParams = [params copy: [self getZone]];

  //If you want to customize privateParams, this is the spot!
 
  numfcasts = privateParams->numfcasts;

  fcastList=[Array create: [self getZone] setCount: numfcasts];

  avspecificity = 0.0;
  gacount = 0;

  variance = privateParams->initvar;
  [self getPriceFromWorld];
  [self getDividendFromWorld];
  global_mean = price + dividend;
  forecast = lforecast = global_mean;


  // Initialize the forecasts, put them into Swarm Array

  //keep the 0'th forecast in a  "know nothing" condition
  [fcastList atOffset: 0 put: [self createNewForecast]];

  //create rest of forecasts with random conditions
  for ( i = 1; i < numfcasts; i++)
    {
      id aForecast =[self createNewForecast] ;
      [self setConditionsRandomly: aForecast];
      [fcastList atOffset: i put: aForecast]; //put aForecast into Swarm array "fcastlist"
     }

/* Compute average specificity */

  index=[ fcastList begin: [self getZone] ];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
    sumspecificity += [aForecast getSpecificity];
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
- (BFCast *)createNewForecast
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

/*"Take a forecast object and randomly change the bits that govern
  which conditions it monitors.  This appears to be a piece of
  functionality that could move to the BFCast class itself. There were
  quite a few of these details floating around in BFagent at one time,
  many are gone now."*/
- setConditionsRandomly: (BFCast *)fcastObject
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


- prepareForTrading
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

  BFCast *  bestForecast;
  double maxstrength;

 
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

 
  // Go through the list and find best forecast
  maxstrength = -1e50;
  bestForecast = nil;
  nactive = 0;
  mincount = getInt(privateParams,"mincount");

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

  if (nactive)  // meaning that at least some forecasts are active
    {
      pdcoeff = [bestForecast getAval];
      offset = [bestForecast getBval]*dividend + [bestForecast getCval];
      forecastvar = getInt(privateParams,"individual")? [bestForecast getVariance]: variance;
    }

  else  // meaning "nactive" zero, no forecasts are active 
    {
      // No forecasts are minimally adequate!!
      // Use weighted (by count) average of all rules
      countsum = 0.0;
      pdcoeff = 0.0;
      offset = 0.0;
      mincount = getInt(privateParams,"mincount");


      index = [fcastList begin: [self getZone]];
      for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
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

  divisor = privateParams->lambda*forecastvar;
    
  return self;
}

/*"A forecast has a set of conditions it is watching. These are packed
tight in a BitVector. We need the world data about the status of those
conditions packed the same way, in order to make quick checks to find
out if the world conditions are matched by the BitVector's
conditions. This method creates a BitVector to match the conditions
that are being monitored by the agent's forecasts.  This requires the
use of the design assumption that all of an agent's forecasts have the
same bitlist."*/
- (BitVector *)collectWorldData: aZone;
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
	[world setConditionsbit: i To: myRealWorld[n]]; 
    }

  [aZone free: myRealWorld];

   return world;
}


/*"This is the main inner loop over forecasts. Go through the list
  of active forecasts, compare how they did against the world.  Notice
  the switch that checks to see how big the bitvector (condwords) is
  before proceeding.  At one time, this gave a significant
  speedup. The original sfsm authors say 'Its ugly, but it
  works. Don't mess with it!'  (pj: I've messed with it, and don't
  notice much of a speed effect on modern computers with modern
  compilers :> My alternative implementation is commented out inside
  this method)"*/
- updateActiveList: (BitVector *)worldvalues
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
    {
      int real0 = [worldvalues getConditionsWord: 0];
      
      
      index=[ fcastList begin: [self getZone]];
      for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	{
	  if ( [aForecast getConditionsWord: 0] & real0 ) 
	    {
	      continue ;
	    }
	  [activeList addLast: aForecast];
	}
      [index drop];
      
      break;
    }
    case 2:
      {
	int * real = [worldvalues getConditions];
    
	
	index=[ fcastList begin: [self getZone]];
	for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	  {
	    int * conditions = [aForecast getConditions];
	    if ( conditions[0] & real[0] ) continue ;
	    if ( conditions[1] & real[1] ) continue ;
	    [activeList addLast: aForecast];
	  }
	[index drop];
	
	break;
      }
  case 3:
    { 
      int * real = [worldvalues getConditions];
   
      
      index=[ fcastList begin: [self getZone]];
      for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	{
	  int * conditions = [aForecast getConditions];
	  if ( conditions[0] & real[0] ) continue ;
	  if ( conditions[1] & real[1] ) continue ;
	  if ( conditions[2] & real[2] ) continue ;
	  [activeList addLast: aForecast];
	}
      [index drop];
      break;
    }
    case 4:
      { 
	int * real = [worldvalues getConditions];
	
	index=[ fcastList begin: [self getZone]];
	for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	  {
	    int * conditions = [aForecast getConditions];
	    if ( conditions[0] & real[0] ) continue ;
	    if ( conditions[1] & real[1] ) continue ;
	    if ( conditions[2] & real[2] ) continue ;
	    if ( conditions[3] & real[3] ) continue ;
	    [activeList addLast: aForecast];
	  }
	[index drop];

      break;
      }
    case 5:
      {
 	int * real = [worldvalues getConditions];
	index=[ fcastList begin: [self getZone]];
	for ( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
	  {
	    int * conditions = [aForecast getConditions];
	    if ( conditions [0] & real[0] ) continue ;
	    if ( conditions [1] & real[1] ) continue ;
	    if ( conditions [2] & real[2] ) continue ;
	    if ( conditions [3] & real[3] ) continue ;
	    if ( conditions [4] & real[4] ) continue ;
	    [activeList addLast: aForecast];
	  }
	[index drop];
	break;
      }
  }
#if MAXCONDBITS > 5*16
#error Too many condition bits (MAXCONDBITS)
#endif

     //pj??? There ought to be a "default" action here for other cases.

  return self;
}


- (double)getDemandAndSlope: (double *)slope forPrice: (double)trialprice
  /*" Returns the agent's requested bid (if >0) or offer (if <0) using
* best (or mean) linear forecast chosen by -prepareForTrading. The
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
- (double)getRealForecast
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

- updatePerformance
{
  BFCast *  aForecast;
  id <Index> index = nil;
  double deviation, ftarget, tauv, a, b, c, maxdev;

  // Precompute things for speed
  tauv = privateParams->tauv;
  a = 1.0/tauv;
  b = 1.0-a;

    /* fixed variance if tauv at max */
  if (tauv == 100000) 
    {
      a = 0.0;
      b = 1.0;
    }
  maxdev = privateParams->maxdev;

  [self getPriceFromWorld];
  ftarget = price + dividend;

// Update global mean (p+d) and our variance
    
  realDeviation = deviation = ftarget - lforecast;
  if (fabs(deviation) > maxdev) deviation = maxdev;
  global_mean = b*global_mean + a*ftarget;
  
  variance = b*variance + a*deviation*deviation;

  index = [ activeList begin: [self getZone]];
  for( aForecast=[index next]; [index getLoc]==Member; aForecast=[index next] )
    {
      [aForecast updateForecastPrice: price Dividend: dividend];
    }
  [index drop];
   
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

//**** most critical change by pj to improve learning and convergence behaviour ******
//*************************************************************************************	      

	      c = 1.0/(double) (1.0 +[aForecast getCnt]);  //??bfagent had no 1+ here ??

//*************************************************************************************

	      [aForecast setVariance: (1.0 - c)*[aForecast getVariance] +
			 c*deviation];
	    }
	  
	  [aForecast setStrength: privateParams->maxdev 
		     - [aForecast getVariance]
		     + [aForecast getSpecfactor]];
	}

      [index drop];
    }
 
  return self;
}

/*"Returns the absolute value of realDeviation"*/
- (double)getDeviation
{
  return fabs(realDeviation);
}

/*"Returns the "condbits" variable from parameters: the number of
  condition bits that are monitored in the world, or 0 if
  condition bits aren't used.
  "*/
- (int)nbits
{
  return privateParams->condbits;
}

/*"Returns the number of forecasts that are used. In the original
  design, this was a constant set in the parameters, although revision
  of the code for ASM-2.2 conceivably should allow agents to alter the
  number of forecasts they maintain."*/
- (int)nrules
{
  return privateParams->numfcasts;
}


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
- (int)bitDistribution: (int *(*)[4])countptr cumulative: (BOOL)cum
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

  return condbits;
}


- (int)fMoments: (double *)moment cumulative: (BOOL)cum
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
      moment[5] += [aForecast getCval]*[aForecast getCval];
   }
 [index drop];  
  return privateParams->numfcasts;
}

//pj: this method is not called anywhere

/*"Currently, this method is not called anywhere in ASM-2.2. It might
  serve some purpose, past or present, I don't know (pj:
  2001-10-26)"*/
// ASM-2.0 documentation:
//	If the agent uses condition bits, returns a description of the
//	specified bit.  Invalid bit numbers return an explanatory message.
//	Agents that don't use condition bits return NULL.
//
- (const char *)descriptionOfBit: (int)bit
{
  if (bit < 0 || bit > getInt(privateParams,"condbits"))
    return "(Invalid condition bit)";
  else
    return [World descriptionOfBit:privateParams->bitlist[bit]];
}


/*" Genetic algorithm. It relies on the following separate methods.
(pj: 2001-11-25. I still see some room for improvement here, but the
emphasis is to eliminate all global variables and explicitly pass
return values instead.  Any values needed for computations should
either be passed explicitly or taken from someplace safe)
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
  register int f;
  int  new;
  BFCast * parent1, * parent2;
 
  double ava,avb,avc,sumc;
  double madv=0.0; 
  double meanv = 0.0;
  double temp;  //for holding values needed shortly
  //pj: previously declared as globals
  int * bitlist;

  id newList = [List create: [self getZone]]; //to collect the new forecasts; 
  id rejectList = [Array create: [self getZone] setCount: getInt(privateParams,"npoolmax")];

  static double avstrength;//static inside a method has a different effect than static in a class

  ++gacount;
  currentTime = getCurrentTime();

  bitlist = privateParams->bitlist;

  // Find the npool weakest rules, for later use in TrnasferFcasts
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
  avstrength /= privateParams->numfcasts;

  meanv = meanv/ privateParams->numfcasts;

  for (f=0; f < privateParams->numfcasts; f++) 
    {
      madv += fabs( [[fcastList atOffset:f] getVariance] - meanv); 
    }

  madv = madv/privateParams->numfcasts;

  /*
   * Set rule 0 (always all don't care) to inverse variance weight 
   * of the forecast parameters.  A somewhat Bayesian way for selecting 
   * the params for the unconditional forecast.  Remember, rule 0 is imune to
   * all mutations and crossovers.  It is the default rule.
   */
  [[fcastList atOffset: 0] setAval: ava/ sumc ];
  [[fcastList atOffset: 0] setBval: avb/ sumc ];
  [[fcastList atOffset: 0] setCval: avc/ sumc ];
  
    
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
   
          [aNewForecast setLastactive: currentTime];
	  varvalue =  privateParams->maxdev-avstrength+[aNewForecast getSpecfactor];

	  [aNewForecast setVariance: varvalue];
	  altvarvalue = [[fcastList atOffset: 0] getVariance]- madv;
	  if ( varvalue < altvarvalue )
	  {
	    [aNewForecast setVariance: altvarvalue];
	    [aNewForecast setStrength: privateParams->maxdev - altvarvalue + [aNewForecast getSpecfactor]];
	   }
	  [aNewForecast setLastactive: currentTime];
	  
	  [newList addLast: aNewForecast]; //?? were these not initialized in original?//
          
	  // Pick first parent using touranment selection
	  do
	    parent1 = [ self Tournament: fcastList ] ;
	  while (parent1 == nil);

	  // Perhaps pick second parent and do crossover; otherwise just copy
	  if (drand() < privateParams->pcrossover) 
	    {
	      do
		parent2 = [self  Tournament: fcastList];
	      while (parent2 == parent1 || parent2 == nil) ;

	      [self Crossover:  aNewForecast Parent1:  parent1 Parent2:  parent2];
	      if (aNewForecast==nil) {raiseEvent(WarningMessage,"got nil back from crossover");}
	      changed = YES;
	    }
	  else
	    {
	      [self CopyRule: aNewForecast From: parent1];
	      if(!aNewForecast)raiseEvent(WarningMessage,"got nil back from CopyRule");
	
	      changed = [self Mutate: aNewForecast Status: changed];
	    }
	  //It used to only do this if changed, but why not all??
	 
	} while (0);
      /* Replace while(0) with while(!changed) to force diversity */
    }

  // Replace nnew of the weakest old rules by the new ones

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
	parent1 = [fcastList atOffset: f];
	specificity += [parent1 getSpecificity];
      }
    avspecificity = ((double) specificity)/(double)privateParams->numfcasts;

  }

  [newList deleteAll]; 
  [newList drop];

  [rejectList drop]; 

  return self;
}



/*"This is a method that copies the instance variables out of one
  forecast object into another. It copies not only the bitvector of
  monitored conditions, but also the forecast value, strength,
  variance, specFactor, specificity, and so forth.  The only deviation
  is that if the return from the original forecast's getCnt method
  (its count value) is equal to 0, then the strength of the copy is
  equal to the value of a static variable named minstrength."*/

- (BFCast *)CopyRule: (BFCast *)to From: (BFCast *)from
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


/*"Given a list of forecasts, find the worst ones and put them into a
pool of rejects. This method requires 2 inputs, the name of the reject
list (actually, a Swarm Array) and the Array of forecasts. "*/
- (void)MakePool: (id <List>)rejects From: (id <Array>)list
{
  register int top;
  int i,j = 0 ;
  BFCast * aForecast;
  BFCast * aReject;
  
  top = -1;
  //pj: why not just start at 1 so we never worry about putting forecast 0 into the mix?
  for ( i=1; i <= privateParams->npool ; i++ )
    {
      aForecast=[list atOffset: i];
      for ( j=top;  j >= 0 && (aReject=[rejects atOffset:j])&& ([aForecast getStrength] < [aReject  getStrength] ); j--)
	{
	  [rejects atOffset: j+1 put: aReject ];
	}  //note j decrements at the end of this loop
      [rejects atOffset: j+1 put: aForecast];
      top++;
    }
	  
  for ( ; i < privateParams->numfcasts; i++)
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
- (BOOL)Mutate: (BFCast *)new Status: (BOOL)changed
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
	      if ([new getConditionsbit: bit] > 0 ) 
		{
		  if (irand(3) > 0) 
		    {
		      [new maskConditionsbit: bit];
		      [new decrSpecificity];
		    }
		  else
		    [new switchConditionsbit: bit];
		  bitchanged = changed = YES;
		}
	      else if (irand(3) > 0) 
		{
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
- (BFCast *)Crossover: (BFCast *)newForecast Parent1: (BFCast *)parent1 Parent2: (BFCast *)parent2
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

  [newForecast setCnt: 0 ];	// call it new in any case
  [newForecast updateSpecfactor];
  [newForecast setStrength :  0.5*([parent1 getStrength] + [parent2 getStrength])];

  return newForecast;
}


/*------------------------------------------------------*/
/*	TransferFcasts					*/
/*------------------------------------------------------*/
- (void)TransferFcastsFrom: newlist To: forecastList Replace: rejects 
{
  id ind;
  BFCast * aForecast;
  BFCast * toDieForecast;
  int newcount = 0 , rejectcount = 0;

  if ( (newcount = [newlist getCount]) < (rejectcount= [rejects getCount]))
    {
      ind = [newlist begin: [self getZone]];
      for ( aForecast = [ind next]; [ind getLoc]==Member; aForecast=[ind next] )
	{
	  toDieForecast = [self GetMort: aForecast Rejects: rejects];
	  toDieForecast = [self CopyRule: toDieForecast From: aForecast];
	}
      [ind drop];
    }
  else if ( newcount == rejectcount)
    {
      //copy all newforecasts to replace rejects
      int i;
      for ( i = 0; i < newcount; i++)
	{
	  toDieForecast = [rejects atOffset: i];
	  [rejects atOffset: i put:  nil];
	  aForecast = [newlist atOffset: i];
	  toDieForecast = [self CopyRule: toDieForecast From: aForecast];
	}
    }
  else
    {
      raiseEvent(InvalidArgument,"npool smaller than nnew, can't do it");
    }


}



/*------------------------------------------------------*/
/*	GetMort						*/
/*------------------------------------------------------*/
- (BFCast *)GetMort: (BFCast *)new Rejects: (id <List>)rejects
  /* GetMort() selects one of the npool weak old fcasts to replace
     * with a newly generated rule.  It pays no attention to strength,
     * but looks at similarity of the condition bits -- like tournament
     * selection, we pick two candidates at random and choose the one
     * with the MORE similar bitstring to be replaced.  This maintains
     * more diversity.
     */
{
  
  unsigned int *cond1; unsigned int *cond2; unsigned int * newcond;
  int numrejects, r1, r2, word, bitmax = 0;
  int bit, different1, different2, temp1, temp2;
  BFCast * aReject;
  
  numrejects = privateParams->npool;
  
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
   *  This is the big decision whether to push diversity by selecting
   *  rules to leave.  Originally there were three versions: Version 1
   *  which choses the least different rules to leave.  Version 2
   *  choses at random, and version 3 choses the least frequently used
   *  rule. Only version 1 is left.
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
  return aReject;
}



/*------------------------------------------------------*/
/*	Generalize					*/
/*------------------------------------------------------*/
- (void)Generalize: (id)list AvgStrength: (double)avgstrength
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
  int * bitlist = NULL;

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
	      if ( [aForecast getConditionsbit: bit] > 0)
		{
		  [aForecast maskConditionsbit: bit];
		  [aForecast decrSpecificity];
		  changed = YES;
		  j--;
		}
	    }
	  if (changed) 
	    {
	      double varvalue;
	      [aForecast setCnt: 0];
	      [aForecast setLastactive: currentTime];
	      [aForecast updateSpecfactor]; 
	      varvalue = privateParams->maxdev - avgstrength + [aForecast getSpecfactor];
	      if (varvalue >0 ){
		[aForecast setVariance: varvalue]; 
	      }
	      //apparently don't change variance otherwise !
	      [aForecast setStrength: avgstrength];
	    }
	}
    }
}


/*"in case you want to see the 0101 representation of an
  integer. Sometimes this comes in handy if you are looking at a
  particular forecast's value as an int and you need to convert it to
  the 0's and 1's"*/
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

/*"This is a general utility method for Swarm lists. It removes all
  objects form the "outputList" and copies the elements from list into
  it.  It does not actually destroy any elements from either list, it
  just updates references."*/
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













