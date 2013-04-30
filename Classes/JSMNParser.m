//
//  JSMNParser.m
//  SM1Password Sync
//
//  Created by sam on 3/20/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "JSMNParser.h"
#import "SMOPContentsItem.h"

@implementation JSMNParser 

- (id)initWithPath:(NSString *)path tokenCount:(NSInteger)total {
	self = [super init];
	if (self) {
		count = total;
		offset = 0;
		if (count)
			tokens = (jsmntok_t *)malloc(sizeof(jsmntok_t)*total);
		jsonData = [[NSString alloc] initWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];		
		jsmn_parser localParser;
		jsmn_init(&localParser);
		jsmn_parse(&localParser, [jsonData cStringUsingEncoding:NSUnicodeStringEncoding], tokens, total);
		for (uint32_t i = 0; i < total; i++) {
			if (tokens[i].start == 0 && tokens[i].end == 0) {
				count = i - 1;
				break;
			}
		}
	}
	return self;
}

+ (NSUInteger)tokenCountForObject:(id)obj {
	NSUInteger count = 0;
	
	if ([obj isKindOfClass:[SMOPContentsItem class]]) {
		obj = [obj returnAsArray];
	}
	
	if ([obj isKindOfClass:[NSArray class]]) {
		count = count + [obj count];
		for (id item in obj) {
			count = count + [JSMNParser tokenCountForObject:item];
		}
	}
	if ([obj isKindOfClass:[NSDictionary class]]) {
		count = count + 1;
		NSEnumerator *enumerator = [obj objectEnumerator];
		id value;
		while ((value = [enumerator nextObject])) {
			count = count + 1 + [JSMNParser tokenCountForObject:value];
		}
	}
	if ([obj isKindOfClass:[NSNumber class]]) {
		count++;
	}
	if ([obj isKindOfClass:[NSString class]]) {
		count++;
	}
	return count;
}

+ (NSString *)serializeJSON:(id)obj {
	NSMutableString *serialize = [[NSMutableString new] autorelease];
	
	if ([obj isKindOfClass:[SMOPContentsItem class]]) {
		obj = [obj returnAsArray];
	}
	
	if ([obj isKindOfClass:[NSArray class]]) {
		NSMutableArray *arrayItems = [NSMutableArray new];
		for (id item in obj) {
			[arrayItems addObject:[JSMNParser serializeJSON:item]];
		}
		[serialize appendFormat:@"[%@]",[arrayItems componentsJoinedByString:@","]];
		[arrayItems release];
	}
	if ([obj isKindOfClass:[NSDictionary class]]) {
		NSMutableArray *allEntries = [NSMutableArray new];
		[obj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
			NSString *entry = [NSString stringWithFormat:@"\"%@\": %@",key,[JSMNParser serializeJSON:obj]];
			[allEntries addObject:entry];
		}];
		[serialize appendFormat:@"{%@}",[allEntries componentsJoinedByString:@","]];
		[allEntries release];
	}
	if ([obj isKindOfClass:[NSNumber class]]) {
		[serialize appendFormat:@"%@",[obj stringValue]];
	}
	if ([obj isKindOfClass:[NSString class]]) {
		[serialize appendFormat:@"\"%@\"",obj];
	}
	
	return serialize;
}

- (id)deserializeJSON {	
	contentsParse = FALSE;
	id result = [self parseFromIndex:0];
	offset = 0;
	return result;
}

- (id)deserializeContents {
	contentsParse = TRUE;
	id result = [self parseFromIndex:0];
	offset = 0;
	return result;
}

- (id)parseFromIndex:(NSInteger)index {
	id parsed = nil;
	switch (tokens[index].type) {
		case JSMN_PRIMITIVE: {
			NSInteger length = tokens[index].end-tokens[index].start;
			NSString *valueString = [jsonData substringWithRange:NSMakeRange(tokens[index].start,length)];
			if (length == 1) {
				if ([valueString isEqualToString:@"Y"] || [valueString isEqualToString:@"N"]) {
					parsed = valueString;
					break;
				}
			} else if (length == 0) {
				valueString = @"";
			}
			NSNumberFormatter *stringFormatter = [[NSNumberFormatter alloc] init];
			[stringFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			parsed = [stringFormatter numberFromString:valueString];
			[stringFormatter release];
			break;
		};
		case JSMN_OBJECT: {
			parsed = [NSMutableDictionary dictionaryWithCapacity:tokens[index].size/2];
			for (uint32_t i = 0; i < tokens[index].size; i+=2) {
				NSUInteger keyIndex = offset+index+1+i;
				NSUInteger objectIndex = offset+index+2+i;
				NSString *keyName = [self parseFromIndex:(keyIndex >= count ? index+1+i : keyIndex)];
				[parsed setObject:[self parseFromIndex:(objectIndex >= count ? index+2+i : objectIndex)] forKey:keyName];
			}
			if (tokens[index].start)
				offset = offset + tokens[index].size;
			break;
		};
		case JSMN_ARRAY: {
			parsed = [NSMutableArray arrayWithCapacity:tokens[index].size];
			for (uint32_t i = 0; i < tokens[index].size; i++) {
				if (index == 0 || contentsParse) {
					offset++;
					[parsed addObject:[self parseFromIndex:offset]];
					offset = offset + tokens[offset].size;
				} else {
					NSUInteger keyIndex = offset+index+1+i;
					[parsed addObject:[self parseFromIndex:(keyIndex >= count ? index+1+i : keyIndex)]];
				}
			}
			if (tokens[index].start && index != 0 && !contentsParse)
				offset = offset + tokens[index].size;
			break;
		};
		case JSMN_STRING: {
			if (tokens[index].end-tokens[index].start > 0) {
				parsed = [jsonData substringWithRange:NSMakeRange(tokens[index].start,tokens[index].end-tokens[index].start)];
			} else {
				parsed = @"";
			}
			break;
		};
		default: {
			break;
		};
	}
	return parsed;
}

- (void)dealloc {
	[jsonData release];
	if (count)
		free(tokens);
	[super dealloc];
}

@end
