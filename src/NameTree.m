// The Santa Fe Stockmarket -- Implementation of NameTree
// R.G. Palmer, February 1993.

// An object of this class manages a hierarchical tree of names, such as a
// directory structure or an ancestry tree.  Each name is up to MAXCHARS
// characters long, where MAXCHARS is a compile-time parameter (see header
// file).  Each node in the tree may have one or more "children".  A node
// without children is called a leaf node; other nodes are branch nodes.
// Leaf nodes can also store a non-negative integer value "v".
//
// Initially all nodes are descended from a single root node, but
// automatic pruning may subsequently lead to "orphan" nodes whose parentage
// is no longer known.  The topological structure is thus a set of subtrees,
// one descending from the root node and others descending from orphan
// nodes.  For multiple root nodes, use multiple instances of this class.
//
// Nodes in the tree are referenced by an integer "index".  The index of the
// root node is always 0; other indices are positive.  Memory is allocated
// automatically.  The root node has the null name "", and is always treated
// as a branch node (even if it has no children).
//
// Nodes may also be referenced by paths, such as /abc/def/ghi.  This is
// just like a path in a directory tree; "abc" is a name at the top level
// (a direct child of the root node), "def" is the name of one of abc's
// children, etc.  The path separator '/' may be changed to another
// character.
//
// The tree is pruned automatically so that no path (from root to leaf)
// includes more than "maxdepth" nodes (besides the root).  maxdepth
// is initially MAXDEPTH (see below).  Pruning consists of removing nodes on
// the overlong branches next to the root, creating orphan nodes.  For
// example, if maxdepth were 3, then adding a node with name "jkl" to the
// node with path /abc/def/ghi would remove "abc" and make def an orphan
// node.  The resulting path of the new node would be reported as
// :def/ghi/jkl.  The orphan prefix ':' is used instead of '/' to represent
// a path starting at an orphan node.  The orphan prefix ':' may be
// changed to another character.
//
// Note that this class was written more generically than is needed for
// the stockmarket project.  The stockmarket only uses balanced trees
// in which every leaf is at the same level.

