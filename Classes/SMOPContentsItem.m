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
		uniqueId = [[data objectAtIndex:0] retain];
		folder = [[data objectAtIndex:1] retain];
		name = [[data objectAtIndex:2] retain];
		location = [[data objectAtIndex:3] retain];
		modifiedDate = [[data objectAtIndex:4] retain];
		unknownString = [[data objectAtIndex:5] retain];
		unknownNumber = [[data objectAtIndex:6] retain];
		trashed = [[data objectAtIndex:7] retain];
	}
	return self;
}

- (NSArray *)returnAsArray {
	return [NSArray arrayWithObjects:uniqueId, folder, name, location, modifiedDate, unknownString, unknownNumber, trashed, nil];
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
