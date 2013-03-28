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

+ (NSInteger)cannotFindLocalKeychain {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:@"Keychain Missing"];
	[alert setInformativeText:[NSString stringWithFormat:@"Could not locate the local 1Password keychain file."]];
	[alert setAlertStyle:NSWarningAlertStyle];
	return [alert runModal];
}

+ (NSInteger)cannotFindKeychainOnDevice:(NSString *)name {
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setMessageText:@"Keychain Missing"];
	[alert setInformativeText:[NSString stringWithFormat:@"Could not locate a 1Password keychain on \"%@\". Do you want to copy the local keychain to this device?",name]];
	[alert setAlertStyle:NSWarningAlertStyle];
	return [alert runModal];
}

@end