// FUNDAMENTAL METHODS
//
// These include the only methods that change what's in the tree -- the
// methods in all other sections below report on the tree, but don't
// change it.
//
// - init
//	Initializes and creates the root node.
//
// - free
//	Frees the instance and allocated memory.
//
// - (int)addName:(const char *)name value:(int)v parent:(int)par
//	Adds a leaf node with name "name" and value "v" as a child of
//	the node with index "par".  Returns the index of the new node.
//	v must be 0 or positive.  par must correspond to an existing node.
//	If the parent was previously a leaf node it becomes a branch node
//	and discards its previous value.  This may cause branch nodes
//	above par to be removed, creating an orphan.  If the parent was
//	previously a branch node, the new node is appended to its list
//	of children.
//
// - removeNode:(int)idx
//	Removes the node with index "idx", and all its children (if any).
//	If the removed node's parent then has no children, it becomes a
//	leaf node with value 0.  If idx=0 (the root) then all nodes
//	descended from the root (but not from orphans) are removed.
//	If idx<0, then all nodes are removed.
//
// - removeLineage:(int)idx
//	Removes the node with index "idx", and all its children (if any).
//	The removed node's parent is also removed if it then has no
//	children, and so on for the parent's parent, etc.  If idx=0 (the
//	root) then all nodes descended from the root (but not from
//	orphans) are removed.  If idx<0, then all nodes are removed.
//
// - setValueOf:(int)idx to:(int)v
//	Changes the value for node "idx" to "v".  "idx" must be a leaf
//	node, and "v" must be 0 or positive.
//
// - setMaxDepth:(int)depth
//	Sets maxdepth, the maximum number of nodes (besides the root) in
//	any path from root or orphan to leaf.  Initially set by MAXDEPTH.
//	Must be at least 2.  This method may cause pruning if it reduces
//	maxdepth.
//
// - (int)maxDepth
//	Returns the current value of maxdepth.
//
// METHODS RETURNING PROPERTIES OF NODES
//
// - (BOOL)validNode:(int)idx
//	Tests whether "idx" is a valid node.  Note that branch nodes may
//	be removed by pruning, and susequently trying to reference them
//	in any method except validNode: will cause a fatal error.
//
// - (int)valueOf:(int)idx
//	Returns the value v for node "idx", or a negative value if
//	idx is not a leaf node.  The root node returns -1.
//
// - (const char *)nameOf:(int)idx
//	Returns the name for node "idx".  Subsequent calls overwrite
//	the previous value.  The root node returns an empty string "".
//
// - (BOOL)isLeaf:(int)idx;
//	Returns YES if idx is a leaf node, NO for a branch node (or root).
//
// - (int)levelOf:(int)idx
//	Returns the hierarchical level of node "idx".  The root node
//	has level 0, its children have level 1, its grandchildren have
//	level 2, etc.  The level of a node is not altered by pruning.
//
// - (int)depthOf:(int)idx
//	Returns the depth of node "idx".  If idx is descended directly from
//	the root, the depth is the same as the level.  If idx is descended
//	from an orphan, the depth is the number of levels on its path from
//	orphan to idx inclusive.
//
// - (int)parentOf:(int)idx
//	Returns the index of the parent node of node "idx" if available.
//	Returns -L if idx is an orphan node, where L is the level of node
//	idx (so L-1 nodes are missing between node idx and the root).  The root
//	node (idx = 0) returns -1.
//
// - (int)ancestorOf:(int)idx
//	Returns the index of the earliest known ancestor of node "idx",
//	besides root.  This will either be an immediate child of root,
//	or an orphan.  The root node returns root (0).
//
// - (int)rootAncestorOf:(int)idx
//	Returns the index of the earliest known ancestor of node "idx",
//	either root (index 0) or an orphan.  Note that -ancestorOf: and
//	-rootAncestorOf: return the same thing for a node descended for
//	an orphan, but for a node descended directly from root there is
//	a one-level difference.
//
// METHODS RETURNING A LIST OF NODES
//
// The following methods all return a list of indices or values in "buf",
// for those nodes satisfying some criterion.  The return value is the total
// number of nodes satisfying the criterion.  If there are more than "len"
// such nodes, then only the first len are placed in buf.  If there are
// fewer than len eligible nodes, then the remainder of buf is left
// unchanged.  buf may be NULL if only the return value is needed.
//
// - (int)childrenOf:(int)idx buf:(int *)buf len:(int)len
//	Returns the children of node "idx".
//
// - (int)siblingsOf:(int)idx buf:(int *)buf len:(int)len
//	Returns the siblings of node "idx".  The original node "idx" is NOT
//	included among the siblings; if you want a list or count including
//	the original node, you can add it yourself, ask for the parent's
//	children, or use the following method.
//
//	If the node idx is an orphan node, this method returns -L like
//	parentOf:, and leaves the buffer unchanged.  The root node returns 0.
//
// - (int)familyValuesOf:(int)idx buf:(int *)buf len:(int)len
//	This is like siblingsOf:buf:len except that:
//	(a) The value "v" of each sibling is returned instead of the index;
//	(b) The original node "idx" is included with its siblings.
//	(c) Nodes that are not leaf nodes are omitted (and not counted in
//	    the return value).
//
// - (int)leavesOf:(int)idx buf:(int *)buf len:(int)len
//	Returns the leaf nodes that are in the subtree descending
//	from node "idx".  If node idx itself is a leaf, then it alone is
//	returned in buf.  If idx=0 (the root) then all leaves descended
//	from the root (but not from orphans) are listed.  If idx<0, then
//	all leaf nodes are listed.
//
// - (int)leafValuesOf:(int)idx buf:(int *)buf len:(int)len
//	This is just like leavesOf:buf:len except that the value v of each
//	leaf node is returned instead of the index.
//
// - (int)orphans:(int *)buf len:(int)len
//	Returns the orphan nodes.
//
// - (int)ancestors:(int *)buf len:(int)len
//	Returns the nodes that are the immediate children of root or are
//	orphans.
//
// METHODS RELATED TO PATHS
//
// - (char *)pathTo:(int)idx buf:(char *)buf len:(int)len
//	Returns in "buf" (which has length len) the path from the root to
//	the node with index "idx".  Each name is prefixed by the path
//	separator charactor (e.g. '/'), except that the leading prefix is
//	changed to the orphan prefix character (e.g. ':') if the path starts
//	at an orphan.  If len is too small for the full path to fit in the
//	buffer, then a partial path is returned, prefixed by the partial path
//	prefix character (e.g. '-') instead of either of the other two
//	charactors.  All three characters may be changed, and need not be
//	distinct.
//
//	For example, using the default characters, the paths /abc/def/ghi
//	and :pqr/stu/vwx could be returned as:
//
//	len>=13		/abc/def/ghi	:pqr/stu/vwx
//	9<=len<=12	-def/ghi	-stu/vwx
//	5<=len<=8	-ghi		-vwx
//	2<=len<=4	-		-
//
//	len<2 would be cause an error.
//
// - (int)indexForPath:(const char *)path
//	Returns the index of the node specified by "path", or a negative or
//	zero value if no such node exists.  This method allows for the
//	possibility that the specified path has been removed from the
//	tree by pruning, so in fact some initial components of "path" may
//	be missing.  The path may start with the normal path separator,
//	or the orphan prefix, or neither.  There is no provision for paths
//	starting with the partial path prefix.  The search strategy depends
//	on the prefix, based on how a path might have been orphaned.  The
//	following example shows what would be searched for in three cases:
//
//	path:	/abc/def/ghi	:abc/def/ghi	abc/def/ghi
//		------------	------------	-----------
//	1.	/abc/def/ghi	:abc/def/ghi	/abc/def/ghi
//	2.	:def/ghi	:def/ghi	:abc/def/ghi
//	3.	:ghi		:ghi		:def/ghi
//	4.					:ghi
//
//	1, 2, 3, and 4 represent successive attempts to locate a matching
//	node, where the '/' and ':' prefixes implies searching the root
//	tree and the orphans respectively.  If the orphan prefix character
//	is the same as the path separator, then the search is as shown in
//	the last column.  Note that duplicate names in the tree can cause
//	the search to fail; e.g. if an orphan node :def existed without a
//	child ghi, then the search would stop and another orphan :ghi would
//	not be found.  Other than that, this method is the inverse of
//	-pathTo:buf:len:, so
//
//		path = [myTree pathTo:idx buf:buf len:len];
//		....
//		i = [myTree indexForPath];
//
//	should give back i=idx (assuming that len is large enough to hold
//	the full path), even if some pruning took place between the two
//	calls.
//
//	When the method fails (so the last component of "path" was not
//	matched), the value returned is minus the index of the last node
//	matched if a partial match was found, or 0 if nothing matched.
//
// - setPathSeparator:(unsigned short)sep
//	Sets the path separator character to "sep".  Default is '/'.
//
// - setOrphanPrefix:(unsigned short)sep
//	Sets the orphan prefix character to "sep".  Default is ':'.
//
// - setPartialPathPrefix:(unsigned short)sep
//	Sets the partial path prefix character to "sep".  Default is '-'.
//
// METHODS FOR TRAVERSING THE TREE
//
// - (int)next:(int)idx level:(int *)lev
//	Returns the index of the next node after idx in a depth first
//	traversal of the tree.  Parents are visited before their children,
//	all descendants of a node are visited before that node's next
//	sibling, and orphans subtrees are traversed after the root subtree.
//	This is index or section order: 1, 1.1, 1.1.1, 1.1.2, 1.2, 1.2.1, 2,
//	etc.  Returns a negative value when all nodes have been visited.  If
//	lev is non-null and *lev is the level of node idx before the call,
//	then *lev will give the level of the new node after the call (or a
//	negative value when all nodes have been visited).  This method is
//	intended to be used in a loop like:
//	  for (idx=0, lvl=0; idx>=0; idx=[nameTree next:idx level:&lvl]) {
//	      ... do something with node idx, which is level lvl ...
//	  }
//
// - (int)next:(int)idx depth:(int *)dpth
//	Just like next:level: except that the second argument maintains
//	the depth of the nodes rather than the level (see depthOf:).  Start
//	from idx=0, *dpth=0.
//
// METHODS FOR DEBUGGING AND ANALYSIS
//
// - (int)checkIntegrity:(FILE *)fp
//	Checks the internal integrity of the name tree.  If an error is
//	found, then a descriptive message is written to file pointer fp
//	(unless fp is NULL).  Returns a negative error code (see the source)
//	or the the number of nodes in use if there is no error.
//
// - (int)memoryInUse
//	Returns the number of bytes of malloc memory in use for the main
//	"names" array.
//
// - dumpTable:(FILE *)fp
//	For debugging: dumps a table of all variables for all nodes
//	(besides the free list) to file pointer fp.
//
// + setDebugFile:(FILE *)fp
//	Sets the debugging file pointer to fp.  If the debugging file pointer
//	is not NULL, then extended debugging information is sent to fp when
//	an error occurs (e.g. referencing an invalid node).  This information
//	includes the output of -dumpTable: and -checkIntegrity:.  If the
//	debugging file pointer is NULL, as it is initially, then an error
//	produces a brief error message to stderr.  In all cases the program
//	is then terminated with a call to -error.  Note that this is a class
//	method; the usual call is [NameTree setDebugFile:stderr].
//
// INTERNALS
//
// The name tree is organized as a collection of "nameentry" items.  There
// are exactly numnameblocks*NAMEBLOCKSIZE items, indexed by the integer
// "index".  (We don't use pointers because we may need to realloc the whole
// list to increase numnameblocks).  nameentry items fall into four classes:
//
// 1. Free.  Free items are linked into one long list through their "next"
//    index.  The instance variable "freelist" indexes the start of the
//    free list and the last entry has next=0.  The "parent" variable is
//    set to FREEPARENT for all free items; the "children" variable is
//    undefined.
//
// 2. Leaf.  A leaf node has no children; the "children" variable is used
//    instead to store -v (which is thus 0 or negative).  The "parent"
//    variable indexes the leaf's parent, or is -L for orphans.  The "next"
//    variable forms a linked list of siblings, ending with -L for ordinary
//    nodes and 0 for orphan nodes.  Orphan nodes are linked as siblings
//    of the root, in order of increasing level.
//
// 3. Branch.  A branch node has one or more children; the "children"
//    variable indexes the first of the linked list of children.
//    The "parent" and "next" variables are as for leaf nodes.
//
// 4. Root.  The single root node has index 0 and parent = -1.  Its name is
//    the null string.  Its "next" variable points to the start of the
//    linked list of orphans (or is 0 if there are no orphans).  The root
//    node cannot be removed.  It is always treated as a branch node.
//
// All nodes have 1-MAXCHARS character null-terminated names stored in
// "name".  name[MAXCHARS] is always '\0'.  The name is "" for free nodes
// and the root node.
//
// EFFICIENCY/DESIGN NOTES
//
// Storage is allocated for MAXCHARS+1 characters (including '\0') for
// every node.  Storage is most efficient if MAXCHARS+1 is a multiple of 4
// and if all names are about the same length.  To support names of widely
// varying length, it would be best to write a similar class that stores
// pointers to the names instead of the names themselves.
//
// The implementation is fairly efficient, but some methods must perform
// loops to get up to the root (or an orphan), or to get to the end of
// a list of siblings.  So the time taken by a method may be linear either
// in depth or in width (number of siblings) of the node concerned.  For
// that reason this implementation is not suitable for very large trees.
//
// Recursion is sometimes used to go up the tree, so MAXDEPTH should not
// be made too large.
//
// The size of the main array never shrinks unless _all_ nodes are removed,
// so it represents a high-water mark.  This is hard to avoid when indices
// (which are known to users, and must not change) correspond directly
// to addresses.  An indirect scheme is possible, but more costly in terms
// of both time and space.


