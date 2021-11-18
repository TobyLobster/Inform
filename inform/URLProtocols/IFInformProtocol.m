//
//  IFInformProtocol.m
//  Inform
//
//  Created by Andrew Hunter on Sat Jun 05 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFInformProtocol.h"
#import "IFUtility.h"

@implementation IFInformProtocol {
    NSURLRequest* theURLRequest;					// The URL request we're supposed to be processing
    NSCachedURLResponse* theCachedResponse;			// The associated cached response
    id<NSURLProtocolClient> theClient;				// The client we're talking to
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
	// We respond to 'inform:///Foo' style URLs
	if ([[[request URL] scheme] isEqualToString: @"inform"]) {
		if ([[request URL] path] != nil)
			return YES;
	}
	return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
	// No idea what this is supposed to do.
	// Docs pretty much say 'whatever you want'
	return request;
}

-(instancetype)initWithRequest:(NSURLRequest *)request 
	  cachedResponse:(NSCachedURLResponse *)cachedResponse 
			  client:(id <NSURLProtocolClient>)client {
	self = [super initWithRequest: request
				   cachedResponse: cachedResponse
						   client: client];
	if (self) {
		theURLRequest = request;
		theCachedResponse = cachedResponse;
		theClient = client;
	}
	
	return self;
}


-(NSCachedURLResponse *)cachedResponse {
	return theCachedResponse;
}

-(id <NSURLProtocolClient>)client {
	return theClient;
}

- (void) startLoading {
	// Might as well load the whole file at once
	NSString* urlPath = [[theURLRequest URL] path];
	NSString* host = [[theURLRequest URL] host];
	NSString* path = nil;
	
	// Note: first character will always be '/', hence the 'substring' thing
	if ([urlPath length] > 0) {
		urlPath = [urlPath substringFromIndex: 1];
	}
	
	NSArray* components = [urlPath pathComponents];
	
	// Accept either the host or the path specifier containing 'extensions'
	if ([[host lowercaseString] isEqualToString: @"extensions"] ||
			(components != nil && [components count] > 1 && 
			 [[components[0] lowercaseString] isEqualToString: @"extensions"])) {
		int skip = 0;
		int x;
		
		if (![[host lowercaseString] isEqualToString: @"extensions"])
			skip = 1;
		
		// Try the library directories
        NSEnumerator* componentEnum = [components objectEnumerator];
        NSString* pathComponent;
        
        path = [IFUtility pathForInformExternalDocumentation];
        for (x=0; x<skip; x++) [componentEnum nextObject];
        while ((pathComponent = [componentEnum nextObject])) {
            path = [path stringByAppendingPathComponent: pathComponent];
        }
        
        if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
            path = nil;
        }

		// Try the ExtnDocs resources directory
        /*
		if (path == nil) {
			componentEnum = [components objectEnumerator];
			
			path = @"ExtnDocs";
			for (x=0; x<skip; x++) [componentEnum nextObject];
			while ((pathComponent = [componentEnum nextObject])) {
				path = [path stringByAppendingPathComponent: pathComponent];
			}

			path = [[NSBundle mainBundle] pathForResource: [[path lastPathComponent] stringByDeletingPathExtension]
												   ofType: [path pathExtension]
											  inDirectory: [path stringByDeletingLastPathComponent]];
		}
        */
	} else {
		// Try using pathForResource:ofType:
		// Advantage of this is that it will allow for localisation at some point in the future
		path = [[NSBundle mainBundle] pathForResource: [[urlPath lastPathComponent] stringByDeletingPathExtension]
											   ofType: [urlPath pathExtension]
                                          inDirectory: [urlPath stringByDeletingLastPathComponent]];
	}

	if (path == nil) {
		// If that fails, then just append to the resourcePath of the main bundle
		path = [[[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/"] stringByAppendingString: urlPath];
	}

	// Check that this is the right kind of URL for us
	if (path == nil || ![[[theURLRequest URL] scheme] isEqualToString: @"inform"]) {
		// Doh - not a valid inform: URL
		[theClient URLProtocol: self
			  didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
													code: NSURLErrorBadURL
												userInfo: nil]];
		return;
	}
	
    // Check if the file is in an asset catalog.
    BOOL notThere = [[NSBundle mainBundle] pathForImageResource:[path stringByDeletingPathExtension]] == nil;
    NSImage *img = [NSImage imageNamed: [path stringByDeletingPathExtension]];
    
    if (notThere && img != nil) {
        //Just output TIFF: it uses the least amount of code:
        NSData *urlData = [img TIFFRepresentation];
        //Which means a TIFF MIME type. Regardless of
        NSString *ourType = @"image/tiff";
        
        // Create the response
        NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [theURLRequest URL]
                                                            MIMEType: ourType
                                               expectedContentLength: [urlData length]
                                                    textEncodingName: nil];
        
        [theClient URLProtocol: self
            didReceiveResponse: response
            cacheStoragePolicy: NSURLCacheStorageAllowedInMemoryOnly];
        
        // We loaded the data
        [theClient URLProtocol: self
                   didLoadData: urlData];
        
        // We finished loading
        [theClient URLProtocolDidFinishLoading: self];
    } else {
	// Check that the file exists and is not a directory
	BOOL isDir = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath: path
											  isDirectory: &isDir]) {
		isDir = YES;
	}
	
	if (isDir) {
		// Will also happen if the file doesn't exist: see above
		[theClient URLProtocol: self
			  didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
													code: NSURLErrorFileDoesNotExist
												userInfo: nil]];
		// (Yeah, there's technically a difference between NSURLErrorFileDoesNotExist and
		// NSURLErrorFileIsDirectory. But I'm lazy here)
		return;
	}
	
	// Load up the data
	NSData* urlData = [NSData dataWithContentsOfFile: path];
	if (urlData == nil) {
		// Failed to load for some other reason
		[theClient URLProtocol: self
			  didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
													code: NSURLErrorCannotOpenFile
												userInfo: nil]];
		return;
	}
		
	// Work out the MIME type
	// Sigh, must be a better way, but it's not obvious
	NSString* ourType = @"text/html";
	if ([[path pathExtension] isEqualToString: @"gif"])
		ourType = @"image/gif";
	else if ([[path pathExtension] isEqualToString: @"jpeg"] ||
			 [[path pathExtension] isEqualToString: @"jpg"])
		ourType = @"image/jpeg";
	else if ([[path pathExtension] isEqualToString: @"png"])
		ourType = @"image/png";
	else if ([[path pathExtension] isEqualToString: @"tiff"] ||
			 [[path pathExtension] isEqualToString: @"tif"])
		ourType = @"image/tiff";

	// Create the response
	NSURLResponse* response = [[NSURLResponse alloc] initWithURL: [theURLRequest URL]
														MIMEType: ourType
										   expectedContentLength: [urlData length]
												textEncodingName: nil];
	
	[theClient URLProtocol: self
		didReceiveResponse: response
		cacheStoragePolicy: NSURLCacheStorageAllowedInMemoryOnly];
	
	// We loaded the data
	[theClient URLProtocol: self
			   didLoadData: urlData];
	
	// We finished loading
	[theClient URLProtocolDidFinishLoading: self];
    }
}

- (void) stopLoading {
}

@end
