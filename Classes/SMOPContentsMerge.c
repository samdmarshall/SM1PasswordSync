/*
 *  SMOPContentsMerge.c
 *  SM1Password Sync
 *
 *  Created by sam on 3/19/13.
 *  Copyright 2013 Sam Marshall. All rights reserved.
 *
 */

#include "SMOPContentsMerge.h"


CFSetRef ContentsUnionSet(CFSetRef recieverSet, CFSetRef otherSet) {
	return recieverSet;
}

CFSetRef ContentsIntersectSet(CFSetRef recieverSet, CFSetRef otherSet) {
	CFMutableSetRef intersectSet = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
	
	return intersectSet;
}

CFSetRef ContentsMinusSet(CFSetRef recieverSet, CFSetRef otherSet) {
	return recieverSet;
}

CFSetRef ContentsSetSet(CFSetRef recieverSet, CFSetRef otherSet) {
	return otherSet;
}