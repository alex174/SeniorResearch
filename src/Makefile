# Makefile for gcc ObjC version ("batch" part only)

BATCH_PRODUCT = market

CC = gcc
CFLAGS = -Wall -Wno-import -D__USE_FIXED_PROTOTYPES__
LIBS = -lobjc -lm

default: $(BATCH_PRODUCT)

.SUFFIXES: .m

# Compilation rules:
.m.o:
	$(CC) $(CFLAGS) -c $< 

version.m: ALWAYS
	@../newversion

ALWAYS:

BATCH_MAIN = marketmain.o
BATCH_OFILES = Agent.o AgentManager.o BFagent.o BSagent.o Dividend.o \
          DUagent.o Forecaster.o LIagent.o NameTree.o Output.o \
	  Scheduler.o Specialist.o World.o control.o error.o \
          random.o util.o version.o
$(BATCH_MAIN): global.h control.h error.h

$(BATCH_PRODUCT): $(BATCH_MAIN) $(BATCH_OFILES)
	$(CC) $(CFLAGS) -ObjC $(LDFLAGS) $(OTHER_LDFLAGS) -o $(BATCH_PRODUCT) \
	$(BATCH_OFILES) $(BATCH_MAIN) $(OTHER_LIBS) $(LIBS)

clean:
	rm -f *.o core *~ $(BATCH_PRODUCT) gmon.out
