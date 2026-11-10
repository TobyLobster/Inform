//
//  IFCompilerOutputScanner.h
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//

#import <Foundation/Foundation.h>
#import "IFError.h"

NS_ASSUME_NONNULL_BEGIN

@class IFCompilerOutputScanner;

///
/// What the compiler's output tells the app, as the scanner comes to it
///
@protocol IFCompilerOutputScannerDelegate <NSObject>

/// A progress line: how far through the compiler is, and the stage it has reached, if the line gives one
- (void) outputScanner: (IFCompilerOutputScanner*) scanner
           hasProgress: (int) percentage
               message: (nullable NSString*) message;

/// The line that says how the compiler ended
- (void) outputScanner: (IFCompilerOutputScanner*) scanner
            hasEndText: (NSString*) endText;

/// An error, warning or message that the compiler gave for a line of a file
- (void) outputScanner: (IFCompilerOutputScanner*) scanner
       addErrorForFile: (NSString*) file
                atLine: (int) line
              withType: (IFLex) type
               message: (NSString*) message;

/// A known error with a page of its own, to show instead of the compiler's problems page
- (void) outputScanner: (IFCompilerOutputScanner*) scanner
   overrideProblemsURL: (NSURL*) problemsURL;

/// Where cblorb asks for the blorb file to be copied
- (void) outputScanner: (IFCompilerOutputScanner*) scanner
           copyBlorbTo: (NSString*) location;

@end

///
/// Scans each line of the compiler's output with the lexer in IFError.l, for the style to show the line in and for what
/// it tells the app: progress, how the compiler ended, errors, and where to copy the blorb file.
///
@interface IFCompilerOutputScanner : NSObject

/// Told what each line says, as it's scanned
@property (atomic, weak, nullable) id<IFCompilerOutputScannerDelegate> delegate;

/// The style for a line of output, which ends with its newline, or nil to leave the line as it is
- (nullable NSString*) styleForLine: (NSString*) line;

@end

NS_ASSUME_NONNULL_END
