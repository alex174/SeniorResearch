ifeq ($(SWARMHOME),)
SWARMHOME=../swarm-1998-08-20
endif
APPLICATION = asm
OBJECTS = Agent.o BFagent.o Dividend.o World.o \
	  random.o Specialist.o Output.o ASMModelSwarm.o \
	  ASMObserverSwarm.o ASMBatchSwarm.o main.o
OTHERCLEAN =  param.data_* output.data* 
DATAFILES = batch.setup param.data

include $(SWARMHOME)/etc/swarm/Makefile.appl

main.o: main.m ASMObserverSwarm.h Agent.h BFagent.h Dividend.h World.h \
	random.h Specialist.h Output.h ASMBatchSwarm.h
Agent.o: Agent.h Agent.m
BFAgent.o: BFagent.h BFagent.m
Dividend.o: Dividend.h Dividend.m
Output.o: Output.h Output.m
ASMModelSwarm.o: ASMModelSwarm.h ASMModelSwarm.m
Specialist.o: Specialist.h Specialist.m
World.o: World.h World.m
random.o: random.h random.m
ASMModelSwarm.o: ASMModelSwarm.h ASMModelSwarm.m
ASMObserverSwarm.o: ASMObserverSwarm.h ASMObserverSwarm.m
ASMBatchSwarm.o: ASMBatchSwarm.h ASMBatchSwarm.m

