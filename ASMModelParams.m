#import "ASMModelParams.h"
#import <objectbase.h>  //for probes


@implementation ASMModelParams
/*"The ASMModelParams class is a "holding class" for the parameters
  that are associated with the ASMModelSwarm class and it also
  controls the GUI probes that users can use to change variables at
  runtime.  These values are set here in order to keep the code clean
  and neat!  Several parts of the simulation need to have access to
  the information held by ASMModelParams, not just ASMModelParams, but
  also any classes that want information on system parameters.

  A big reason for keeping these values in a separate class is that
  they can be used by both batch and graphical runs of the model.

  There are values saved for these parameters in the asm.scm file, and
  the Parameters class, which orchestrates all this parameter magic,
  does the work of creating one of these ASMModelParams objects."*/

+createBegin: (id) aZone
{
  ASMModelParams * obj;
  id <ProbeMap> probeMap;

  obj = [super createBegin: aZone];

  probeMap = [EmptyProbeMap createBegin: aZone];
  [probeMap setProbedClass: [self class]];
  probeMap = [probeMap createEnd];
  
  [probeMap addProbe: [probeLibrary getProbeForVariable: "numBFagents"
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "initholding"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "initialcash"
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "minholding"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "mincash"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "intrate"
  			            inClass: [self class]]];

  [probeMap addProbe: [probeLibrary getProbeForVariable: "baseline"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "mindividend"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxdividend"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "amplitude"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "period"
  			            inClass: [self class]]];

  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxprice"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "minprice"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "taup"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "exponentialMAs" 
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "sptype"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxiterations" 
				    inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "minexcess"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "eta"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "etamin"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "etamax"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "rea"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "reb"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "randomSeed"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxbid"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "maxdev"
  			            inClass: [self class]]];
  [probeMap addProbe: [probeLibrary getProbeForVariable: "setOutputForData"
  			            inClass: [self class]]];

  [probeLibrary setProbeMap: probeMap For: [self class]];

  return obj;

}

@end