#import "NameTree.h"
#import <stdlib.h>
#import <string.h>

// Parameters (see also MAXCHARS in the header file).
//
// NAMEBLOCKSIZE sets the initial size of the name tree (in number of nodes
// -- each is 16 + floor(MAXCHARS/4) bytes long).  The size is increased
// in increments of NAMEBLOCKSIZE initially, then in larger multiples of
// this later if necessary.  The sequence of sizes, in multiple of
// NAMEBLOCKSIZE, is 1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20, 24, 32, ...
// -- the increment is doubled when size = 6*increment.
//
// MAXNAMEBLOCKS sets the maximum number of such blocks that may be
// allocated; needing more than this creates a fatal error.  This is
// just to prevent runaway misuse---there's no inherent limitation besides
// the size of the integers used for indices.  Use a power of two.
//
// MAXDEPTH sets the initial value of maxdepth.
//
#define NAMEBLOCKSIZE	64
#define MAXNAMEBLOCKS	1024
#define MAXDEPTH	15

// Internal definitions
#define FREEPARENT	((int)0x80000000)
#define INVALIDNODE(i)	((i) < 0 || (i) >= tablesize || \
					names[(i)].parent == FREEPARENT)

// PRIVATE METHODS
@interface NameTree(Private)
- prune:(int)idx to:(int)levels;
- die:(const char *)name :(const char *)format, ...;
@end

