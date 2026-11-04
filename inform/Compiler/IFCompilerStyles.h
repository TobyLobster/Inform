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
extern NSString* const IFStyleBase;
extern NSString* const IFStyleLaunch;

// Basic compiler messages
extern NSString* const IFStyleCompilerVersion;
extern NSString* const IFStyleCompilerMessage;
extern NSString* const IFStyleCompilerWarning;
extern NSString* const IFStyleCompilerError;
extern NSString* const IFStyleCompilerFatalError;
extern NSString* const IFStyleProgress;

extern NSString* const IFStyleFilename;

// Compiler statistics/dumps/etc
extern NSString* const IFStyleAssembly;
extern NSString* const IFStyleHexDump;
extern NSString* const IFStyleStatistics;



NS_ASSUME_NONNULL_END

#endif /* IFCompilerStyles_h */
