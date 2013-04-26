//
//  SMOPDeviceDetector.m
//  SM1Password Sync
//
//  Created by sam on 4/9/13.
//  Copyright 2013 Sam Marshall. All rights reserved.
//

#import "SMOPDeviceDetector.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOCFPlugIn.h>

@implementation SMOPDeviceDetector

+ (NSArray *)devicesSupportingIPhoneOS {
	NSMutableArray *devices = [[NSMutableArray new] autorelease];
	io_iterator_t iterator;
	mach_port_t masterPort;
	kern_return_t kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
	if (kr == kIOReturnSuccess && masterPort) {
		CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
		IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator);
		io_service_t usbDevice;
		while (usbDevice = IOIteratorNext(iterator)) {
			CFTypeRef supportsIPhoneOS = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("SupportsIPhoneOS"), kCFAllocatorDefault, kIORegistryIterateRecursively);
			if (supportsIPhoneOS) {
				CFTypeRef serialNumber = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("USB Serial Number"), kCFAllocatorDefault, kIORegistryIterateRecursively);
				CFTypeRef productName = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("USB Product Name"), kCFAllocatorDefault, kIORegistryIterateRecursively);
				CFTypeRef productId = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("bcdDevice"), kCFAllocatorDefault, kIORegistryIterateRecursively);
				uint16_t version = [(NSNumber *)productId intValue] >> 8;
				uint16_t revision = ([(NSNumber *)productId intValue] & 0x00FF) >> 4;				
				NSString *productType = [NSString stringWithFormat:@"%@%i,%i",(NSString *)productName,version,revision];
				[devices addObject:[NSDictionary dictionaryWithObjectsAndKeys:(NSString *)serialNumber, @"UniqueDeviceID", (NSString *)productName, @"ProductName", (NSString *)productType, @"productType", nil]];
			}
			IOObjectRelease(usbDevice);
		}
	} else {
		NSLog (@"Error: Couldn't create a master I/O Kit port(%08x)", kr);
	}
	mach_port_deallocate(mach_task_self(), masterPort);
	return devices;
}

@end
