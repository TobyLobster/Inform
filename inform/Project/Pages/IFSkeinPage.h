//
//  IFSkeinPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// The 'skein' page
///
@interface IFSkeinPage : IFPage<NSSplitViewDelegate, WKNavigationDelegate>

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

-(BOOL) selectSkeinItemWithNodeId:(unsigned long) skeinItemNodeId;

@end

NS_ASSUME_NONNULL_END
