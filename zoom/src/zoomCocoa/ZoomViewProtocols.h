//
//  ZoomViewProtocols.h
//  ZoomView
//
//  Created by C.W. Betts on 12/5/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ZoomView input/output receivers
//! ZoomView output receiver
@protocol ZoomViewOutputReceiver <NSObject>
@optional

// Direct output
- (void) inputCommand:   (NSString*) command;
- (void) inputCharacter: (NSString*) character;
- (void) outputText:     (NSString*) outputText;

// Status notifications
- (void) zoomWaitingForInput;
- (void) zoomInterpreterRestart;

@end

//! ZoomView input receiver
@protocol ZoomViewInputSource <NSObject>
@optional

//! Retrieve the next command
- (nullable NSString*) nextCommand;

//! Return \c YES if you want to turn off \b More... prompts
@property (nonatomic, readonly) BOOL disableMorePrompt;

@end

NS_ASSUME_NONNULL_END
