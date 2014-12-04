//
//  IFProjectTypes.h
//  Inform
//
//  Created by Andrew Hunter on Wed Aug 27 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "IFNaturalIntel.h"

extern NSString* IFProjectFilesChangedNotification;
extern NSString* IFProjectWatchExpressionsChangedNotification;
extern NSString* IFProjectBreakpointsChangedNotification;
extern NSString* IFProjectSourceFileRenamedNotification;
extern NSString* IFProjectSourceFileDeletedNotification;
extern NSString* IFProjectStartedBuildingSyntaxNotification;
extern NSString* IFProjectFinishedBuildingSyntaxNotification;

typedef enum {
    IFInformVersion6,
    IFInformVersion7,
    IFInformVersionUnknown
} IFInformVersion;

typedef enum {
    IFFileTypeUnknown,
    
    IFFileTypeInform7Project,
    IFFileTypeInform7SourceFile,
    IFFileTypeInform7ExtensionFile,
    
    IFFileTypeInform6ExtensionProject,
    IFFileTypeInform6SourceFile,
    IFFileTypeInform6ICLFile,
} IFFileType;

@interface IFProjectTypes : NSObject  {
}

+(NSStringEncoding) encodingForFilename: (NSString*) filename;
+(IFInformVersion) informVersionForFilename: (NSString*) filename;
+(IFHighlightType) highlighterTypeForFilename: (NSString*) filename;
+ (id<IFSyntaxIntelligence,NSObject>) intelligenceForFilename: (NSString*) filename;

+(IFFileType) fileTypeFromString: (NSString*) typeName;

@end
