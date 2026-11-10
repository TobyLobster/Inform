//
//  IFCompilerOutputScanner.m
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//

#import "IFCompilerOutputScanner.h"
#import "IFCompilerStyles.h"

/// The scanner whose line the lexer is scanning, which the lexer's helper functions report to
static IFCompilerOutputScanner* activeScanner = nil;

@implementation IFCompilerOutputScanner

- (NSString*) styleForLine: (NSString*) line {
    activeScanner = self;
    IFLex res = IFErrorScanString([line cStringUsingEncoding:NSUTF8StringEncoding]);

    switch (res) {
        case IFLexBase:
            return IFStyleBase;

        case IFLexCompilerVersion:
            return IFStyleCompilerVersion;

        case IFLexCompilerMessage:
            return IFStyleCompilerMessage;

        case IFLexCompilerWarning:
            return IFStyleCompilerWarning;

        case IFLexCompilerError:
            return IFStyleCompilerError;

        case IFLexCompilerFatalError:
            return IFStyleCompilerFatalError;

        case IFLexAssembly:
            return IFStyleAssembly;

        case IFLexHexDump:
            return IFStyleHexDump;

        case IFLexStatistics:
            return IFStyleStatistics;

		case IFLexProgress: {
			NSString* msg = nil;

			if (IFLexLastProgressString) {
				msg = [[NSString alloc] initWithBytes: IFLexLastProgressString
											   length: strlen(IFLexLastProgressString)-2
											 encoding: NSUTF8StringEncoding];

				// (Second attempt if UTF-8 makes no sense)
				if (msg == nil) msg = [[NSString alloc] initWithBytes: IFLexLastProgressString
															   length: strlen(IFLexLastProgressString)-2
															 encoding: NSISOLatin1StringEncoding];
			}

			[self.delegate outputScanner: self
							 hasProgress: IFLexLastProgress
								 message: msg];

			return IFStyleProgress;
		}
        case IFLexEndText:
            if( IFLexEndTextString ) {
				NSString* msg;

				msg = [[NSString alloc] initWithBytes: IFLexEndTextString
											   length: strlen(IFLexEndTextString)-1
											 encoding: NSUTF8StringEncoding];

				// (Second attempt if UTF-8 makes no sense)
				if (msg == nil)
                {
                    msg = [[NSString alloc] initWithBytes: IFLexEndTextString
												   length: strlen(IFLexEndTextString)-1
												 encoding: NSISOLatin1StringEncoding];
                }

                [self.delegate outputScanner: self
                                  hasEndText: msg];
            }
            return IFStyleCompilerMessage;
    }

    return nil;
}

@end

// == The lexical helper functions, which the lexer calls ==

static NSString* memSetting = @"The memory setting ";
static NSString* exceeds = @"The story file exceeds ";
static NSString* readable = @"This program has overflowed the maximum readable-memory size of the Z-machine format.";

void IFErrorAddError(const char* filC,
					 int line,
                     IFLex type,
                     const char* mesC) {
    NSString* file    = @(filC);
    NSString* message = @(mesC);

	// Look for known error messages
	if (type == IFLexCompilerFatalError
		&& message.length > memSetting.length
		&& [[message substringToIndex: memSetting.length] isEqualToString: memSetting]) {
		[activeScanner.delegate outputScanner: activeScanner
						  overrideProblemsURL: [NSURL URLWithString: @"inform:/ErrorI6MemorySetting.html"]];
	}

	if (type == IFLexCompilerFatalError
		&& message.length > exceeds.length
		&& [[message substringToIndex: exceeds.length] isEqualToString: exceeds]) {
		[activeScanner.delegate outputScanner: activeScanner
						  overrideProblemsURL: [NSURL URLWithString: @"inform:/ErrorI6TooBig.html"]];
	}

	if ((type == IFLexCompilerFatalError || type == IFLexCompilerError)
		&& message.length > readable.length
		&& [[message substringToIndex: readable.length] isEqualToString: readable]) {
		[activeScanner.delegate outputScanner: activeScanner
						  overrideProblemsURL: [NSURL URLWithString: @"inform:/ErrorI6Readable.html"]];
	}

    // Pass the rest to the delegate
    [activeScanner.delegate outputScanner: activeScanner
                          addErrorForFile: file
                                   atLine: line
                                 withType: type
                                  message: message];
}

void IFErrorCopyBlorbTo(const char* whereTo) {
	[activeScanner.delegate outputScanner: activeScanner
							  copyBlorbTo: @(whereTo)];
}
