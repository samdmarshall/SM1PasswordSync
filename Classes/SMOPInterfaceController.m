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
	if (!deviceList) {
		deviceList = [NSMutableArray new];
	}
	deviceAccess = [[SMOPDeviceManager alloc] init];
	
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
		[self refreshListWithData:[deviceAccess getDevices]];
	}
	return self;
}

- (void)dealloc {
	[deviceSync release];
	[deviceList release];
	[deviceAccess release];
	[super dealloc];
}

- (void)refreshListWithData:(NSArray *)devices {
	if (!isUpdating) {
		isUpdating = TRUE;
		[deviceList removeAllObjects];
		NSArray *results = [deviceAccess devicesWithOnePassword4:devices];
		if (results.count)
			[deviceList addObjectsFromArray:results];
		[deviceTable reloadData];
		isUpdating = FALSE;
	}
}

- (void)performSync {
	if (deviceSync)
		[deviceSync release];
	deviceSync = [[SMOPSyncProcess alloc] init];
	[deviceSync setSyncDevice:[self selectedDevice]];
	[deviceSync synchronizePasswords];
}

- (IBAction)syncData:(id)sender {
	if (!isUpdating) {
		[syncButton setEnabled:NO];
		[refreshButton setEnabled:NO];
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
			[self performSync];
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

- (AMDevice *)selectedDevice {
	return [[deviceAccess getDevices] objectAtIndex:[deviceTable selectedRow]];
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
