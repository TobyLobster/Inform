//
//  IFCompilerConstants.m
//  Inform
//
//  The compiler's string constants. They're declared in IFCompiler.h, and defined here,
//  as Swift can't define a constant that Objective-C sees.
//

#import "IFCompiler.h"

NSString* const IFCompilerClearConsoleNotification = @"IFCompilerClearConsoleNotification";
NSString* const IFCompilerStartingNotification     = @"IFCompilerStartingNotification";
NSString* const IFCompilerStdoutNotification       = @"IFCompilerStdoutNotification";
NSString* const IFCompilerStderrNotification       = @"IFCompilerStderrNotification";
NSString* const IFCompilerFinishedNotification     = @"IFCompilerFinishedNotification";
