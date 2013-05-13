//
//  SMOPDebugLogController.h
//  SM1Password Sync
//
//  Created by sam on 5/13/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SMOPDebugLogController : NSObject <NSTableViewDataSource, NSTableViewDelegate> {
	IBOutlet NSTableView *logTable;
	
	NSMutableArray *logList;
}

#pragma mark -
#pragma mark NSTableView
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

@end