// Local variables for whole class
static FILE *debugfile = NULL;
struct nameentry rootentry = {-1, 0, 0, "\0"};

@implementation NameTree

// ----------------------- FUNDAMENTAL METHODS -----------------------

- init
{
// Initialize variables.  Initially the main name array only has one
// entry, in static storage.  A proper array and freelist are allocated
// to replace this as soon as another entry is added.
    tablesize = 1;
    nnodes = 1;
    numnameblocks = 0;
    blockincrement = 1;
    freelist = 0;
    pathseparator = '/';
    orphanprefix = ':';
    partialpathprefix = '-';
    maxdepth = MAXDEPTH;
    names = &rootentry;	// temporary entry, until memory allocated

    return self;
}


- free
{
    if (tablesize > 1)
	free(names);
    return [super free];
}


- (int)addName:(const char *)name value:(int)v parent:(int)par
/*
 * Adds name/number pair to the name tree, with ancestor "parent".
 * This is the only method that actually adds a node.
 */
{
    int slot, i, j;
    struct nameentry *nlp;

// Check arguments
    if (v < 0)
	[self die:"addName:value:parent:" :"invalid value %d", v];
    if (INVALIDNODE(par))
	[self die:"addName:value:parent:" :"invalid parent %d", par];

// See if there's a free slot already
    if (freelist == 0) {

    // If not, allocate more memory for the main array
	if (numnameblocks == 0) {	// First block -- treat specially
	    names = (struct nameentry *)malloc(
				    sizeof(struct nameentry)*NAMEBLOCKSIZE);
	    if (names == NULL)
		[self die:"addName:value:parent:" :"out of memory"];
	    numnameblocks = 1;
	    tablesize = NAMEBLOCKSIZE;
	    blockincrement = 1;
	    names[0] = rootentry;	// Insert root entry
	    nnodes = 1;
	    freelist = 1;
	}
	else {				// Subsequent blocks -- realloc
	    if (numnameblocks == 6*blockincrement) blockincrement *= 2;
	    freelist = tablesize;
	    numnameblocks += blockincrement;
	    if (numnameblocks > MAXNAMEBLOCKS)
		[self die:"addName:value:parent:" :"name list full"];
	    tablesize = NAMEBLOCKSIZE*numnameblocks;
	    names = (struct nameentry *)realloc((void *)names,
					sizeof(struct nameentry)*tablesize);
	    if (names == NULL)
		[self die:"addName:value:parent:" :"out of memory"];
	}

    // Make new free list from freelist to tablesize-1
	for (i=freelist; i<tablesize; i++) {
	    nlp = names + i;
	    nlp->name[0] = '\0';
	    nlp->name[MAXCHARS] = '\0';
	    nlp->parent = FREEPARENT;
	    nlp->next = i+1;
	}
	names[tablesize-1].next = 0;
    }

// Take new slot from free list
    slot = freelist;
    nlp = names+slot;
    freelist = nlp->next;
    ++nnodes;

// Fill in fields
    strncpy(nlp->name,name,MAXCHARS);
    nlp->parent = par;
    nlp->children = -v;

// Fix links from parent and siblings
    if ((i = names[par].children) <= 0) {	/* parent was a leaf or root */
	i = names[par].parent;
	if (i < 0)
	    nlp->next = (i == -1? -1: i-1);   /* new child of root or orphan */
	else {
	    for (i=par; i>0; i = names[i].next) ;	/* get level */
	    nlp->next = 0;
	    if (-i >= maxdepth)
		[self prune:par to:maxdepth-1];	/* prune parent path */
	    nlp->next = i-1;			/* next level down */
	}
	names[par].children = slot;
    }
    else {					/* parent had children */
	while ((j = names[i].next) > 0) i = j;
	names[i].next = slot;			/* append to child list */
	nlp->next = j;
    }

    return slot;
}


