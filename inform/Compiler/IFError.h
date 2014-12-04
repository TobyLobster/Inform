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

typedef enum {
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

extern int IFLexLastProgress;
extern char* IFLexLastProgressString;
extern char* IFLexEndTextString;

extern int  IFErrorScanString(const char* string);				// Scans a string (presumably from the compiler) for anything that looks like an error
extern void IFErrorAddError  (const char* file,
                              int line,
                              IFLex type, // Limited to Message, Warning or Error
                              const char* message);				// (Defined in IFCompilerController.h - called whenever a new error is encountered)
extern void IFErrorCopyBlorbTo(const char* whereTo);			// (Defined in IFCompilerController.h - called when cblorb asks for a new location to store its blorb file)

#endif
