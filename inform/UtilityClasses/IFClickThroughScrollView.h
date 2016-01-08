//
//  IFClickThroughScrollView.h
//  Inform
//
//  Created by Andrew Hunter on 06/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>


///
/// NSScrollView subclass that is designed to work around a boneheaded limitation due to the field
/// editor system, namely that you can't get clicks outside of the text container for text views 
/// where the field editor is active.
///
@interface IFClickThroughScrollView : NSScrollView {

}

@end
