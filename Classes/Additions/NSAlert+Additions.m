//
//  NSAlert+Additions.m
//  SM1Password Sync
//
//  Created by sam on 3/19/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "NSAlert+Additions.h"


@implementation NSAlert(Additions)

+ (NSInteger)emptyKeychainAlertAtPath:(NSString *)path {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Continue"];
	[alert setMessageText:@"Keychain Error"];
	[alert setInformativeText:[NSString stringWithFormat:@"There was a problem with reading your agilekeychain file (%@), do you wish to continue the sync?",path]];
	[alert setAlertStyle:NSWarningAlertStyle];
	return [alert runModal];
}
@end
