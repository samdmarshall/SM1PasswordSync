//
//  SMOPSyncProcess.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPSyncProcess.h"
#import "SMOPFunctions.h"

@implementation SMOPSyncProcess

- (id)init {
	self = [super init];
	if (self) {
		localKeychainPath = (NSString *)OnePasswordKeychainPath();
		mergeKeychainPath = kSMOPApplicationSupportPath;
		localContents = [NSMutableSet new];
		deviceContents = [NSMutableSet new];
	}
	return self;
}

- (void)setSyncDevice:(AMDevice *)syncDevice {
	device = syncDevice;
}

- (void)synchronizePasswords {
	NSMutableSet *sameItems = [NSMutableSet new];
	NSMutableSet *differentItems = [NSMutableSet new];
	
	[sameItems release];
	[differentItems release];
}

- (void)dealloc {
	[localKeychainPath release];
	[mergeKeychainPath release];
	[localContents release];
	[deviceContents release];
	[device release];
	[super dealloc];
}

@end
