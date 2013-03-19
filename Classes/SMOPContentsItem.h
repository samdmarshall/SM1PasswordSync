//
//  SMOPContentsItem.h
//  SM1Password Sync
//
//  Created by sam on 3/19/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SMOPContentsItem : NSObject {
	NSString *uniqueId;
	NSString *folder;
	NSString *name;
	NSString *location;
	NSNumber *modifiedDate;
	NSString *unknownString;
	NSNumber *unknownNumber;
	NSNumber *trashed;
}

@property (nonatomic, retain) NSString *uniqueId;
@property (nonatomic, retain) NSString *folder;
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *location;
@property (nonatomic, retain) NSNumber *modifiedDate;
@property (nonatomic, retain) NSString *unknownString;
@property (nonatomic, retain) NSNumber *unknownNumber;
@property (nonatomic, retain) NSNumber *trashed;

- (id)initWithArray:(NSArray *)data;

@end
