#import "Parameters.h"
#import <stdlib.h>

#import <objectbase.h>    //for probeMap
#import <objectbase/ProbeMap.h>
#import <simtools.h>


@implementation Parameters
/*"The Artificial Stock Market model has a very large set of
parameters.  Until ASM-2.2, these paramters were set inside various
implementation files, making them difficult to find/maintain. Now all
parameters are set through separate objects, which can be called upon
whenever needed.  

The Parameters class is an example of a general
purpose Swarm command-line processing class.  In case one is designing
batch simulations, this is the place to customize the command line
options and read them into the program.  From the command line, type
"./asm --help" to see a list of command line arguments this program
will respond to. You should see all default Swarm command line parameters
as well as --run, which is specific to this project.  More parameters can be added in the parseKey:arg: method of this class.

This class also takes responsibility for making sure that objects to manager parameters for the ASMModelSwarm and the BFagents are created.
"*/ 

+ createBegin: aZone
{
  static struct argp_option options[] = {
     {"run",            'R',"RunNumber",0,"Run is...",6},
     {"inputfile",          'I',"filename",0,"set fn",7},
     { 0 }
  };

  Parameters *obj = [super createBegin: aZone];
    
  [obj addOptions: options];
 
  obj->run=-1;

  obj->filename= NULL;

  return obj;
}


/*"In order to parse command line parameters, this method runs.
  Because Parameters is subclassed from the Swarm Arguments class,
  whatever keys we check for in this method will always be checked.
  Since processing of command line parameters has not yet been a focal
  point, only one parameter, the "run" number, is processed here.
  This is included mainly as an example of how other parameters might
  be managed."*/
- (int)parseKey: (int) key arg: (const char*) arg
{
  if (key == 'R')
    {
      run = atoi(arg);
      return 0;
    }
  else if (key == 'I')
    {
      filename = strdup(arg);
      return 0;
    }

  else
    return [super parseKey: key arg: arg];
}


/*"This performs the vital job of using the lispAppArchiver to read
  the baseline values of the parameters out of the asm.scm file and
  then creating the parameter objects--asmModelParms and
  bfParams--that hold those values and make them avalable to the
  various objects in the model "*/
- init 

{
  if (!filename)
    {
      asmModelParams =
	[lispAppArchiver getWithZone: [self getZone] key: "asmModelParams"];
      bfParams =
	[lispAppArchiver getWithZone: [self getZone] key: "bfParams"];
      
    }
     
  else
    {
      id archiver = [LispArchiver create: [self getZone] setPath: filename];
      asmModelParams = [archiver getObject: "asmModelParams"];
      bfParams = [archiver getObject: "bfParams"];
      [archiver drop];
    } 
  if (asmModelParams == nil)
    raiseEvent(InvalidOperation,
	       "Can't find the modelSwarm parameters");

  if (bfParams == nil)
    raiseEvent(InvalidOperation,
               "Can't find the BFParam's parameters");
  [bfParams init];

  return self;
}






/*"Returns an instance of ASMModelParams, the object which holds the model-level input parameters"*/
- (ASMModelParams*) getModelParams
{ 
  return asmModelParams;
}


/*"Returns an instance of the BFParams class, an object which holds
  the default parameter of the BFagents.  If they desire to do so,
  BFagents can create their own instances of BFParams, copy default
  settings, and then allow their parameters to 'wander'.  (As far as I
  know, this potential did not exist before and has not been
  used. PJ-2001-10-31) "*/
- (BFParams*) getBFParams;
{
  return bfParams;
}


/*"Unless one wants to make all IVARS public and access them with ->, then one should create get methods, one for each argument. This gets the run number."*/
- (int) getRunArg
{
  return run;
}

/*"Sometimes we worry that the Parameter object did not get created properly, so this method tells it to speak to the command line with a warm greeting"*/
-sayHello
{
  printf("You are a dirty scoundrel");
  return self;
}



- (char *)getFilename
{

  if (filename)
    return strdup(filename);
  else
    return NULL;
}



@end














