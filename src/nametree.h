// The Santa Fe Stock Market -- Interface for NameTree class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

#ifndef _NameTree_h
#define _NameTree_h

#include <stdarg.h>      // Must precede stdio.h in gcc
#include <stdio.h>
#include <objc/Object.h>

@interface NameTree : Object
{
    struct nameentry *names;	// Dynamically allocated array names[]
    int freelist;
    int numnameblocks;
    int tablesize;
    int blockincrement;
    int nnodes;
    int maxdepth;
    int pathseparator;
    int orphanprefix;
    int partialpathprefix;
}

// FUNDAMENTAL METHODS
- init;
- free;
- (int)addName:(const char *)name value:(int)v parent:(int)par;
- removeNode:(int)idx;
- removeLineage:(int)idx;
- setValueOf:(int)idx to:(int)v;
- setMaxDepth:(int)maxd;
- (int)maxDepth;

// METHODS RETURNING PROPERTIES OF NODES
- (BOOL)validNode:(int)idx;
- (int)valueOf:(int)idx;
- (const char *)nameOf:(int)idx;
- (BOOL)isLeaf:(int)idx;
- (int)levelOf:(int)idx;
- (int)depthOf:(int)idx;
- (int)parentOf:(int)idx;
- (int)ancestorOf:(int)idx;
- (int)rootAncestorOf:(int)idx;

// METHODS RETURNING A LIST OF NODES
- (int)childrenOf:(int)idx buf:(int *)buf len:(int)len;
- (int)siblingsOf:(int)idx buf:(int *)buf len:(int)len;
- (int)familyValuesOf:(int)idx buf:(int *)buf len:(int)len;
- (int)leavesOf:(int)idx buf:(int *)buf len:(int)len;
- (int)leafValuesOf:(int)idx buf:(int *)buf len:(int)len;
- (int)orphans:(int *)buf len:(int)len;
- (int)ancestors:(int *)buf len:(int)len;

// METHODS RELATED TO PATHS
- (char *)pathTo:(int)idx buf:(char *)buf len:(int)len;
- (int)indexForPath:(const char *)path;
- setPathSeparator:(unsigned short)sep;
- setOrphanPrefix:(unsigned short)sep;
- setPartialPathPrefix:(unsigned short)sep;

// METHODS FOR TRAVERSING THE TREE
- (int)next:(int)idx level:(int *)lvl;
- (int)next:(int)idx depth:(int *)dpth;

// METHODS FOR DEBUGGING AND ANALYSIS
- (int)checkIntegrity:(FILE *)fp;
- (int)memoryInUse;
+ setDebugFile:(FILE *)fp;
- dumpTable:(FILE *)fp;

@end

#endif /* _NameTree_h */
