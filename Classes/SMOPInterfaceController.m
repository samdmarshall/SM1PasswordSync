//
//  SMOPInterfaceController.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPInterfaceController.h"
#import "SMOPDefines.h"
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
	[syncProgress setHidden:YES];
	if (!deviceList) {
		deviceList = [NSMutableArray new];
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPApplicationSupportPath withIntermediateDirectories:YES attributes:nil error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPSyncPath withIntermediateDirectories:YES attributes:nil error:nil];
	[[NSFileManager defaultManager] createDirectoryAtPath:kSMOPSyncStatePath withIntermediateDirectories:YES attributes:nil error:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnectionEvent:) name:kDeviceConnectionEventPosted object:nil];
	
	deviceAccess = [[SMOPDeviceManager alloc] init];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		if ([deviceAccess watchForConnection]) {
			[self updateDeviceList];
		}
	});
}

- (id)init {
	self = [super init];
	if (self) {
		if (!deviceList) {
			deviceList = [NSMutableArray new];
		}
		deviceTable.delegate = self;
		isUpdating = FALSE;
		isSyncing = FALSE;
		[syncProgress setIndeterminate:NO];
		[syncProgress setDoubleValue:0.0];
		[syncProgress setUsesThreadedAnimation:YES];
		[syncProgress setDisplayedWhenStopped:YES];
		[syncProgress displayIfNeeded];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceConnectionEvent:) name:kDeviceConnectionEventPosted object:nil];
		[self updateDeviceList];
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
		isUpdating = FALSE;
		[self updateTableSelection:[deviceTable selectedRow]];
		[syncButton setEnabled:YES];
		[refreshButton setEnabled:YES];
	}
}

- (void)performSyncForDevice:(AMDevice *)device {
	if (deviceSync)
		[deviceSync release];
	deviceSync = [[SMOPSyncProcess alloc] init];
	deviceSync.delegate = self;
	[deviceSync setSyncDevice:device withSyncStatus:[[[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceState"] valueForKey:@"SyncError"] boolValue]];
	[deviceSync synchronizePasswords];
}

- (void)performInstallOnDevice:(AMDevice *)device {
	if (deviceSync)
		[deviceSync release];
	deviceSync = [[SMOPSyncProcess alloc] init];
	deviceSync.delegate = self;
	[deviceSync setSyncDevice:device withSyncStatus:[[[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceState"] valueForKey:@"SyncError"] boolValue]];
	[deviceSync installOnePassword];
}

- (IBAction)syncDevice:(id)sender {
	if (!isUpdating) {
		AMDevice *device = [self selectedDevice];
		if (device != nil) {
			isSyncing = TRUE;
			[(NSMutableDictionary *)[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceState"] setObject:@"sync" forKey:@"StateIcon"];
			[deviceTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:[deviceTable selectedRow]] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[syncButton setEnabled:NO];
				[refreshButton setEnabled:NO];
				[syncProgress setDoubleValue:0.0];
				[syncProgress displayIfNeeded];
				[syncProgress setHidden:NO];
				[self performSyncForDevice:device];
				isSyncing = FALSE;
				[self refreshListWithData:deviceAccess.managerDevices];
				[syncButton setEnabled:YES];
				[refreshButton setEnabled:YES];
				[syncProgress setHidden:YES];
			});
		}
	}
}

- (IBAction)refreshList:(id)sender {
	[self updateDeviceList];
}

- (IBAction)installAndSync:(id)sender {
	if (!isUpdating) {
		AMDevice *device = [self selectedDevice];
		if (device != nil) {
			isSyncing = TRUE;
			[(NSMutableDictionary *)[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceState"] setObject:@"installing" forKey:@"StateIcon"];
			[deviceTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:[deviceTable selectedRow]] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
				[syncButton setEnabled:NO];
				[refreshButton setEnabled:NO];
				[syncProgress setDoubleValue:0.0];
				[syncProgress displayIfNeeded];
				[syncProgress setHidden:NO];
				[self performInstallOnDevice:device];
				isSyncing = FALSE;
				[self refreshListWithData:deviceAccess.managerDevices];
				[syncButton setEnabled:YES];
				[refreshButton setEnabled:YES];
				[syncProgress setHidden:YES];
			});
		}
	}
}

- (void)updateDeviceList {
	[self refreshListWithData:deviceAccess.managerDevices];
}

- (AMDevice *)selectedDevice {
	if (deviceAccess.managerDevices.count == 0) {
		return nil;
	} else {
		BOOL canSyncWithDevice = [[[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceState"] objectForKey:@"ConnectState"] boolValue];
		if (!canSyncWithDevice) {
			[NSAlert communciationErrorWithDevice:[[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceInfo"] objectForKey:@"DeviceName"]];
			return nil;
		} else {
			return [deviceAccess getDeviceWithIdentifier:[[self deviceInfoAtSelectedRow] objectForKey:@"DeviceIdentifier"]];
		}
	}
}

- (NSDictionary *)deviceInfoAtSelectedRow {
	NSInteger selection = [deviceTable selectedRow];
	return (selection >= 0 && selection < deviceList.count ? [deviceList objectAtIndex:[deviceTable selectedRow]] : nil);
}

- (void)updateTableSelection:(NSInteger)index {
	if (isUpdating || isSyncing) {
		[syncButton setEnabled:NO];
		[refreshButton setEnabled:NO];
	} else {
		NSDictionary *state;
		if (index != -1 && index < deviceList.count) {
			state = [[deviceList objectAtIndex:index] objectForKey:@"DeviceState"];
		} else {
			state = [[self deviceInfoAtSelectedRow] objectForKey:@"DeviceState"];
		}
		BOOL canConnect = [[state objectForKey:@"ConnectState"] boolValue];
		if (canConnect) {
			[syncButton setEnabled:YES];
			BOOL needsApp = [[state objectForKey:@"NeedsAppInstall"] boolValue];
			[syncButton setTitle:(needsApp ? @"Install" : @"Sync")];
			[syncButton setAction:(needsApp ? @selector(installAndSync:) : @selector(syncDevice:))];
		} else {
			[syncButton setTitle:@"Install"];
			[syncButton setAction:@selector(installAndSync:)];
			[syncButton setEnabled:NO];
		}
	}
	[syncButton setNeedsDisplay:YES];
}

#pragma mark -
#pragma mark NSTableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [deviceList count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	if (isUpdating || isSyncing) {
		[syncButton setEnabled:NO];
	} else {
		[syncButton setEnabled:[[[[deviceList objectAtIndex:rowIndex] objectForKey:@"DeviceState"] objectForKey:@"ConnectState"] boolValue]];
	}
	if ([[aTableColumn identifier] isEqualToString:@"StateIcon"]) {
		return [NSImage imageNamed:[[[deviceList objectAtIndex:rowIndex] objectForKey:@"DeviceState"] objectForKey:[aTableColumn identifier]]];
	} else {
		return [[[deviceList objectAtIndex:rowIndex] objectForKey:@"DeviceInfo"] objectForKey:[aTableColumn identifier]];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	[self updateTableSelection:-1];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
	[self updateTableSelection:rowIndex];
	return YES;
}

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	[self updateTableSelection:row];
	return YES;
}

#pragma mark -
#pragma mark SMOPSyncProgressDelegate
-(void)syncItemNumber:(NSUInteger)item ofTotal:(NSUInteger)count {
	dispatch_sync(dispatch_get_main_queue(), ^{
		double newValue = ((double)item/(double)count)*100.0;
		[syncProgress setDoubleValue:newValue];
		[syncProgress displayIfNeeded];
	});
}

@end
