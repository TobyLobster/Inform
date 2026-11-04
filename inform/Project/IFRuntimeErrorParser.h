//
//  IFRuntimeErrorParser.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlkView/GlkView.h>
#import <GlkView/GlkAutomation.h>
#import <ZoomView/ZoomView.h>

NS_ASSUME_NONNULL_BEGIN

@protocol IFRuntimeErrorParserDelegate;

///
/// Natural Inform (or Inform 7 as it's now more officially known) can produce runtime errors.
/// This class implements a Zoom output receiver that parses these out and reports them to a
/// delegate method.
///
@interface IFRuntimeErrorParser : NSObject<GlkAutomation, ZoomViewOutputReceiver>

/// Called by Zoom when output is generated
- (void) outputText: (NSString*) outputText;
/// Sets the delegate for this object. The delegate is not retained.
@property (atomic, readwrite, weak, nullable) id<IFRuntimeErrorParserDelegate> delegate;

@end

@protocol IFRuntimeErrorParserDelegate<NSObject>
@optional

/// Called when a runtime problem occurs in the output. The directory holding the problem's
/// explanation is nil if the output doesn't give one.
- (void) runtimeError: (NSString*) error inDirectory: (nullable NSString*) directory;

@end

NS_ASSUME_NONNULL_END
