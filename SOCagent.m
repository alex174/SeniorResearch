// Code for a Social agent

#import "SOCagent.h"
#import <random.h>

#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 

@implementation SOCagent

//************************************************************************
- (BOOL)PickParents: (BFCast *)aNewForecast
{
  double psocial = -0.1;
  BFCast * parent1, * parent2;
  id agent,index = 0;
  BOOL changed = NO;
   
  if (drand() > psocial)
    {
      //for comments on that part of if statement see same passage in BFagent.m
      do
	parent1 = [ super Tournament: fcastList ] ;
      while (parent1 == nil);
      
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
    }
  else
    {
     
      index = [agentList begin: [self getZone]];
 
      while ((agent = [index next]))
	{
	  //	  printf("Agent number %3d\n",[agent getID]);
	}
    }
  return changed;
}



@end













