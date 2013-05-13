//
//  SMOPDebugLogController.m
//  SM1Password Sync
//
//  Created by sam on 5/13/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPDebugLogController.h"
#import "SMOPDefines.h"
#import "MobileDeviceAccess.h"
#import "SMOPFunctions.h"

@implementation SMOPDebugLogController

- (void)awakeFromNib {
	if (!logList) {
		logList = [NSMutableArray new];
	}
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logMessage:) name:kLogMessageEventPosted object:nil];
}

- (id)init {
	self = [super init];
	if (self) {
		if (!logList) {
			logList = [NSMutableArray new];
		}
		logTable.delegate = self;
	}
	return self;
}

- (void)dealloc {
	//[[NSNotificationCenter defaultCenter] removeObserver:self];
	//[logList release];
	[super dealloc];
}

- (void)logMessage:(NSNotification *)notification {
	//NSLog(@"%@",notification);
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"MMM dd, yyyy HH:mm:ss"];
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	[dateFormatter setLocale:[NSLocale currentLocale]];
	NSString *notificationPostDate = [dateFormatter stringFromDate:[notification.userInfo objectForKey:@"DateStamp"]];
	[dateFormatter release];
	
	NSDictionary *logItem = [NSDictionary dictionaryWithObjectsAndKeys:notificationPostDate, @"DateStamp", GetSourceFromNotificiation(notification), @"NotificationSource", [NSString stringWithFormat:@"%@ - %@", [notification.userInfo objectForKey:@"NotificationAction"], [notification.userInfo objectForKey:@"MessageString"]], @"LogMessage", nil];
	[logList addObject:logItem];
	[logTable reloadData];
	[logTable scrollRowToVisible:logList.count-1];
}


#pragma mark -
#pragma mark NSTableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [logList count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return [[logList objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

@end
