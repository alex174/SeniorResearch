ifeq ($(SWARMHOME),)
SWARMHOME=/usr
endif
APPVERSION=2.1
BUGADDRESS=weber2@ssc.upenn.edu
APPLICATION = asm
OBJECTS = Agent.o Dividend.o World.o \
	  Specialist.o Output.o ASMModelSwarm.o \
	  ASMObserverSwarm.o ASMBatchSwarm.o main.o BFParams.o BFCast.o BFagent.o
OTHERCLEAN =  param.data_* output.data* 
DATAFILES = batch.setup param.data

include $(SWARMHOME)/etc/swarm/Makefile.appl

main.o: main.m ASMObserverSwarm.h ASMBatchSwarm.h
Agent.o: Agent.h Agent.m
BFAgent.o: BFagent.h BFagent.m BFParams.h BFCast.h World.h
Dividend.o: Dividend.h Dividend.m
Output.o: Output.h Output.m 
ASMModelSwarm.o: ASMModelSwarm.h ASMModelSwarm.m BFParams.o 
Specialist.o: Specialist.h Specialist.m 
World.o: World.h World.m 
ASMModelSwarm.o: ASMModelSwarm.h ASMModelSwarm.m Output.h BFParams.h BFCast.h Specialist.h Dividend.h World.h BFagent.h Agent.h 
ASMObserverSwarm.o: ASMObserverSwarm.h ASMObserverSwarm.m 
ASMBatchSwarm.o: ASMBatchSwarm.h ASMBatchSwarm.m 
BFParams.o: BFParams.h BFParams.m World.h
BFCast.o: BFCast.h BFCast.m
