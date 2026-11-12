//
//  IFDocumentationPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

NS_ASSUME_NONNULL_BEGIN

///
/// The 'documentation' page
///
@interface IFDocumentationPage : IFPage<WKNavigationDelegate>

// The documentation view
/// Tells the documentation view to open a specific URL
- (void) openURL: (NSURL*) url;
/// Opens a URL from the history, without recording it in the history again
- (void) openHistoricalURL: (nullable NSURL*) url;
/// Opens the table of contents
- (IBAction) showToc: (nullable id) sender;

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
