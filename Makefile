ifeq ($(SWARMHOME),)
SWARMHOME=/usr
endif
APPVERSION=2.1.1
BUGADDRESS=pauljohn@ukans.edu
APPLICATION = asm
OBJECTS = Agent.o Dividend.o World.o \
	  Specialist.o Output.o ASMModelSwarm.o \
	  ASMObserverSwarm.o ASMBatchSwarm.o main.o BFParams.o BFCast.o BFagent.o BitVector.o \
	  ASMModelParams.o Parameters.o MovingAverage.o

OTHERCLEAN =  param.data_* output.data* 
DATAFILES = batch.setup param.data

include $(SWARMHOME)/etc/swarm/Makefile.appl

main.o: main.m ASMObserverSwarm.h ASMBatchSwarm.h
Agent.o: Agent.h Agent.m
BFagent.o: BFagent.h BFagent.m BFParams.h BFCast.h World.h BitVector.h
Dividend.o: Dividend.h Dividend.m
Output.o: Output.h Output.m BFParams.h ASMModelParams.h
ASMModelSwarm.o: ASMModelSwarm.h ASMModelSwarm.m BFParams.o 
Specialist.o: Specialist.h Specialist.m 
World.o: World.h World.m MovingAverage.h
ASMModelSwarm.o: ASMModelSwarm.h ASMModelSwarm.m Output.h BFParams.h Specialist.h Dividend.h World.h BFagent.h Agent.h BFagent.h
ASMObserverSwarm.o: ASMObserverSwarm.h ASMObserverSwarm.m 
ASMBatchSwarm.o: ASMBatchSwarm.h ASMBatchSwarm.m 
BFParams.o: BFParams.h BFParams.m World.h
BFCast.o: BFCast.h BFCast.m BitVector.h
BitVector.o: BitVector.h BitVector.m
ASMModelParams.o: ASMModelParams.h  ASMModelParams.m
Parameters.o: Parameters.h Parameters.m ASMModelParams.h BFParams.h
MovingAverage.o: MovingAverage.h MovingAverage.m
