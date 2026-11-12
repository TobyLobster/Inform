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
// The kinds of line that IFCompilerOutputScanner finds in the compiler's output
//

typedef enum IFLex {
    IFLexCompilerVersion = 1,
    IFLexCompilerMessage,
    IFLexCompilerWarning,
    IFLexCompilerError,
    IFLexCompilerFatalError,

    IFLexProgress,
    IFLexEndText,
} IFLex;

#endif
