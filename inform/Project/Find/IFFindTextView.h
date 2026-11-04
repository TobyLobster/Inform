//
//  IFFindTextView.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFFindController.h"

NS_ASSUME_NONNULL_BEGIN

///
/// NSTextView category that supports the new find dialog
///
@interface NSTextView(IFFindTextView) <IFFindDelegate>
@end

NS_ASSUME_NONNULL_END
