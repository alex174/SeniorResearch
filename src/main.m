#import <simtools.h>
#import "ASMObserverSwarm.h"
#import "ASMBatchSwarm.h"
#import "Parameters.h"

// The main() function is the top-level place where everything starts.
// For a typical Swarm simulation, in main() you create a toplevel
// Swarm, let it build and activate, and set it to running.

int
main (int argc, const char **argv) 
{
  id theTopLevelSwarm;



  // Swarm initialization: all Swarm apps must call this first.
  initSwarmArguments (argc, argv, [Parameters class]);

  arguments= [(Parameters *) arguments init];


  if(swarmGUIMode == 1)
    theTopLevelSwarm = [ASMObserverSwarm create: globalZone];
  else
    if ((theTopLevelSwarm =
	 [lispAppArchiver getWithZone: globalZone key: "asmBatchSwarm"]) == nil)
    raiseEvent(InvalidOperation,
               "Can't find the batchSwarm parameters");


  [theTopLevelSwarm buildObjects];
  [theTopLevelSwarm buildActions];
  
 //   while (1)
      {
      id <SwarmActivity> activity = [theTopLevelSwarm activateIn: nil];
      [theTopLevelSwarm go];
      [activity drop];
      if (swarmGUIMode == 0)
	[theTopLevelSwarm expostParamWrite];
      [theTopLevelSwarm drop];
       }
  // The toplevel swarm has finished processing, so it's time to quit.
  return 0;
}







