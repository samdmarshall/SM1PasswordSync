//
//  SMOPInterfaceController.m
//  SM1Password Sync
//
//  Created by sam on 3/18/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPInterfaceController.h"
#import "SMOPDefines.h"

@implementation SMOPInterfaceController

- (void)awakeFromNib {
	hadError = FALSE;
	deviceList = [NSMutableArray new];
	deviceAccess = [[SMOPDeviceManager alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(errorWithAFC:) name:@"kAFCFailedToConnectError" object:nil];
	
	if ([deviceAccess watchForConnection]) {
		[self refreshWithData:[deviceAccess getDevices]];
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
		[self refreshWithData:[deviceAccess getDevices]];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[deviceList release];
	[deviceAccess release];
	[super dealloc];
}

- (void)refreshWithData:(NSArray *)devices {
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
				NSDictionary *deviceDict = [NSDictionary dictionaryWithObjectsAndKeys:[device deviceName], @"DeviceName", [device deviceClass], @"DeviceClass", lastSyncDate, @"SyncDate", nil];
				[deviceList addObject:deviceDict];
			} else {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"kAFCFailedToConnectError" object:self userInfo:nil];
			}
			[fileService release];
		}
	}
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
