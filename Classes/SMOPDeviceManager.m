//
//  SMOPDeviceManager.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPDeviceManager.h"
#import "SMOPDefines.h"

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

- (NSArray *)devicesWithOnePassword4:(NSArray *)devices {
	NSMutableArray *deviceList = [[[NSMutableArray alloc] init] autorelease];
	for (AMDevice *device in devices) {
		NSPredicate *findOnePassword = [NSPredicate predicateWithFormat:@"bundleid == %@",kOnePasswordBundleId];
		NSArray *results = [device.installedApplications filteredArrayUsingPredicate:findOnePassword];
		if (results.count) {
			NSString *lastSyncDate = @"Never";
			AFCApplicationDirectory *fileService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
			if (fileService) {
				BOOL hasPasswordDatabase = [fileService fileExistsAtPath:kOnePasswordRemotePath];
				if (hasPasswordDatabase) {
					NSDictionary *fileInfo = [fileService getFileInfo:kOnePasswordRemotePath];
					NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
					[dateFormatter setDateFormat:@"MMM dd, yyyy HH:mm"];
					[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
					[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
					[dateFormatter setLocale:[NSLocale currentLocale]];
					[dateFormatter setDoesRelativeDateFormatting:YES];
					lastSyncDate = [dateFormatter stringFromDate:[fileInfo objectForKey:@"st_mtime"]];
					[dateFormatter release];
				}
				[fileService close];
				NSDictionary *deviceDict = [NSDictionary dictionaryWithObjectsAndKeys:[device deviceName], @"DeviceName", [device modelName], @"DeviceClass", lastSyncDate, @"SyncDate", nil];
				[deviceList addObject:deviceDict];
			} else {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"kAFCFailedToConnectError" object:self userInfo:nil];
			}
			[fileService release];
		}
	}
	return [NSArray arrayWithArray:deviceList];
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
