//
//  SMOPDeviceManager.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPDeviceManager.h"


@implementation SMOPDeviceManager

- (id)init {
	self = [super init];
	if (self) {
		manager = [MobileDeviceAccess singleton];
		[manager setListener:self];
	}
	return self;
}

- (void)dealloc {
	[manager release];
	[super dealloc];
}

- (NSArray *)getDevices {
	return [manager devices];
}

- (BOOL)watchForConnection {
	return [manager waitForConnection];
}

#pragma mark -
#pragma mark MobileDeviceAccessListener

- (void)deviceConnected:(AMDevice *)device {
	// post notification to refresh
}

- (void)deviceDisconnected:(AMDevice *)device {
	// post notification to refresh and cancel any syncs to this device
}

@end
