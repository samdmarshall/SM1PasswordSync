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
	}
	return self;
}

- (void)setSyncDevice:(AMDevice *)syncDevice {
	[device release];
	device = syncDevice;
}

- (void)dealloc {
	[localKeychainPath release];
	[mergeKeychainPath release];
	[device release];
	[super dealloc];
}

@end
