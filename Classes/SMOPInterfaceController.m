//
//  SMOPInterfaceController.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPInterfaceController.h"
#import "SMOPDefines.h"
#import "SMOPSyncProcess.h"

@implementation SMOPInterfaceController

- (void)awakeFromNib {
	hadError = FALSE;
	isUpdating = FALSE;
	deviceList = [NSMutableArray new];
	deviceAccess = [[SMOPDeviceManager alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(errorWithAFC:) name:@"kAFCFailedToConnectError" object:nil];
	
	if ([deviceAccess watchForConnection]) {
		[self refreshListWithData:[deviceAccess getDevices]];
	}
}

- (void)errorWithAFC:(NSNotification *)notification {
	if (!hadError)
		hadError = TRUE;
}

- (id)init {
	self = [super init];
	if (self) {
		if (!deviceList) {
			deviceList = [NSMutableArray new];
		}
		hadError = FALSE;
		isUpdating = FALSE;
		[self refreshListWithData:[deviceAccess getDevices]];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[deviceList release];
	[deviceAccess release];
	[super dealloc];
}

- (void)refreshListWithData:(NSArray *)devices {
	if (!isUpdating) {
		isUpdating = TRUE;
		hadError = FALSE;
		[deviceList removeAllObjects];
		for (AMDevice *device in devices) {
			NSPredicate *findOnePassword = [NSPredicate predicateWithFormat:@"bundleid == %@",kOnePasswordBundleId];
			NSArray *results = [device.installedApplications filteredArrayUsingPredicate:findOnePassword];
			if (results.count) {
				NSString *lastSyncDate = @"Never";
				AFCApplicationDirectory *fileService = [device newAFCApplicationDirectory:kOnePasswordBundleId];
				if (fileService && !hadError) {
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
		[deviceTable reloadData];
		isUpdating = FALSE;
	}
}

- (void)performSync {
	SMOPSyncProcess *newSync = [[SMOPSyncProcess alloc] init];
	[newSync setSyncDevice:[[deviceAccess getDevices] objectAtIndex:[deviceTable selectedRow]]];
	[newSync synchronizePasswords];
}

- (IBAction)syncData:(id)sender {
	if (!isUpdating) {
		[syncButton setEnabled:NO];
		[refreshButton setEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self refreshListWithData:[deviceAccess getDevices]];
			[syncButton setEnabled:YES];
			[refreshButton setEnabled:YES];
		});
	}
}

- (IBAction)refreshList:(id)sender {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self refreshListWithData:[deviceAccess getDevices]];
	});
}

#pragma mark -
#pragma mark NSTableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [deviceList count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return [[deviceList objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}


@end
