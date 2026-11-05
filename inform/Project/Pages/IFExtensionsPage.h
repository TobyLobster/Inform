//
//  IFExtensionsPage.h
//  Inform
//
//  Created by Toby Nelson on 09/02/2014.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The 'extensions' page
///
@interface IFExtensionsPage : IFPage<WKNavigationDelegate>

// The documentation view
/// Tells the view to open a specific URL
- (void) openURL: (NSURL*) url;

/// Opens the home page
- (IBAction) showHome: (nullable id) sender;

/// Show the public library
- (void) showPublicLibrary: (nullable id) sender;

- (void) extensionUpdated:(nullable NSString*) javascriptId;

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
