//
//  IFUtility.h
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import <Cocoa/Cocoa.h>
#import "IFExtensionsManager.h"
#import "NSString+IFStringExtensions.h"

@class UTType;

NS_ASSUME_NONNULL_BEGIN

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))
#define DEGREES_TO_RADIANS(degrees) ((degrees) * (M_PI / 180.0))
extern NSTimeInterval const defaultTimeoutInterval;
extern NSErrorDomain        INFORM_ERROR_DOMAIN;

CGFloat lerp(CGFloat progress, CGFloat from, CGFloat to);
CGFloat smoothstep(CGFloat t);
CGFloat smootherstep(CGFloat t);
CGFloat easeOutQuad(CGFloat t);
CGFloat easeOutCubic(CGFloat t);

@interface IFUtility : NSObject

/// Unique identifier
+ (unsigned long) generateID;

// String
+ (NSString*) localizedString:(NSString*) key;
+ (NSString*) localizedString: (NSString*) key
                      default: (nullable NSString*) value NS_FORMAT_ARGUMENT(2);
+ (NSString*) localizedString: (NSString*) key
                      default: (nullable NSString*) value
                        table: (nullable NSString*) table NS_FORMAT_ARGUMENT(2);
+ (NSString*) unescapeString: (NSString*) string;

// Convenience methods for alerts
+ (void) runAlertInformationWindow: (nullable NSWindow*) window
                             title: (NSString*) title
                           message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(3,4);
+ (void) runAlertWarningWindow: (nullable NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(3,4);

+ (void) runAlertWindow: (nullable NSWindow*) window
              localized: (BOOL) alreadyLocalized
                warning: (BOOL) warningStyle
                  title: (NSString*) title
                message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(5,6);

+ (void) runAlertYesNoWindow: (nullable NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (nullable id) modalDelegate
              didEndSelector: (nullable SEL) alertDidEndSelector
                 contextInfo: (nullable void *) contextInfo
                     message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(8,9);

+ (void) runAlertYesNoWindow: (nullable NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (nullable id) modalDelegate
              didEndSelector: (nullable SEL) alertDidEndSelector
                 contextInfo: (nullable void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
                     message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(9,10);

/// Show an error for an operation on an extension (e.g. error while installing an extension)
+ (void) showExtensionError: (IFExtensionResult) result
                 withWindow: (nullable NSWindow*) window;

/// The content types for a list of filename extensions, for open and save panels
+ (NSArray<UTType*>*) contentTypesForFilenameExtensions: (NSArray<NSString*>*) extensions;

/// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window;

+(bool) unzip: (NSURL*) zipFilepath toDirectory:(NSURL*) targetDirectory;

/// Sandboxing
+ (BOOL) isSandboxed;
@property (class, readonly, atomic, getter=isSandboxed) BOOL sandboxed;

/// Paths to common resources
+ (nullable NSURL*) publicLibraryURL;

+ (NSString*) informSupportPath: (nullable NSString *)firstString, ... NS_REQUIRES_NIL_TERMINATION;

// External directories within Application Support or Sandboxed container
+ (NSString*) pathForInformExternalAppSupport;
+ (NSString*) pathForInformExternalExtensions;
+ (NSString*) pathForInformExternalLibraries;
+ (NSString*) pathForInformExternalDocumentation;

/// The documentation page Inform writes for an extension a project uses, in the project's
/// materials folder: Extensions/Reserved/Documentation/<author>/<title>-v<version>/index.html.
/// Nil if there is none.
+ (nullable NSString*) documentationPageForExtensionTitled: (NSString*) title
                                           author: (NSString*) author
                                  inMaterialsPath: (NSString*) materialsPath;

// Internal directories within the bundle resources
/// Path to the internal Inform 7 app support
+ (NSString*) pathForInformInternalAppSupport: (NSString *)version;
/// Path to the internal Inform 7 extensions
+ (NSString*) pathForInformInternalExtensions: (NSString *)version;
/// Path to the internal Inform 7 libraries
+ (NSString*) pathForInformInternalLibraries: (NSString *)version;
/// Path to the internal Inform 7 documentation
+ (NSString*) pathForInformInternalDocumentation: (NSString *)version;
/// Path to the inform executables (ni, inbuild, intest etc)
+ (nullable NSString*) pathForInformExecutable: (NSString*) executableName version: (NSString*) compilerVersion;

/// Path to the compiler
+ (nullable NSString*) pathForCompiler: (NSString *)version;

+ (NSURL*) temporaryDirectoryURL;

// OS version checking
+ (BOOL) hasFullscreenSupportFeature;
@property (class, readonly, atomic) BOOL hasFullscreenSupportFeature;
+ (BOOL) hasScrollElasticityFeature;
@property (class, readonly, atomic) BOOL hasScrollElasticityFeature;
+ (BOOL) hasUpdatedToolbarFeature;
@property (class, readonly, atomic) BOOL hasUpdatedToolbarFeature;

+ (void) performSelector:(SEL) selector object:(nullable id) object;

// Attributes for NSAttributedString
+(NSDictionary<NSAttributedStringKey,id>*) adjustAttributesFontSize: (NSDictionary<NSAttributedStringKey,id>*) dictionary
                                     size: (CGFloat) fontSize;

// RegEx
+(nullable NSTextCheckingResult*) findMatch: (NSString*) pattern inText:(NSString*) text;

@end

@interface IFUtility (URLSchemes)

/// Decode the "source:" URL scheme link: the source file, the test case and the line number
+ (nullable NSArray*) decodeSourceSchemeURL:(NSURL*) sourceURL;

/// Decode the "skein:" URL scheme link: the test case and the node ID
+ (nullable NSArray<NSString*>*) decodeSkeinSchemeURL:(NSURL*) skeinURL;

@end

@interface IFUtility (CompilerVersions)

+(BOOL) isLatestMajorMinorCompilerVersion: (NSString*) compilerVersion;
+(BOOL) compilerVersion: (NSString*) compilerVersion isAfter: (NSString*) afterVersion;
+(BOOL) compilerVersion: (NSString*) compilerVersion isNoLaterThan: (NSString*) otherVersion;
+(NSString*) majorMinor: (NSString*) version;

/// Command line parameter name for "-format=ulx"
+ (NSString*) compilerFormatParameterName:(NSString *)version;
/// Command line parameter name for "-project" / "-package"
+ (NSString*) compilerProjectParameterName:(NSString *) version;

+ (nullable NSString*) fullCompilerVersion: (NSString*)version;
/// Compare compiler version numbers
+ (NSComparisonResult) compilerVersionCompare: (NSString*)version1 other: (NSString*) version2;

// Core build version
@property (class, readonly, copy, nonatomic, nullable) NSString *coreBuildVersion;

@end

NS_ASSUME_NONNULL_END
