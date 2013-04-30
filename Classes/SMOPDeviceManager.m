//
//  SMOPDeviceManager.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPDeviceManager.h"
#import "SMOPDeviceDetector.h"

@implementation SMOPDeviceManager

@synthesize managerDevices;

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

- (NSArray *)managerDevices {
	NSMutableArray *allDevices = [[NSMutableArray new] autorelease];
	[allDevices addObjectsFromArray:manager.devices];
	NSArray *detectorResults = [SMOPDeviceDetector devicesSupportingIPhoneOS];
	for (NSDictionary *device in detectorResults) {
		NSPredicate *findUDID = [NSPredicate predicateWithFormat:@"udid == %@",[device objectForKey:@"UniqueDeviceID"]];
		NSArray *results = [manager.devices filteredArrayUsingPredicate:findUDID];
		if (results.count == 0) {
			[allDevices addObject:device];
		}
	}
	return allDevices;
}

- (AMDevice *)getDeviceWithIdentifier:(NSString *)identifier {
	NSPredicate *findUDID = [NSPredicate predicateWithFormat:@"udid == %@",identifier];
	NSArray *results = [manager.devices filteredArrayUsingPredicate:findUDID];
	return ((results.count) ? [results objectAtIndex:0] : nil);
}

- (BOOL)watchForConnection {
	return [manager waitForConnection];
}

- (NSArray *)devicesWithOnePassword4:(NSArray *)devices {
	NSMutableArray *deviceList = [[[NSMutableArray alloc] init] autorelease];
	NSArray *devicesCopy = [NSArray arrayWithArray:devices];
	for (id device in devicesCopy) {
		if (![devices isEqualToArray:devicesCopy]) {
			break;
		}
		NSDictionary *deviceInfo = nil, *deviceState = nil;
		if ([device isKindOfClass:[AMDevice class]]) {
			NSPredicate *findOnePassword = [NSPredicate predicateWithFormat:@"bundleid == %@",kOnePasswordBundleId];
			NSArray *results = [((AMDevice *)device).installedApplications filteredArrayUsingPredicate:findOnePassword];
			NSString *lastSyncDate = @"Never";
			if (results.count) {
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
					BOOL syncError = ([fileService fileExistsAtPath:kSMOPDeviceSyncStatePath] ? TRUE : ([[NSFileManager defaultManager] fileExistsAtPath:GetSyncStateFileForDevice([device udid])]? TRUE : FALSE));
					[fileService close];
					deviceState = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:syncError], @"SyncError", [NSNumber numberWithBool:TRUE], @"ConnectState", [NSNumber numberWithBool:FALSE], @"NeedsAppInstall", nil];
				}
				[fileService release];
			} else {
				// not installed
				deviceState = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], @"SyncError", [NSNumber numberWithBool:TRUE], @"ConnectState", [NSNumber numberWithBool:TRUE], @"NeedsAppInstall", nil];
			}
			deviceInfo = [NSDictionary dictionaryWithObjectsAndKeys:[device deviceName], @"DeviceName", [device modelName], @"DeviceClass", lastSyncDate, @"SyncDate", nil];
		} else if ([device isKindOfClass:[NSDictionary class]]) {
			deviceInfo = [NSDictionary dictionaryWithObjectsAndKeys:[device objectForKey:@"ProductName"], @"DeviceName", [device objectForKey:@"productType"], @"DeviceClass", @"Unknown", @"SyncDate", nil];
			deviceState = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:FALSE], @"SyncError", [NSNumber numberWithBool:FALSE], @"ConnectState", [NSNumber numberWithBool:FALSE], @"NeedsAppInstall", nil];
		}
		if (deviceInfo != nil && deviceState != nil) {
			NSDictionary *deviceDict = [NSDictionary dictionaryWithObjectsAndKeys: deviceInfo, @"DeviceInfo", deviceState , @"DeviceState", ([device isKindOfClass:[AMDevice class]] ? [device udid] : [device objectForKey:@"UniqueDeviceID"]), @"DeviceIdentifier", nil];
			[deviceList addObject:deviceDict];
		}
	}
	return [NSArray arrayWithArray:deviceList];
}

#pragma mark -
#pragma mark MobileDeviceAccessListener

- (void)deviceConnected:(AMDevice *)device {
	// post notification to refresh
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kDeviceConnectionEventPosted object:manager.devices userInfo:nil];
	});
}

- (void)deviceDisconnected:(AMDevice *)device {
	// post notification to refresh and cancel any syncs to this device
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:kDeviceConnectionEventPosted object:manager.devices userInfo:nil];
	});
}

@end