#import "Output.h"

#include <misc.h> // stdio, time
#import "BFagent.h" 
#import "BFCast.h" //for bitDist
#import <analysis.h>
#import "Parameters.h"

/*"
This class helps with data output.  The time plots will
show on the screen--if you want--and they also write data into files.

The time stream data is saved in two formats, just for 
demonstration purposes.

1) Text output of data streams.
2) HDF5 output EZGraph which writes one vector per plotted line
   into an hdf5 file.

The latter requires your system have HDF5 installed. If not, 
compile with this command:

 make EXTRACPPFLAGS=-DNO_HDF5

The hdf5 file is created EVERY TIME YOU RUN THE MODEL.

The text ouput file will be created only if you turn it on from the
graphical interface or you run the model in batch model.  The buttons
in the ASMObserverSwarm display turn on data saving in text format.
Look for "toggleDataWrite".  If "toggleDataWrite" is empty or false,
hit that button and it shows "true". When the model runs, output will
be created. If you run the program in batch mode, it automatically
turns on the data writing.

Please note that if you want the simulation to save your parameter
values to a file, you can click the GUI button
"writeSimulationParams." If you push that button, the system writes
the parameter values into a file, such as

guiSettingsThu_Jun_28_23_48_00_2001.scm


One key change from the old ASM is that you can push that
button at time 0, and it will save a snap at that time, and any time
you stop the model, you can change parameters and punch the button
again, and it will also save a snapshot at quit time.  I believe this
works fine now, but it was a little tricky making sure the objects are
created in the right order and early enough to allow this to work.

Now, just a word about data formatting.  Because it is familiar and
compatible with existing programs, I often prefer to save data in raw
ASCII format.  In case you want text output, this shows you how to do it.
I think filenames that have the date in them are good to
help remember when they were originally created, for example.  It
creates an ASCII file, for example,

output.data_Thu_Jun_28_23_48_00_2001

However, I understand the reasons others are pushing to use more
refined formats.  So I've used the Swarm EZGraph for the dual purposes
of drawing on the screen and writing into an hdf5 file.  The hdf5 file
has the run number appended to the basename of the file, so, for example,
the output of run 33 would be named:

stockData33.hdf

If you are running from the graphical interface and the run variable
is not explicitly set, then run equals "-1" and the output file will 
have a date string pasted into it:

 stockData-Sun_May_18_10_47_58_2003.hdf


"*/

@implementation Output


/*"createEnd does a lot of specific things that make the data output
  objects work. It gets the system time, uses that to fashion a
  filename that includes the time, then where necessary it creates
  archivers which will later be called on to get readings on the
  system and record them."*/
- createEnd
{
  int i;
 
  char paramFileName[100];

  if(!runTime)
    runTime = time(NULL);
  
  dataFileExists = NO;
 
  strcpy (timeString, ctime(&runTime));

  for (i = 0; i < 100; i++)
    {
      if (timeString[i] == ' ' || timeString[i] == ':')
	timeString[i] = '_';
      else if (timeString[i] == '\n')
	timeString[i] = '\0';
    }



  if (swarmGUIMode == 1)
    strcpy (paramFileName,"guiSettings");
  else
    strcpy (paramFileName,"batchSettings");

  strcat (paramFileName, timeString);

  strcat (paramFileName,".scm");
  
  unlink ("settingsSaved.scm");
  
  archiver = [LispArchiver create: [self getZone] setPath: paramFileName];
  unlink ("settingsSaved.scm");

  for (i=0;i<16;i++) bs[i]=0;
  for (i=0;i<3;i++) cs[i]=0;
  return self;
}

/*"The output object needs to have a reference to a Specialist object, from whom it can gather data on the volume of trade."*/
- setSpecialist: (Specialist *)theSpec
{
  outputSpecialist = theSpec;
  return self;
}

/*"The output object must have a reference to a World object, from which it can get price, dividend, or any other information it wants"*/
- setWorld: (World *)theWorld;
{
  outputWorld = theWorld;
  return self;
}


- (void)setAgentlist: list
{
  agentList = list;
}


/*"This flushes a snapshot of the current parameter settings from
  both the ASMModelParams and BFAgentParams into a file"*/
