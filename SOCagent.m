// Code for a Social agent

#import "SOCagent.h"
#import <random.h>

#define drand()    [uniformDblRand getDoubleWithMin: 0 withMax: 1] 

@implementation SOCagent

//************************************************************************
- (BOOL)PickParents: (BFCast *)aNewForecast Status: (BOOL) changed
{
  double psocial = 0.5;
  BFCast * parent1, * parent2;
  id agentlist;
  id agent,index = 0;
  ASMModelSwarm * asmModelSwarm;
   
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
      asmModelSwarm = 
      agentlist = [asmModelSwarm getAgentList];
      index = [agentlist begin: [self getZone]];
      int num = [agentlist getCount];
      int zahl = [asmModelSwarm getNumBFagents];
      printf("number of agents=%d num=%d\n",zahl, num);
      while ((agent = [index next]))
	{
	  printf("Agent number %3d\n",[agent getID]);
	}
    }
  return (changed);
}



@end













