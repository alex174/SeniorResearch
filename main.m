#import <simtools.h>
#import "ASMObserverSwarm.h"
#import "ASMBatchSwarm.h"

// The main() function is the top-level place where everything starts.
// For a typical Swarm simulation, in main() you create a toplevel
// Swarm, let it build and activate, and set it to running.

int
main (int argc, const char **argv) 
{
  id theTopLevelSwarm;

  // Swarm initialization: all Swarm apps must call this first.
  initSwarm (argc, argv);

  if(swarmGUIMode == 1)
    theTopLevelSwarm = [ASMObserverSwarm create: globalZone];
  else
    theTopLevelSwarm = [ASMBatchSwarm create: globalZone];
  
  [theTopLevelSwarm buildObjects];
  [theTopLevelSwarm buildActions];
  [theTopLevelSwarm activateIn: nil];
  [theTopLevelSwarm go];

  if(([[theTopLevelSwarm getActivity] getStatus] == Completed) && swarmGUIMode == 1)
    if([theTopLevelSwarm ifParamWrite])
      [theTopLevelSwarm expostParamWrite];
    
  // The toplevel swarm has finished processing, so it's time to quit.
  return 0;
}







