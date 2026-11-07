//
//  IFInformProtocol.h
//  Inform
//
//  Created by Andrew Hunter on Sat Jun 05 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Inform protocol: refers to files within the Inform application bundle, or in
/// Inform's documentation folder for an extensions URL. It answers for Foundation's
/// URL loading, as when the welcome window and the skein page read their templates.
/// Web views don't ask an NSURLProtocol; IFWebViewHelper and IFNewsCustomSchemeHandler
/// answer theirs.
///
@interface IFInformProtocol : NSURLProtocol

@end

NS_ASSUME_NONNULL_END
