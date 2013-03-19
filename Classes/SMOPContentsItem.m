//
//  SMOPContentsItem.m
//  SM1Password Sync
//
//  Created by sam on 3/19/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPContentsItem.h"


@implementation SMOPContentsItem

- (id)initWithArray:(NSArray *)data {
	self = [super init];
	if (self) {
		item = data;
	}
	return self;
}

- (void)dealloc {
	[item release];
	[super dealloc];
}

- (NSArray *)contents {
	return item;
}

- (BOOL)isEqual:(id)obj {
	BOOL result = [obj isKindOfClass:[SMOPContentsItem class]];
	if (result) {
		result = [[item objectAtIndex:0] isEqualToString:[[obj contents] objectAtIndex:0]];
		if (result)
			result = (([[item objectAtIndex:4] integerValue] == [[[obj contents] objectAtIndex:4] integerValue])? TRUE : FALSE);
	} else {
		result = [super isEqual:obj];
	}
	return result;
}

@end
