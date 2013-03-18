//
//  SMOPInterfaceController.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPInterfaceController.h"


@implementation SMOPInterfaceController

- (void)awakeFromNib {
	deviceList = [NSMutableArray new];
	deviceAccess = [[SMOPDeviceManager alloc] init];
	if ([deviceAccess watchForConnection]) {
		[self refreshWithData:[deviceAccess getDevices]];
	}
}

- (void)dealloc {
	[deviceList release];
	[deviceAccess release];
	[super dealloc];
}

- (void)refreshWithData:(NSArray *)devices {
	
}

- (IBAction)syncData:(id)sender {
	
}

- (IBAction)refreshList:(id)sender {
	
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
