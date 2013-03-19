//
//  SMOPContentsItem.h
//  SM1Password Sync
//
//  Created by sam on 3/19/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SMOPContentsItem : NSObject {
	NSArray *item;
}

- (id)initWithArray:(NSArray *)data;
- (NSArray *)contents;
- (BOOL)isEqual:(id)obj;

@end
