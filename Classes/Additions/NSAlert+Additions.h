//
//  NSAlert+Additions.h
//  SM1Password Sync
//
//  Created by sam on 3/19/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSAlert(Additions)
+ (NSInteger)connectionErrorWithDevice:(NSString *)name;
+ (NSInteger)emptyKeychainAlertAtPath:(NSString *)path;
+ (NSInteger)cannotFindLocalKeychain;
+ (NSInteger)cannotFindKeychainOnDevice:(NSString *)name;
+ (NSInteger)previousSyncError;
+ (NSInteger)syncInterruptError;
@end
