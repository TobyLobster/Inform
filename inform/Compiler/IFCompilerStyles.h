//
//  IFCompilerStyles.h
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

#ifndef IFCompilerStyles_h
#define IFCompilerStyles_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Possible styles (stored in the styles dictionary)
static NSString* const IFStyleBase = @"IFStyleBase";
static NSString* const IFStyleLaunch = @"IFStyleLaunch";

// Basic compiler messages
static NSString* const IFStyleCompilerVersion = @"IFStyleCompilerVersion";
static NSString* const IFStyleCompilerMessage = @"IFStyleCompilerMessage";
static NSString* const IFStyleCompilerWarning = @"IFStyleCompilerWarning";
static NSString* const IFStyleCompilerError = @"IFStyleCompilerError";
static NSString* const IFStyleCompilerFatalError = @"IFStyleCompilerFatalError";
static NSString* const IFStyleProgress = @"IFStyleProgress";

static NSString* const IFStyleFilename = @"IFStyleFilename";

// Compiler statistics/dumps/etc
static NSString* const IFStyleAssembly = @"IFStyleAssembly";
static NSString* const IFStyleHexDump = @"IFStyleHexDump";
static NSString* const IFStyleStatistics = @"IFStyleStatistics";



NS_ASSUME_NONNULL_END

#endif /* IFCompilerStyles_h */