- removeNode:(int)idx
/*
 * Removes a node from the name tree.  If this leaves the parent
 * without children, the parent beomes a leaf node with value 0.
 * idx = 0 removes all the root's descendents.  idx < 0 removes
 * everything.
 * Note: this is the only method that actually removes a node;
 * even pruning uses this.
 */
{
    int i, j;

// Check for valid node, or negative to remove all
    if (idx >= tablesize || (idx > 0 && names[idx].parent == FREEPARENT))
	[self die:"removeNode:" :"invalid index %d", idx];

// First remove any children, recursively
    if (idx < 0) {
	i = 0;
	j = 1;
    }
    else
	i = j = names[idx].children;
    for (; j>0; i=j) {
	j = names[i].next;	// save before i is destroyed!
	[self removeNode:i];
    }

// Adjust list of siblings to which this node belongs.
    if (idx > 0) {
	int parent;	// Here to save stack space in the above recursion

	parent = names[idx].parent;
	i = (parent < 0? 0: names[parent].children);	// first of idx's chain
	if (i == idx) {					// first born
	    if ((i = names[idx].next) > 0)
		names[parent].children = i;		// has younger siblings
	    else
		names[parent].children = 0;		// only child
	}
	else {						// has older siblings
	    while ((j = names[i].next) != idx && j > 0) i = j;
	    if (j <= 0)
		[self die:"removeNode:" :"parent %d disowns child %d",
							    parent, idx];
	    names[i].next = names[idx].next;
	}

// Return node to the free list
	names[idx].parent = FREEPARENT;
	names[idx].next = freelist;
	names[idx].name[0] = '\0';
	freelist = idx;
	--nnodes;
    }

// Free memory if tree is now empty (besides root node)
    if (tablesize > 1 && nnodes == 1) {
	tablesize = 1;
	numnameblocks = 0;
	blockincrement = 1;
	freelist = 0;
	names = &rootentry;
    }

    return self;
}


- removeLineage:(int)idx
/*
 * Removes a leaf node from the name tree.  If this leaves the parent
 * without children, then the parent is removed too, and so on.
 */
{
    int parent, i;

// Record our parent's index
    parent = (idx > 0? names[idx].parent: -1);

// Remove the node itself (and any children)
    [self removeNode:idx];

// If our parent now has no children, remove it too, etc
    for (i = parent; i > 0 && names[i].children == 0; i = parent) {
	parent = names[i].parent;
	[self removeNode:i];
    }

    return self;
}


- setValueOf:(int)idx to:(int)v
{
// Check arguments
    if (v < 0)
	[self die:"setValueOf:to:" :"invalid value %d", v];
    if (INVALIDNODE(idx))
	[self die:"setValueOf:to:" :"invalid index %d", idx];
    if (idx == 0 || names[idx].children > 0)
	[self die:"setValueOf:to:" :"index %d is not a leaf node", idx];

// Set it
    names[idx].children = -v;
    return self;
}


- setMaxDepth:(int)maxd
/*
 * Sets the maximum number of elements in a path.  If this is reduced
 * we must prune the whole tree.
 */
{
    int i, depth;

    if (maxd < 2)
	[self die:"setMaxDepth:" :"invalid maxdepth %d", maxd];

    if (maxd >= maxdepth) {
	maxdepth = maxd;
	return self;
    }
    maxdepth = maxd;

    do {
	for (i=0, depth=0; i>=0; i = [self next:i depth:&depth]) {
	    if (depth > maxdepth) {
		[self prune:i to:maxdepth];
		break;	/* start over after pruning (slow but rare) */
	    }
	}
    } while (i>=0);

    return self;
}


- (int)maxDepth
{
    return maxdepth;
}


// ------------- METHODS RETURNING PROPERTIES OF NODES --------------

- (BOOL)validNode:(int)idx
{
    return !(INVALIDNODE(idx));
}


- (int)valueOf:(int)idx
{
    if (INVALIDNODE(idx))
	[self die:"valueOf:" :"invalid index %d", idx];
    if (idx == 0)
	return -1;
    else
	return -names[idx].children;
}


- (const char *)nameOf:(int)idx
{
    static char name[MAXCHARS+1];

    if (INVALIDNODE(idx))
	[self die:"nameOf:" :"invalid index %d", idx];
    strncpy(name, names[idx].name, MAXCHARS+1);
    return name;
}


- (BOOL)isLeaf:(int)idx
{
    if (INVALIDNODE(idx))
	[self die:"isLeaf:" :"invalid index %d", idx];
    return (names[idx].children <= 0 && idx != 0);
}


- (int)levelOf:(int)idx
{
    int i;

    if (INVALIDNODE(idx))
	[self die:"levelOf:" :"invalid index %d", idx];
    if ((i = names[idx].parent) < 0)
	return (i == -1? 0: -i);
    for (i=names[idx].next; i>0; i = names[i].next) ;
    return -i;
}


- (int)depthOf:(int)idx
{
    int d;

    if (INVALIDNODE(idx))
	[self die:"depthOf:" :"invalid index %d", idx];
    for (d=0; idx>0; idx=names[idx].parent, d++) ;
    return d;
}


- (int)parentOf:(int)idx
{
    if (INVALIDNODE(idx))
	[self die:"parentOf:" :"invalid index %d",idx];
    return names[idx].parent;
}


- (int)ancestorOf:(int)idx
{
    int i, ancestor;

    if (INVALIDNODE(idx))
	[self die:"ancestorOf:" :"invalid index %d", idx];
    ancestor = idx;
    while ((i = names[ancestor].parent) > 0)
	ancestor = i;
    return ancestor;
}


- (int)rootAncestorOf:(int)idx
{
    int i, ancestor;

    if (INVALIDNODE(idx))
	[self die:"rootAncestorOf:" :"invalid index %d", idx];
    ancestor = idx;
    while ((i = names[ancestor].parent) >= 0)
	ancestor = i;
    return ancestor;
}


// --------------- METHODS RETURNING A LIST OF NODES -----------------

- (int)childrenOf:(int)idx buf:(int *)buf len:(int)len
/*
 * Returns the number of children of idx, and lists them in buf.
 */
{
    int i, n;

    if (INVALIDNODE(idx))
	[self die:"childrenOf:buf:len:" :"invalid index %d", idx];

    if (buf == NULL) len = 0;
    for (i=names[idx].children, n=0; i>0; i=names[i].next) {
	if (len > n) buf[n] = i;
	++n;
    }
    return n;
}


