//
//  IFNewsCustomSchemeHandler.m
//  Inform
//
//  Created by Toby Nelson on 21/06/2022.
//

#import <Foundation/Foundation.h>
#import "WebKit/WebKit.h"
#import "NSString+IFStringExtensions.h"
#import "IFNewsCustomSchemeHandler.h"

@implementation IFNewsCustomSchemeHandler {
}

-(instancetype) init {
    self = [super init];

    if (self) {
    }
    return self;
}

-(void) loadFromURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask  {
}


- (void)    webView:(WKWebView *)webView
 startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {

    // check for 'inform:' scheme aka. protocol
    NSString* scheme = urlSchemeTask.request.URL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"inform"]) {
        // Might as well load the whole file at once
        NSString* urlPath = urlSchemeTask.request.URL.path;
        //NSString* host = urlSchemeTask.request.URL.host;
        NSString* path = nil;

        // Note: first character will always be '/', hence the 'substring' thing
        if ([urlPath length] > 0) {
            urlPath = [urlPath substringFromIndex: 1];
        }

        // NSArray* components = [urlPath pathComponents];

        // Try using pathForResource:ofType:
        // Advantage of this is that it will allow for localisation at some point in the future
        path = [[NSBundle mainBundle] pathForResource: [[urlPath lastPathComponent] stringByDeletingPathExtension]
                                               ofType: [urlPath pathExtension]
                                          inDirectory: [urlPath stringByDeletingLastPathComponent]];

        // Check if the file is in an asset catalog.
        NSString *assetCheckPath = [urlPath stringByDeletingPathExtension];
        if ([assetCheckPath endsWithCaseInsensitive: @"@2x"]) {
            assetCheckPath = [assetCheckPath stringByReplacing:@"@2x" with:@""];
        }
        NSImage *img = [NSImage imageNamed: assetCheckPath];

        if (path == nil && img != nil) {
            //Just output TIFF: it uses the least amount of code:
            NSData *urlData = [img TIFFRepresentation];
            //Which means a TIFF MIME type. Regardless of extension.
            NSString *ourType = @"image/tiff";

            // Create the response
            NSURLResponse* response = [[NSURLResponse alloc] initWithURL: urlSchemeTask.request.URL
                                                                MIMEType: ourType
                                                   expectedContentLength: [urlData length]
                                                        textEncodingName: nil];

            [urlSchemeTask didReceiveResponse:response];    // We have a response
            [urlSchemeTask didReceiveData:urlData];         // We loaded the data
            [urlSchemeTask didFinish];                      // We finished loading
            return;
        }

        if (path == nil) {
            // If that fails, then just append to the resourcePath of the main bundle
            path = [[[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/"] stringByAppendingString: urlPath];
        }

        // Error out if we can't find the path to the resource
        if (path == nil) {
            [urlSchemeTask didFailWithError:[NSError errorWithDomain: NSURLErrorDomain
                                                                code: NSURLErrorBadURL
                                                            userInfo: nil]];
            return;
        }

        // Check that the file exists and is not a directory
        BOOL fileExists = YES;
        BOOL isDir = YES;
        fileExists = [[NSFileManager defaultManager] fileExistsAtPath: path
                                                          isDirectory: &isDir];
        if (isDir) {
            [urlSchemeTask didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
                                                                 code: NSURLErrorFileIsDirectory
                                                             userInfo: nil]];
            return;
        }

        if (!fileExists) {
            [urlSchemeTask didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
                                                                 code: NSURLErrorFileDoesNotExist
                                                             userInfo: nil]];
            return;
        }

        // Load up the data
        NSData* urlData = [NSData dataWithContentsOfFile: path];
        if (urlData == nil) {
            // Failed to load for some other reason
            [urlSchemeTask didFailWithError: [NSError errorWithDomain: NSURLErrorDomain
                                                                 code: NSURLErrorCannotOpenFile
                                                             userInfo: nil]];
            return;
        }

        // Work out the MIME type
        NSString* ourType = nil;
        do {
            NSString *pathExt = path.pathExtension;
            CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)pathExt, kUTTypeData);
            if (!uti) {
                break;
            }

            ourType = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType));
            CFRelease(uti);
        } while (false);

        if (ourType == nil) {
            ourType = @"text/html";
            if ([[path pathExtension] isEqualToString: @"gif"]) {
                ourType = @"image/gif";
            } else if ([[path pathExtension] isEqualToString: @"jpeg"] ||
                       [[path pathExtension] isEqualToString: @"jpg"]) {
                ourType = @"image/jpeg";
            } else if ([[path pathExtension] isEqualToString: @"png"]) {
                ourType = @"image/png";
            } else if ([[path pathExtension] isEqualToString: @"tiff"] ||
                       [[path pathExtension] isEqualToString: @"tif"]) {
                ourType = @"image/tiff";
            }
        }

        // Create the response
        NSURLResponse* response = [[NSURLResponse alloc] initWithURL: urlSchemeTask.request.URL
                                                            MIMEType: ourType
                                               expectedContentLength: [urlData length]
                                                    textEncodingName: nil];

        [urlSchemeTask didReceiveResponse:response];
        [urlSchemeTask didReceiveData:urlData];
        [urlSchemeTask didFinish];
    }
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask {
}

@end
