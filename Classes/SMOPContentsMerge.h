/*
 *  SMOPContentsMerge.h
 *  SM1Password Sync
 *
 *  Created by sam on 3/19/13.
 *  Copyright 2013 Sam Marshall. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>

CFSetRef ContentsUnionSet(CFSetRef recieverSet, CFSetRef otherSet);
CFSetRef ContentsIntersectSet(CFSetRef recieverSet, CFSetRef otherSet);
CFSetRef ContentsMinusSet(CFSetRef recieverSet, CFSetRef otherSet);
CFSetRef ContentsSetSet(CFSetRef recieverSet, CFSetRef otherSet);