- (int)siblingsOf:(int)idx buf:(int *)buf len:(int)len
/*
 * Returns the number of siblings of idx, and lists them in buf.
 */
{
    int i, n, par;

    if (INVALIDNODE(idx))
	[self die:"siblingsOf:buf:len:" :"invalid index %d", idx];
    if (idx == 0) return 0;				/* root */
    if ((par = names[idx].parent) < 0) return par;	/* orphan node */
    if (buf == NULL) len = 0;

    for (i=names[par].children, n=0; i>0; i=names[i].next)
	if (i != idx) {
	    if (len > n) buf[n] = i;
	    ++n;
	}
    return n;
}


- (int)familyValuesOf:(int)idx buf:(int *)buf len:(int)len
/*
 * Returns the number of leaf-node siblings of idx (including idx itself),
 * and lists their values in buf.
 */
{
    int i, n, par, v;

    if (INVALIDNODE(idx))
	[self die:"familyValuesOf:buf:len:" :"invalid index %d", idx];
    if (idx == 0) return 0;				/* root */
    if (buf == NULL) len = 0;

    if ((par = names[idx].parent) < 0) {		/* orphan node */
	if ((v = names[idx].children) <= 0) {
	    if (len > 0) buf[0] = -v;
	    return 1;
	}
	return 0;
    }

    for (i=names[par].children, n=0; i>0; i=names[i].next)
	if ((v = names[i].children) <= 0) {
	    if (len > n) buf[n] = -v;
	    ++n;
	}
    return n;
}


- (int)leavesOf:(int)idx buf:(int *)buf len:(int)len
{
    int i, level, initiallevel, n;

    if (buf == NULL) len = 0;

// Special case: idx<0 => list all leaves
    if (idx < 0) {
	i = [self next:0 level:NULL];	/* skip root */
	for(n=0; i>0; i=[self next:i level:NULL]) {
	    if (names[i].children <= 0) {
		if (len > n) buf[n] = i;
		++n;
	    }
	}
	return n;
    }

    if (INVALIDNODE(idx))
	[self die:"leavesOf:buf:len:" :"invalid index %d", idx];

// Special case: idx is itself a leaf node
    if ((i=names[idx].children) <= 0) {
	if (idx == 0)
	    return 0;
	else {
	    if (len > 0) buf[0] = idx;
	    return 1;
	}
    }

// General case: traverse tree while level < idx's level
    initiallevel = [self levelOf:idx];
    for (level=initiallevel+1, n=0; level>initiallevel;
				    i=[self next:i level:&level]) {
	if (names[i].parent < 0) break;
	if (names[i].children <= 0) {
	    if (len > n) buf[n] = i;
	    ++n;
	}
    }
    return n;
}


- (int)leafValuesOf:(int)idx buf:(int *)buf len:(int)len
{
    int i, level, initiallevel, n, v;

    if (buf == NULL) len = 0;

// Special case: idx<0 => list all leaves
    if (idx < 0) {
	i = [self next:0 level:NULL];	/* skip root */
	for(n=0; i>0; i=[self next:i level:NULL]) {
	    if ((v = names[i].children) <= 0) {
		if (len > n) buf[n] = -v;
		++n;
	    }
	}
	return n;
    }

    if (INVALIDNODE(idx))
	[self die:"leavesOf:buf:len:" :"invalid index %d", idx];

// Special case: idx is itself a leaf node
    if ((i=names[idx].children) <= 0) {
	if (idx == 0)
	    return 0;
	else {
	    if (len > 0) buf[0] = -i;
	    return 1;
	}
    }

// General case: traverse tree while level < idx's level
    initiallevel = [self levelOf:idx];
    for (level=initiallevel+1, n=0; level>initiallevel;
				    i=[self next:i level:&level]) {
	if (names[i].parent < 0) break;
	if ((v = names[i].children) <= 0) {
	    if (len > n) buf[n] = -v;
	    ++n;
	}
    }
    return n;
}


- (int)orphans:(int *)buf len:(int)len
{
    int i, n;

    if (buf == NULL) len = 0;
    for (i=names[0].next, n=0; i>0; i=names[i].next) {
	if (len > n) buf[n] = i;
	++n;
    }
    return n;
}


- (int)ancestors:(int *)buf len:(int)len
{
    int i, n;

    if (buf == NULL) len = 0;

// List root's children
    for (i=names[0].children, n=0; i>0; i=names[i].next) {
	if (len > n) buf[n] = i;
	++n;
    }

// And add in the orphans
    for (i=names[0].next; i>0; i=names[i].next) {
	if (len > n) buf[n] = i;
	++n;
    }
    return n;
}


// --------------------- METHODS RELATED TO PATHS ---------------------

