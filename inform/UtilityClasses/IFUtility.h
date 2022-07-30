//
//  IFUtility.h
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import <Cocoa/Cocoa.h>
#import "IFExtensionsManager.h"
#import "NSString+IFStringExtensions.h"

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))
#define DEGREES_TO_RADIANS(degrees) ((degrees) * (M_PI / 180.0))

CGFloat lerp(CGFloat progress, CGFloat from, CGFloat to);
CGFloat smoothstep(CGFloat t);
CGFloat easeOutQuad(CGFloat t);
CGFloat easeOutCubic(CGFloat t);

@interface IFUtility : NSObject

/// Unique identifier
+ (unsigned long) generateID;

// String
+ (bool) safeString:(NSString*) string1 insensitivelyEqualsSafeString:(NSString*) string2;
+ (bool) url:(NSURL*) url1 equals:(NSURL*) url2;
+ (NSString*) localizedString:(NSString*) key;
+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value NS_FORMAT_ARGUMENT(2);
+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value
                        table: (NSString*) table NS_FORMAT_ARGUMENT(2);

// Convenience methods for alerts
+ (void) runAlertInformationWindow: (NSWindow*) window
                             title: (NSString*) title
                           message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(3,4);
+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(3,4);

+ (void) runAlertWindow: (NSWindow*) window
              localized: (BOOL) alreadyLocalized
                warning: (BOOL) warningStyle
                  title: (NSString*) title
                message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(5,6);

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
                     message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(8,9);

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
                     message: (NSString*) formatString, ... NS_FORMAT_FUNCTION(9,10);

/// Show an error for an operation on an extension (e.g. error while installing an extension)
+ (void) showExtensionError: (IFExtensionResult) result
                 withWindow: (NSWindow*) window;

/// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window;

/// Sandboxing
+ (BOOL) isSandboxed;
@property (class, readonly, atomic, getter=isSandboxed) BOOL sandboxed;

/// Paths to common resources
+ (NSURL*) publicLibraryURL;

+ (NSString*) informSupportPath: (NSString *)firstString, ... NS_REQUIRES_NIL_TERMINATION;

// External directories within Application Support or Sandboxed container
+ (NSString*) pathForInformExternalAppSupport;
+ (NSString*) pathForInformExternalExtensions;
+ (NSString*) pathForInformExternalLibraries;
+ (NSString*) pathForInformExternalDocumentation;

// Internal directories within the bundle resources
/// Path to the internal Inform 7 app support
+ (NSString*) pathForInformInternalAppSupport: (NSString *)version;
/// Path to the internal Inform 7 extensions
+ (NSString*) pathForInformInternalExtensions: (NSString *)version;
/// Path to the internal Inform 7 libraries
+ (NSString*) pathForInformInternalLibraries: (NSString *)version;
/// Path to the internal Inform 7 documentation
+ (NSString*) pathForInformInternalDocumentation: (NSString *)version;

/// Path to the compiler
+ (NSString*) pathForCompiler: (NSString *)version;
/// Command line parameter name for "-format=ulx"
+ (NSString*) compilerFormatParameterName:(NSString *)version;
/// Command line parameter name for "-project" / "-package"
+ (NSString*) compilerProjectParameterName:(NSString *) version;

+ (NSString*) fullCompilerVersion: (NSString*)version;
/// Compare compiler version numbers
+ (NSComparisonResult) compilerVersionCompare: (NSString*)version1 other: (NSString*) version2;

+ (NSURL*) temporaryDirectoryURL;

/// Decode the "source:" URL scheme link
+ (NSArray*) decodeSourceSchemeURL:(NSURL*) sourceURL;

/// Decode the "skein:" URL scheme link
+ (NSArray*) decodeSkeinSchemeURL:(NSURL*) skeinURL;

// OS version checking
+ (BOOL) hasFullscreenSupportFeature;
@property (class, readonly, atomic) BOOL hasFullscreenSupportFeature;
+ (BOOL) hasScrollElasticityFeature;
@property (class, readonly, atomic) BOOL hasScrollElasticityFeature;
+ (BOOL) hasUpdatedToolbarFeature;
@property (class, readonly, atomic) BOOL hasUpdatedToolbarFeature;

+ (void) performSelector:(SEL) selector object:(id) object;

// Attributes for NSAttributedString
+(NSDictionary<NSAttributedStringKey,id>*) adjustAttributesFontSize: (NSDictionary<NSAttributedStringKey,id>*) dictionary
                                     size: (CGFloat) fontSize;
+ (NSString*) coreBuildVersion;
@property (class, readonly, copy, nonatomic) NSString *coreBuildVersion;

@end
