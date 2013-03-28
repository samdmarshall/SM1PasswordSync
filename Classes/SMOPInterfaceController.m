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
#import "NSAlert+Additions.h"

@implementation SMOPInterfaceController

- (void)deviceConnectionEvent:(NSNotification *)notification {
	if ([notification object] && isSyncing) {
		if ([[notification object] isEqual:[deviceSync getSyncDevice]]) {
			[NSAlert syncInterruptError];
		}
	}
	[self updateDeviceList];
}

- (void)awakeFromNib {
	hadError = FALSE;
	isUpdating = FALSE;
	isSyncing = FALSE;
	if (!deviceList) {
		deviceList = [NSMutableArray new];
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPApplicationSupportPath withIntermediateDirectories:YES attributes:nil error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPSyncPath withIntermediateDirectories:YES attributes:nil error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPSyncStatePath withIntermediateDirectories:YES attributes:nil error:nil];
	
	deviceAccess = [[SMOPDeviceManager alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnectionEvent:) name:@"kDeviceConnectionEventPosted" object:nil];
	
	
	if ([deviceAccess watchForConnection]) {
		[self refreshListWithData:[deviceAccess getDevices]];
	}
}

- (id)init {
	self = [super init];
	if (self) {
		if (!deviceList) {
			deviceList = [NSMutableArray new];
		}
		isUpdating = FALSE;
		isSyncing = FALSE;
		[self refreshListWithData:[deviceAccess getDevices]];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[deviceSync release];
	[deviceList release];
	[deviceAccess release];
	[super dealloc];
}

- (void)refreshListWithData:(NSArray *)devices {
	if (!isUpdating) {
		isUpdating = TRUE;
		[syncButton setEnabled:NO];
		[refreshButton setEnabled:NO];
		NSArray *results = [deviceAccess devicesWithOnePassword4:devices];
		if (results.count) {
			[deviceList setArray:results];
		} else {
			[deviceList removeAllObjects];
		}
		[deviceTable reloadData];
		[syncButton setEnabled:YES];
		[refreshButton setEnabled:YES];
		isUpdating = FALSE;
	}
}

- (void)performSyncForDevice:(AMDevice *)device {
	if (deviceSync)
		[deviceSync release];
	deviceSync = [[SMOPSyncProcess alloc] init];
	[deviceSync setSyncDevice:device withSyncStatus:[[[deviceList objectAtIndex:[deviceTable selectedRow]] valueForKey:@"SyncError"] boolValue]];
	[deviceSync synchronizePasswords];
}

- (IBAction)syncData:(id)sender {
	if (!isUpdating) {
		isSyncing = TRUE;
		AMDevice *device = [self selectedDevice];
		[syncButton setEnabled:NO];
		[refreshButton setEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self performSyncForDevice:device];
			[self refreshListWithData:[deviceAccess getDevices]];
			[syncButton setEnabled:YES];
			[refreshButton setEnabled:YES];
			isSyncing = FALSE;
		});
	}
}

- (void)updateDeviceList {
	if (!isUpdating)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[self refreshListWithData:[deviceAccess getDevices]];
		});
}

- (IBAction)refreshList:(id)sender {
	[self updateDeviceList];
}

- (AMDevice *)selectedDevice {
	return [[deviceAccess getDevices] objectAtIndex:[deviceTable selectedRow]];
}

#pragma mark -
#pragma mark NSTableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	if ([deviceList count] != [[deviceAccess getDevices] count]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kDeviceConnectionEventPosted" object:nil userInfo:nil];
	}
	return [deviceList count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	if ([deviceList count] != [[deviceAccess getDevices] count]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"kDeviceConnectionEventPosted" object:nil userInfo:nil];	
		return @"";
	}
	return [[deviceList objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}


@end