- writeParams: modelParam BFAgent: bfParms Time: (long int) t
{
  char modelKey[20];
  char paramKey[20];

  sprintf (modelKey, "modelParams%ld",t);
  sprintf (paramKey, "bfParams%ld",t);
  
  [archiver putShallow: modelKey object: modelParam];
  [archiver sync];

  [archiver putShallow: paramKey  object: bfParms];
  [archiver sync];

  return self;
}



/*"Because it is possible for users to turn on data writing during a
  run of the simulation, it is necessary to have this method which can
  initialize the data output files. Each time this is called, it
  checks to see if the files have already been initialized. That way
  it does not initialize everything twice."*/
- prepareCOutputFile
{
  char outputFile[256];

  if (dataFileExists == YES) return self;

  else{
    
    strcpy (outputFile,"output.data");
    strcat (outputFile, timeString);
    
    if(!(dataOutputFile = fopen(outputFile,"w")))
      abort();
    fprintf (dataOutputFile, "currentTime\t price\t\t dividend\t volume\n\n");
    dataFileExists = YES;
  }
  return self;
}



/*"This method is needed to stop run-time hangs when users close graph windows by clicking on their system's window close button"*/
- _priceGraphDeath_ : caller
{
  [priceGraph drop];
  priceGraph = nil;
  return self;
}

/*"This method is needed to stop run-time hangs when users close graph windows by clicking on their system's window close button"*/
- _volumeGraphDeath_ : caller
{
  [volumeGraph drop];
  volumeGraph = nil;
  return self;
}


/*"This method is needed to stop run-time hangs when users close graph windows by clicking on their system's window close button"*/
- _bitGraphDeath_ : caller
{
  [bitGraph drop];
  bitGraph = nil;
  return self;
}

- createTimePlots
{
  int i = 0;

#ifndef NO_HDF5
  int run = [(Parameters *)arguments getRunArg];
  char hdfEZGraphName[100];
  if (run != -1)
    sprintf (hdfEZGraphName, "stockData-%d.hdf", run);
  else
    sprintf (hdfEZGraphName, "stockData-%s.hdf", timeString);


  hdf5container = [HDF5 createBegin: [self getZone]];
  [hdf5container setWriteFlag: YES];
  [hdf5container  setName: hdfEZGraphName];
  hdf5container = [hdf5container createEnd];
#endif

  priceGraph = [EZGraph createBegin: [self getZone]];
#ifndef NO_HDF5
  [priceGraph setHDF5Container: hdf5container];
#endif  
  [priceGraph setTitle: "Price v. time"];
  [priceGraph setAxisLabelsX: "time" Y: "price"];
  [priceGraph setWindowGeometryRecordName: "priceGraph"];
  [priceGraph enableDestroyNotification: self
 	      notificationMethod: @selector (_priceGraphDeath_:)];
  
  priceGraph =  [priceGraph createEnd];
#ifndef NO_HDF5
  [priceGraph setFileOutput: YES];
  [priceGraph setFileName: "prices"]; //name inside hdf5 file
#endif  

  if (swarmGUIMode == YES)
    [priceGraph setGraphics: YES];
  else
    [priceGraph setGraphics: NO];
  
  prsequence[0] = [priceGraph createSequence: "actual price" 
			      withFeedFrom: outputWorld
			      andSelector: M(getPrice)];
  prsequence[1] = [priceGraph createSequence: "risk neutral price"
			      withFeedFrom: outputWorld
			      andSelector: M(getRiskNeutral)];



  volumeGraph = [EZGraph createBegin: [self getZone]];
#ifndef NO_HDF5
  [volumeGraph setHDF5Container: hdf5container];
#endif
  [volumeGraph  setTitle: "Volume v. time"];
  [volumeGraph  setAxisLabelsX: "time" Y: "volume"];
  [volumeGraph  setWindowGeometryRecordName: "volumeGraph"];
  
  volumeGraph = [volumeGraph createEnd];
#ifndef NO_HDF5
  [volumeGraph setFileOutput: YES]; 
  [volumeGraph setFileName: "volume"]; //name inside hdf5 file
#endif  
  [volumeGraph enableDestroyNotification: self
	       notificationMethod: @selector (_volumeGraphDeath_:)];
  
  volsequence = [volumeGraph createSequence: "actual volume"
			     withFeedFrom: outputSpecialist
			     andSelector: M(getVolume)];
  
  if (swarmGUIMode == YES)
      [volumeGraph setGraphics: YES];
  else
      [volumeGraph setGraphics: NO];


  bitGraph = [EZGraph createBegin: [self getZone]];
#ifndef NO_HDF5
  [bitGraph setHDF5Container: hdf5container];
#endif
  [bitGraph  setTitle: "bit usage"];
  [bitGraph  setAxisLabelsX: "time" Y: "frequency"];
  [bitGraph  setWindowGeometryRecordName: "bitGraph"];
  
  bitGraph = [bitGraph createEnd];
#ifndef NO_HDF5
  [bitGraph setFileOutput: YES]; 
  [bitGraph setFileName: "bituse"]; //name inside hdf5 file
#endif  
  [bitGraph enableDestroyNotification: self
	       notificationMethod: @selector (_bitGraphDeath_:)];
  
  for ( i = 0; i < 3; i++)
    {
      char name[10];
      sprintf (name, "cs[%d]",i);
      cssequence[i] = [bitGraph createSequence: name
				withFeedFrom: self
				andSelector: M(getCS:)];
      [cssequence[i] setUnsignedArg: i];
    }
 
  if (swarmGUIMode == YES)
      [bitGraph setGraphics: YES];
  else
      [bitGraph setGraphics: NO];


  return self;
}


