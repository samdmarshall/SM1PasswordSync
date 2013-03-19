//
//  SMOPContentsItem.m
//  SM1Password Sync
//
//  Created by sam on 3/19/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPContentsItem.h"


@implementation SMOPContentsItem

@synthesize uniqueId;
@synthesize folder;
@synthesize name;
@synthesize location;
@synthesize modifiedDate;
@synthesize unknownString;
@synthesize unknownNumber;
@synthesize trashed;

- (id)initWithArray:(NSArray *)data {
	self = [super init];
	if (self) {
		uniqueId = [data objectAtIndex:0];
		folder = [data objectAtIndex:1];
		name = [data objectAtIndex:2];
		location = [data objectAtIndex:3];
		modifiedDate = [data objectAtIndex:4];
		unknownString = [data objectAtIndex:5];
		unknownNumber = [data objectAtIndex:6];
		trashed = [data objectAtIndex:7];
	}
	return self;
}
- (void)dealloc {
	[uniqueId release];
	[folder release];
	[name release];
	[location release];
	[modifiedDate release];
	[unknownString release];
	[unknownNumber release];
	[trashed release];
	[super dealloc];
}

@end
