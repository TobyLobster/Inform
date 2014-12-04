//
//  ZoomPlugInInfo.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <ZoomPlugIns/ZoomPlugInInfo.h>
#import "ZoomPlugInManager.h"


@implementation ZoomPlugInInfo

// = Initialisation =

- (id) initWithBundleFilename: (NSString*) bundle {
	NSDictionary* plist = [[ZoomPlugInManager sharedPlugInManager] plistForBundle: bundle];

	// No information available if there's no plist for this bundle
	if (plist == nil) {
		self = [super init];
		[self release];
		return nil;
	}
	
	self = [self initFromPList: [plist objectForKey: @"ZoomPlugin"]];
	
	if (self) {
		// Get the information out of the plist
		[image release]; image = nil;
		image				= [[plist objectForKey: @"ZoomPlugin"] objectForKey: @"Image"];		
		
		if (image != nil) {
			image = [[bundle stringByAppendingPathComponent: image] stringByStandardizingPath];
		}
		
		[image retain];
		
		// Work out the status (installed or downloaded as we're working from a path)
		NSString* standardPath = [bundle stringByStandardizingPath];
		NSString* mainBundlePath = [[[NSBundle mainBundle] bundlePath] stringByStandardizingPath];
		
		if ([mainBundlePath characterAtIndex: [mainBundlePath length]-1] != '/') {
			mainBundlePath = [mainBundlePath stringByAppendingString: @"/"];
		}
		
		if ([standardPath hasPrefix: mainBundlePath] || [standardPath hasPrefix: [ZoomPlugInManager plugInsPath]]) {
			status = ZoomPlugInInstalled;
		} else {
			status = ZoomPlugInDownloaded;
		}
		
		[location release]; location = nil;
		location = [[NSURL fileURLWithPath: bundle] copy];
	}
	
	return self;
}

static unsigned int ValueForHexChar(int hex) {
	if (hex >= '0' && hex <= '9') return hex - '0';
	if (hex >= 'a' && hex <= 'f') return hex - 'a' + 10;
	if (hex >= 'A' && hex <= 'F') return hex - 'A' + 10;
	return 0;
}

- (id) initFromPList: (NSDictionary*) plist {
	self = [super init];
	
	if (self) {
		// No information available if there's no plist for this bundle
		if (plist == nil) {
			[self release];
			return nil;
		}
		
		// Get the information out of the plist
		name				= [[plist objectForKey: @"DisplayName"] retain];
		author				= [[plist objectForKey: @"Author"] retain];
		interpreterAuthor	= [[plist objectForKey: @"InterpreterAuthor"] retain];
		interpreterVersion	= [[plist objectForKey: @"InterpreterVersion"] retain];
		version				= [[plist objectForKey: @"Version"] retain];
		image				= nil;		
		status				= ZoomPlugInNotKnown;
		
		if ([plist objectForKey: @"URL"] != nil) {
			location = [[NSURL URLWithString: [plist objectForKey: @"URL"]] copy];			
		}
		
		// Get the MD5 value if it exists
		id md5raw = [plist objectForKey: @"MD5"];
		
		if ([md5raw isKindOfClass: [NSData class]]) {
			// Just use data values directly
			md5 = [md5raw retain];
		} else if ([md5raw isKindOfClass: [NSString class]]) {
			// Build a digest from string values
			unsigned char digest[16];
			int x;
			for (x=0; x<16; x++) {
				int pos = x*2;
				if (pos+1 >= [md5raw length]) break;
				
				unichar firstChar = [md5raw characterAtIndex: pos];
				unichar secondChar = [md5raw characterAtIndex: pos+1];
				
				digest[x] = (ValueForHexChar(firstChar)<<4)|ValueForHexChar(secondChar);
			}
			
			md5 = [[NSData alloc] initWithBytes: digest
										 length: 16];
		}
		
		if ([plist objectForKey: @"UpdateURL"] != nil) {
			updateUrl = [[NSURL URLWithString: [plist objectForKey: @"UpdateURL"]] copy];
		}
		
		// Check the plist entries
		if (name == nil) {
			[self release];
			return nil;
		}
		if (author == nil) {
			if (interpreterAuthor == nil) {
				[self release];
				return nil;
			}
			author = [interpreterAuthor retain];
		}
		if (interpreterAuthor == nil) {
			interpreterAuthor = [author retain];
		}
		if (version == nil || interpreterVersion == nil) {
			[self release];
			return nil;
		}
	}
	
	return self;	
}

- (void) dealloc {
	[name release];
	[author release];
	[interpreterVersion release];
	[interpreterAuthor release];
	[version release];
	[image release];
	[location release];
	[updated release];
	[updateDownload release];
	[md5 release];
	[updateUrl release];
	
	[super dealloc];
}

// = Copying =

- (id) copyWithZone: (NSZone*) zone {
	ZoomPlugInInfo* newInfo = [[ZoomPlugInInfo alloc] init];
	
	newInfo->name 				= [name copy];
	newInfo->author 			= [author copy];
	newInfo->interpreterVersion	= [interpreterVersion copy];
	newInfo->interpreterAuthor 	= [interpreterAuthor copy];
	newInfo->version 			= [version copy];
	newInfo->image 				= [image copy];
	newInfo->location 			= [location copy];
	newInfo->md5 				= [md5 copy];
	newInfo->status 			= status;
	newInfo->updated 			= [updated copy];
	newInfo->updateUrl 			= [updateUrl copy];
	
	return newInfo;
}

// = Retrieving the information =

- (NSString*) name {
	return name;
}

- (NSString*) author {
	return author;
}

- (NSString*) version {
	return version;
}

- (NSString*) interpreterAuthor {
	return interpreterAuthor;
}

- (NSString*) interpreterVersion {
	return interpreterVersion;
}

- (NSString*) imagePath {
	return image;
}

- (ZoomPlugInStatus) status {
	return status;
}

- (void) setStatus: (ZoomPlugInStatus) newStatus {
	status = newStatus;
}

- (NSString*) description {
	return [NSString stringWithFormat: @"Plug in: %@, version %@", [self name], [self version]];
}

- (NSURL*) location {
	return location;
}

- (ZoomPlugInInfo*) updateInfo {
	return updated;
}

- (void) setUpdateInfo: (ZoomPlugInInfo*) info {
	[updated release];
	updated = [info copy];
}

- (ZoomDownload*) download {
	return updateDownload;
}

- (void) setDownload: (ZoomDownload*) download {
	[updateDownload release];
	updateDownload = [download retain];
}

- (NSData*) md5 {
	return md5;
}

- (NSURL*) updateUrl {
	return updateUrl;
}

@end
