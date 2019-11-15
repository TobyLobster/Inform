//
//  IFUtility.h
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import <Cocoa/Cocoa.h>
#import "NSString+IFStringExtensions.h"

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))
#define DEGREES_TO_RADIANS(degrees) ((degrees) * (M_PI / 180.0))

float lerp(float progress, float from, float to);
float smoothstep(float t);
float easeOutQuad(float t);
float easeOutCubic(float t);

@interface IFUtility : NSObject

// Unique identifier
+ (unsigned long) generateID;

// String
+ (bool) safeString:(NSString*) string1 insensitivelyEqualsSafeString:(NSString*) string2;
+ (bool) url:(NSURL*) url1 equals:(NSURL*) url2;
+ (NSString*) localizedString:(NSString*) key;
+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value;
+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value
                        table: (NSString*) table;

// Convenience methods for alerts
+ (void) runAlertInformationWindow: (NSWindow*) window
                             title: (NSString*) title
                           message: (NSString*) formatString, ...;
+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ...;

+ (void) runAlertWindow: (NSWindow*) window
              localized: (BOOL) alreadyLocalized
                warning: (BOOL) warningStyle
                  title: (NSString*) title
                message: (NSString*) formatString, ...;

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
                     message: (NSString*) formatString, ...;

// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window;

// Sandboxing
+ (BOOL) isSandboxed;

// Paths to common resources
+ (NSURL*) publicLibraryURL;

+ (NSString*) informSupportPath: (NSString *)firstString, ... NS_REQUIRES_NIL_TERMINATION;

// External directories within Application Support or Sandboxed container
+ (NSString*) pathForInformExternalAppSupport;
+ (NSString*) pathForInformExternalExtensions;
+ (NSString*) pathForInformExternalLibraries;
+ (NSString*) pathForInformExternalDocumentation;

// Internal directories within the bundle resources
+ (NSString*) pathForInformInternalAppSupport: (NSString *)version;          // Path to the internal Inform 7 app support
+ (NSString*) pathForInformInternalExtensions: (NSString *)version;          // Path to the internal Inform 7 extensions
+ (NSString*) pathForInformInternalLibraries: (NSString *)version;           // Path to the internal Inform 7 libraries
+ (NSString*) pathForInformInternalDocumentation: (NSString *)version;       // Path to the internal Inform 7 documentation

+ (NSString*) pathForCompiler: (NSString *)version;                          // Path to the compiler
+ (NSString*) compilerFormatParameterName:(NSString *)version;               // Command line parameter name for "-format=ulx"
+ (NSString*) compilerProjectParameterName:(NSString *) version;             // Command line parameter name for "-project" / "-package"

+ (NSString*) fullCompilerVersion: (NSString*)version;
+ (NSComparisonResult) compilerVersionCompare: (NSString*)version1 other: (NSString*) version2; // Compare compiler version numbers

+ (NSURL*) temporaryDirectoryURL;

// Decode the "source:" URL scheme link
+ (NSArray*) decodeSourceSchemeURL:(NSURL*) sourceURL;

// Decode the "skein:" URL scheme link
+ (NSArray*) decodeSkeinSchemeURL:(NSURL*) skeinURL;

// OS version checking
+ (BOOL) hasFullscreenSupportFeature;
+ (BOOL) hasScrollElasticityFeature;
+ (BOOL) hasUpdatedToolbarFeature;

+ (void) performSelector:(SEL) selector object:(id) object;

// Attributes for NSAttributedString
+(NSDictionary*) adjustAttributesFontSize: (NSDictionary*) dictionary
                                     size: (float) fontSize;
+ (NSString*) coreBuildVersion;

@end
