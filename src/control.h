// The Santa Fe Stock Market -- Interface for top-level control routines
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _control_h
#define _control_h

extern void setEnvironment(int argc, char *argv[], const char *filename);
extern void startup(void);
extern void warmup(void);
extern void period(void);
extern void performEvents(void);
extern void finished(void);
extern void closeall(void);
extern void marketDebug(void);

#endif /* _control_h */
