//
//  IFInformProtocol.h
//  Inform
//
//  Created by Andrew Hunter on Sat Jun 05 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Inform protocol: refers to files within the Inform application bundle
/// Grr, Apple's docs on how to write these is VERY sparse and unhelpful
/// Maybe could write this as a policy delegate, but there's a header file
/// error there.
///
@interface IFInformProtocol : NSURLProtocol

@end

NS_ASSUME_NONNULL_END
