//
//  IFLinkButton.h
//  Inform
//
//  Added in November 2026.
//

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

///
/// A button that acts as a link, so shows a pointing-hand cursor while the mouse is over it
///
@interface IFLinkButton : NSButton

/// Whether the button shows a pointing hand. Yes for a new button.
@property (nonatomic) BOOL showsPointingHand;

@end

NS_ASSUME_NONNULL_END
