//
//  IFProjectTypes.h
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFNaturalIntel.h"

extern NSNotificationName const IFProjectFilesChangedNotification;
extern NSNotificationName const IFProjectBreakpointsChangedNotification;
extern NSNotificationName const IFProjectSourceFileRenamedNotification;

typedef NS_ENUM(unsigned int, IFInformVersion) {
    IFInformVersion6,
    IFInformVersion7,
    IFInformVersionUnknown
};

typedef NS_ENUM(unsigned int, IFFileType) {
    IFFileTypeUnknown,
    
    IFFileTypeInform7Project,
    IFFileTypeInform7ExtensionProject,
    IFFileTypeInform7SourceFile,
    IFFileTypeInform7ExtensionFile,
    
    IFFileTypeInform6ExtensionProject,
    IFFileTypeInform6SourceFile,
    IFFileTypeInform6ICLFile,
};

typedef NS_ENUM(unsigned int, IFLineStyle) {
    IFLineStyleNeutral = 0,

    // Temporary highlights
    IFLineStyle_Temporary = 1,  // Dummy style

    IFLineStyleWarning = 1,     // Temp highlight
    IFLineStyleError,           // Temp highlight
    IFLineStyleFatalError,      // Temp highlight
    IFLineStyleHighlight,       // Temp highlight

    IFLineStyle_LastTemporary,

    // 'Permanent highlights'
    IFLineStyle_Permanent = 0xfff, // Dummy style
};



@interface IFProjectTypes : NSObject

+ (NSStringEncoding) encodingForFilename: (NSString*) filename;
+ (IFInformVersion) informVersionForFilename: (NSString*) filename;
+ (IFHighlightType) highlighterTypeForFilename: (NSString*) filename;
+ (id<IFSyntaxIntelligence>) intelligenceForFilename: (NSString*) filename;

+ (IFFileType) fileTypeFromString: (NSString*) typeName;

@end