- stepPlots
{
  [priceGraph step];
  [volumeGraph step];

  [self calculateBitData];
  [bitGraph step];
  return self;
}





- calculateBitData
{
  int i;
  static int *(*countpointer)[4];
  BOOL cum;
  id index, agent; 
  long t = getCurrentTime();

  cum = NO;
  countpointer = calloc(4,sizeof(int));
  
  for (i=0;i<16;i++) bs[i]=0;
  now = time(NULL);
  if (t%10000 == 0) printf("at time %s %7ld runs complete\n",asctime(localtime(&now)),t);
  index = [agentList begin: [self getZone]];
  while ((agent = [index next]))
    {
      //printf("Agent number %3d\n",[agent getID]);
      [agent bitDistribution: countpointer cumulative:cum];
      for (i = 0; i < [agent nbits];i++ ) 
	{
	  bs[i]=bs[i]+(*countpointer)[1][i]+(*countpointer)[2][i];
	  
	}
    }

  [index drop];
         

  
  cs[0]=0; cs[1]=0; cs[2]=0;
  
  for (i = 0; i < 16;i++ )
    {
      if (i < 10) cs[0] = cs[0]+bs[i];
      else if ( i >= 10 && i < 13) cs[1] = cs[1]+bs[i];
      else cs[2] = cs[2]+bs[i];
    }

  free (countpointer);
  return self;
}

- (double)getCS: (unsigned) i
{
  return cs[i];
}



//Modified by BaT 10.09.2002 to write additional agent-specific data on file*/

- writeCData
{
  int i;
  long t = getCurrentTime();

  // First, just dump out the raw numbers in text.
  // This is the old standby!
  
  fprintf (dataOutputFile, "%10ld\t %5f\t %8f\t %f ", 
	   t, 
           [outputWorld getPrice],
           [outputWorld getDividend], 
           [outputSpecialist getVolume]);


 
  for (i=0;i<16;i++) fprintf(dataOutputFile,"%3d ",bs[i]);
  //for (i=0;i<16;i++) fprintf(stderr,"%3d ",bs[i]);fprintf(stderr,"\n");
  fprintf(dataOutputFile,"%f %f %f", (double)cs[0]/10.0,(double)cs[1]/4.0,(double)cs[2]/10.0);
  fprintf(dataOutputFile,"\n");
 

   return self;
}



/*"It is necessary to drop the data writing objects in order to make
sure they finish their work.
"*/
-(void) drop
{
  [priceGraph drop];
  [volumeGraph drop];

  if (dataOutputFile) fclose(dataOutputFile);
  [archiver drop];
 
  [super drop];
}

@end