- (char *)pathTo:(int)idx buf:(char *)buf len:(int)len
/*
 * Returns the path from the root to the node "idx", provided there's
 * room in "buf".  If "len" is too small a shortened name is returned.
 * The first character of the path is changed to orphanprefix or
 * partialpathprefix if (respectively) the path starts at an orphan or
 * has been shortened.
 */
{
    char *ptr, *optr;
    int l;

    if (INVALIDNODE(idx))
	[self die:"pathTo:buf:len:" :"invalid index %d", idx];
    if (len < 2)
	[self die:"pathTo:buf:len:" :"buffer size %d too small", len];

// Enter names into buf from right to left
    ptr = buf+len-1;
    *ptr = '\0';
    for (; idx>0; idx=names[idx].parent) {
	 l = strlen(names[idx].name);
	 if (ptr <= buf+l) break;
	 ptr -= l+1;
	*ptr = pathseparator;
	strncpy(ptr+1, names[idx].name, l);
    }
    if (*ptr == '\0') *--ptr = pathseparator;
    if (idx > 0) *ptr = partialpathprefix;
    else if (idx < 0) *ptr = orphanprefix;


// Done if it exactly fitted
    if (ptr == buf)
	return buf;

// Shift buffer down
    for (optr=buf; *ptr!='\0'; ptr++)
	*optr++ = *ptr;
    *optr = '\0';

    return buf;
}


- (int)indexForPath:(const char *)path
{
    char component[MAXCHARS+1];
    const char *ptr;
    char *optr;
    int idx, matches, oldidx;
    BOOL secondchance;

// Set starting point (root tree or orphans), and secondchance if we should
// try the orphans after the root tree without intermediate decapitation
    if (*path == pathseparator) {
	idx = names[0].children;
	secondchance = (pathseparator == orphanprefix);
	++path;
    }
    else if (*path == orphanprefix) {
	idx = names[0].next;
	secondchance = NO;
	++path;
    }
    else {
	idx = names[0].children;
	secondchance = YES;
    }

    if (*path == '\0')
	return 0;

// Search the tree(s)
    matches = 0;
    oldidx = 0;
    ptr = path;
    for (;;) {
	for (optr=component; optr < component+MAXCHARS &&
				    *ptr != pathseparator && *ptr != '\0'; )
	    *optr++ = *ptr++;
	*optr = '\0';
	for (; idx > 0; idx = names[idx].next)
	    if (strncmp(component, names[idx].name, MAXCHARS) == 0) break;
	if (idx <= 0) {
	    if (matches > 0)
		return -oldidx;		// Partial match exit
	    if (secondchance)
		secondchance = NO;
	    else {
	    // Decapitate the path we're looking for
		while (*path != '\0' && *path++ != pathseparator) ;
		if (*path == '\0')
		    return 0;		// No match exit
	    }
	    ptr = path;
	    idx = names[0].next;
	    oldidx = 0;
	    continue;
	}
	if (*ptr == '\0')
	    return idx;			// Successful exit
	++matches;
	oldidx = idx;
	idx = names[idx].children;
	++ptr;
    }
    /* not reached */
}


- setPathSeparator:(unsigned short)sep
/*
 * Sets the path separator.  We use unsigned short for consistency
 * with NXBrowser, etc., but convert to int internally.
 */
{
    if (sep == 0 || sep >= 256)
	[self die:"setPathSeparator:" :"invalid character %u", sep];
    pathseparator = (int)sep;
    return self;
}


- setOrphanPrefix:(unsigned short)sep
/*
 * Sets the orphan prefix character, which is used initially instead of
 * the usual path separator if a path starts at an orphan.
 */
{
    if (sep == 0 || sep >= 256)
	[self die:"setOrphanPrefix:" :"invalid character %u", sep];
    orphanprefix = (int)sep;
    return self;
}


- setPartialPathPrefix:(unsigned short)sep;
/*
 * Sets the partial path prefix character, which is used initially instead of
 * the usual path separator if a path is incomplete.
 */
{
    if (sep == 0 || sep >= 256)
	[self die:"setPartialPathPrefix:" :"invalid character %u", sep];
    partialpathprefix = (int)sep;
    return self;
}


// ---------------- METHODS FOR TRAVERSING THE TREE -----------------

- (int)next:(int)idx level:(int *)lvl
{
    int j, pj;

    if (INVALIDNODE(idx))
	[self die:"next:level:" :"invalid index %d", idx];
    if ((j = names[idx].children) > 0) {		/* down */
	if (lvl!=NULL) ++(*lvl);
	return j;
    }

    for (;;) {
	if ((j = names[idx].next) > 0) {		/* sideways */
	    if (lvl!=NULL && (pj = names[j].parent) < -1)	/* orphan */
		*lvl = -pj;
	    return j;
	}
	else {						/* end of chain */
	    if ((j = names[idx].parent) >= 0) {		/* up */
		if (lvl!=NULL) --(*lvl);
		idx = j;
	    }
	    else {
		if (lvl!=NULL) *lvl = -1;
		return -1;				/* all done */
	    }
	}
    }
}


- (int)next:(int)idx depth:(int *)dpth
{
    int j;

    if (INVALIDNODE(idx))
	[self die:"next:depth:" :"invalid index %d", idx];
    if ((j = names[idx].children) > 0) {		/* down */
	if (dpth!=NULL) ++(*dpth);
	return j;
    }

    for (;;) {
	if ((j = names[idx].next) > 0)			/* sideways */
	    return j;
	else {						/* end of chain */
	    if ((j = names[idx].parent) >= 0) {		/* up */
		if (j!=0 &&dpth!=NULL) --(*dpth);
		idx = j;
	    }
	    else {
		if (dpth!=NULL) *dpth = -1;
		return -1;				/* all done */
	    }
	}
    }
}


// --------------- METHODS FOR DEBUGGING AND ANALYSIS ---------------

