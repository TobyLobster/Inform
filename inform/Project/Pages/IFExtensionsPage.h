//
//  IFExtensionsPage.h
//  Inform
//
//  Created by Toby Nelson on 09/02/2014.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

///
/// The 'extensions' page
///
@interface IFExtensionsPage : IFPage<WebResourceLoadDelegate, WebFrameLoadDelegate>

// The documentation view
/// Tells the view to open a specific URL
- (void) openURL: (NSURL*) url;

/// Opens the home page
- (IBAction) showHome: (id) sender;

/// Show the public library
- (void) showPublicLibrary: (id) sender;

- (void) extensionUpdated:(NSString*) javascriptId;

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
