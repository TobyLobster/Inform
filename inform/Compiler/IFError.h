//
//  IFError.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#ifndef __IFError_h
#define __IFError_h

//
// A flex source that scans Inform files for errors
//

typedef enum IFLex {
    IFLexBase = 1,

    IFLexCompilerVersion,
    IFLexCompilerMessage,
    IFLexCompilerWarning,
    IFLexCompilerError,
    IFLexCompilerFatalError,

    IFLexAssembly,
    IFLexHexDump,
    IFLexStatistics,
	
	IFLexProgress,
    IFLexEndText,
} IFLex;

// What the lexer found in the last line it scanned. It scans for the compiler output scanner, on the main thread,
// so Swift is told they're the main actor's.
extern int IFLexLastProgress __attribute__((swift_attr("@MainActor")));
extern char* IFLexLastProgressString __attribute__((swift_attr("@MainActor")));
extern char* IFLexEndTextString __attribute__((swift_attr("@MainActor")));

extern int  IFErrorScanString(const char* string);				// Scans a string (presumably from the compiler) for anything that looks like an error
extern void IFErrorAddError  (const char* file,
                              int line,
                              IFLex type, // Limited to Message, Warning or Error
                              const char* message);				// (Defined in IFCompilerController.h - called whenever a new error is encountered)
extern void IFErrorCopyBlorbTo(const char* whereTo);			// (Defined in IFCompilerController.h - called when cblorb asks for a new location to store its blorb file)

#endif