- (int)checkIntegrity:(FILE *)fp
/*
 * Checks the name tree for consistency, writes message to fp if error.
 * Returns number of nodes in use, or negative error code.
 */
{
    char *msg;
    int i = -999;
    int j = -9999;
    int level = -99999;
    int pj = -999999;
    int count = tablesize;
    int pi, err;
    BOOL firstvisit = YES;

// Check free list
    for (i=freelist; i>0 && count>0; i=names[i].next, count--) {
	if (names[i].parent != FREEPARENT)
	    { msg="bad freelist parent"; err=-1; goto bad;}
	if (names[i].name[0] != '\0')
	    { msg="bad freelist name"; err=-2; goto bad;}
    }
    if (count == 0)
	{ msg="freelist too large (loop?)"; err=-3; goto bad;}
    if (i != 0)
	{ msg="bad freelist next"; err=-4; goto bad;}
    if (count != nnodes)
	{ msg="bad node count"; err=-5; goto bad;}

// Check main tree
    j = 0;
    level = 0;
    while (count--) {
	i = j;
	if (firstvisit && (j = names[i].children) > 0) {	/* down */
	    ++level;
	    pj = names[j].parent;
	    if (pj != i)
		{ msg="wrong parent of firstborn"; err=-6; goto bad;}
	}
	else if ((j = names[i].next) > 0) {			/* sideways */
	    pi = names[i].parent;
	    pj = names[j].parent;
	    if (pj < -1) {	/* orphan */
		if (pi > 0)
		    { msg="misplaced orphan"; err=-7; goto bad;}
		if (-pj < level)
		    { msg="orphan out of order"; err=-8; goto bad;}
		level = -pj;
	    }
	    else if (pj != pi)
		{ msg="siblings have different parents"; err=-9; goto bad;}
	    firstvisit = YES;
	}
	else {							/* up */
	    if (j == 0) {
		if (count != 0)
		    { msg="missing nodes"; err=-10; goto bad;}
		else
		    return nnodes;	/* normal exit */
	    }
	    if (j != -level)
		{ msg="level mismatch"; err=-11; goto bad;}
	    if ((j = names[i].parent) >= 0) {
		firstvisit = NO;
		--level;
		++count;
	    }
	}
    }
    msg = "tree too large (loop?)"; err=-12;

bad:
    if (fp)
	fprintf(fp, "Name tree inconsistency: %s\n"
	    "  i=%d, j=%d, pj=%d, count=%d, level=%d, nnodes=%d\n",
	    msg, i, j, pj, count, level, nnodes);
    return err;
}


- (int)memoryInUse
{
    return (sizeof(struct nameentry)*NAMEBLOCKSIZE*numnameblocks);
}


- dumpTable:(FILE *)fp
{
    int i;

    if (fp != NULL) {
	fprintf(fp,"node\tparent\tchldrn\tnext\tname\n");
	for (i=0; i<tablesize; i++)
	    if (names[i].parent != FREEPARENT)
		fprintf(fp,"%d\t%d\t%d\t%d\t%s\n",
		    i, names[i].parent, names[i].children,
		    names[i].next, names[i].name);
	fflush(fp);
    }
    return self;
}


+ setDebugFile:(FILE *)fp
{
    debugfile = fp;	// May be NULL to turn off debugging
    return self;
}


// ------------------------- INTERNAL METHODS -------------------------

- prune:(int)idx to:(int)depth
/*
 * Prunes (if necessary) the path from the root to node "idx" to be
 * no longer than "depth" nodes long (excluding root, including idx).  Node
 * idx itself is never destroyed.
 */
{
    int ancestor, child, i, j, level, firstchild;
    int lastchild = 0;
    int d = 1;

    if (INVALIDNODE(idx))
	[self die:"prune:to:" :"invalid index %d", idx];

// Travel up to ancestor (one below root, or orphan) of specified node.
    ancestor = idx;
    while ((i = names[ancestor].parent) > 0) {
	ancestor = i;
	++d;
    }
    if (ancestor == idx)
	[self die:"prune:to:" :"attempt to prune self: %s (%d)",
						    names[idx].name, idx];

    if (d > depth) {
    // Get first child, compute child's level
	firstchild = names[ancestor].children;
	if (firstchild <= 0)
	    [self die:"prune:to:" :"no children of ancestor %d",
								ancestor];
	level = -names[ancestor].parent;
	if (level == 0) level = 1;
	++level;

    // Orphan each child of ancestor
	for (child=firstchild; child>0; child=names[child].next) {
	    lastchild = child;
	    names[child].parent = -level;		/* make orphan */
	}

    // Remove ancestor
	names[ancestor].children = 0;
	[self removeNode:ancestor];

    // Link children into list of orphans
	i = 0;
	while ((j=names[i].next) > 0 && level >= -names[j].parent) i = j;
	names[lastchild].next = j;
	names[i].next = firstchild;
    }

    if (d-depth > 1)
	[self prune:idx to:depth];	/* recursive call if still too many */

    return self;
}


- die:(const char *)name :(const char *)format, ...
{
    va_list args;
    int nodes;
    FILE *fp;

    fp = (debugfile? debugfile: stderr);
    fprintf(fp,"Fatal error in [NameTree %s]: ", name);

    va_start(args, format);
    vfprintf(fp, format, args);
    va_end(args);
    putc('\n', fp);

    if (debugfile) {
	[self dumpTable:fp];
	nodes = [self checkIntegrity:fp];
	if (nodes >= 0)
	    fprintf(fp, "Integrity check OK -- %d nodes in use\n", nodes);
	[self error:"Fatal error in [NameTree %s], debugging complete", name];
    }
    else
	[self error:"Fatal error in [NameTree %s]", name];

    return self; 		/* not reached */
}

@end
