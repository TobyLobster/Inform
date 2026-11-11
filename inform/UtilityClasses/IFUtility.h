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

static NSErrorDomain const INFORM_ERROR_DOMAIN = @"com.inform7.errors";

CGFloat lerp(CGFloat progress, CGFloat from, CGFloat to);
CGFloat easeOutCubic(CGFloat t);

@interface IFUtility : NSObject

/// When the app is hosting the unit tests, it skips start-up work that would touch the user's Inform
/// (the Glk hub's name), their extensions (the census) or the screen (the welcome window), doesn't
/// run an alert that has no window, and keeps the website data of `IFWebViewHelper`'s web views in memory.
@property (class, readonly, atomic, getter=isHostingUnitTests) BOOL hostingUnitTests;

/// Xcode starts the test host again after it crashes, to run the tests that are left, but doesn't run the scheme's
/// pre-action that removes the tests' home folder (CFFIXED_USER_HOME). A host started with that folder there has
/// the user's preferences, as they're first read before any of the app's code runs (by ZoomView's
/// `+[ZoomSkeinLayout load]`), so `main` stops it, and the tests that were left aren't run.
+ (void) stopTestHostWithLeftoverHome;
/// Whether the environment is a test host's whose home folder is there, as it is for `main` after a crash
+ (BOOL) isTestHostWithLeftoverHomeInEnvironment: (NSDictionary<NSString*, NSString*>*) environment;

// Convenience methods for alerts
/// An informational alert with an OK button, its title looked up in the localised strings and its text as it is
+ (void) runAlertInformationWindow: (nullable NSWindow*) window
                             title: (NSString*) title
                   informativeText: (NSString*) text NS_SWIFT_UI_ACTOR;
/// The same, as a warning
+ (void) runAlertWarningWindow: (nullable NSWindow*) window
                         title: (NSString*) title
               informativeText: (NSString*) text NS_SWIFT_UI_ACTOR;
/// A warning whose title is already localised
+ (void) runAlertWarningWindow: (nullable NSWindow*) window
                localizedTitle: (NSString*) title
               informativeText: (NSString*) text NS_SWIFT_UI_ACTOR;

/// Shows the alert in a sheet on the window, or with no window runs it app-modally. While the app is
/// hosting the unit tests an alert with no window is only logged, and ends at once with NSModalResponseAbort.
+ (void) showAlert: (NSAlert*) alert
         forWindow: (nullable NSWindow*) window
 completionHandler: (void (NS_SWIFT_UI_ACTOR ^)(NSModalResponse response)) handler NS_SWIFT_UI_ACTOR;

/// Begins the save panel in a sheet on the window, or with no window as an app-modal panel that doesn't wait,
/// which is what AppKit makes of a sheet on no window. For Swift, which can't begin a sheet on no window.
+ (void) beginSavePanel: (NSSavePanel*) panel
              forWindow: (nullable NSWindow*) window
      completionHandler: (void (NS_SWIFT_UI_ACTOR ^)(NSModalResponse result)) handler NS_SWIFT_UI_ACTOR;

/// An alert asking yes or no, with its title, buttons and text as they're given. When it ends, the delegate is sent
/// the selector, if both are given, with the window, the response and the context.
+ (void) runAlertYesNoWindow: (nullable NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (nullable id) modalDelegate
              didEndSelector: (nullable SEL) alertDidEndSelector
                 contextInfo: (nullable void *) contextInfo
             informativeText: (NSString*) text NS_SWIFT_UI_ACTOR;
/// The same, with the button at the index given (0 or 1) marked as destructive
+ (void) runAlertYesNoWindow: (nullable NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (nullable id) modalDelegate
              didEndSelector: (nullable SEL) alertDidEndSelector
                 contextInfo: (nullable void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
             informativeText: (NSString*) text NS_SWIFT_UI_ACTOR;

/// Show an error for an operation on an extension (e.g. error while installing an extension)
+ (void) showExtensionError: (IFExtensionResult) result
                 withWindow: (nullable NSWindow*) window NS_SWIFT_UI_ACTOR;

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

@interface IFUtility (Paths)

/// Paths to common resources
+ (nullable NSURL*) publicLibraryURL NS_SWIFT_UI_ACTOR;

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
+ (NSString*) pathForInformInternalAppSupport: (NSString *)version NS_SWIFT_UI_ACTOR;
/// Path to the internal Inform 7 extensions
+ (NSString*) pathForInformInternalExtensions: (NSString *)version NS_SWIFT_UI_ACTOR;
/// Path to the internal Inform 7 libraries
+ (NSString*) pathForInformInternalLibraries: (NSString *)version NS_SWIFT_UI_ACTOR;
/// Path to the internal Inform 7 documentation
+ (NSString*) pathForInformInternalDocumentation: (NSString *)version NS_SWIFT_UI_ACTOR;
/// Path to the inform executables (ni, inbuild, intest etc)
+ (nullable NSString*) pathForInformExecutable: (NSString*) executableName
                                       version: (NSString*) compilerVersion NS_SWIFT_UI_ACTOR;

/// Path to the compiler
+ (nullable NSString*) pathForCompiler: (NSString *)version NS_SWIFT_UI_ACTOR;

+ (NSURL*) temporaryDirectoryURL;

@end

@interface IFUtility (Strings)

// String
+ (NSString*) localizedString:(NSString*) key;
+ (NSString*) localizedString: (NSString*) key
                      default: (nullable NSString*) value NS_FORMAT_ARGUMENT(2);
+ (NSString*) localizedString: (NSString*) key
                      default: (nullable NSString*) value
                        table: (nullable NSString*) table NS_FORMAT_ARGUMENT(2);
+ (NSString*) unescapeString: (NSString*) string;

// RegEx
+(nullable NSTextCheckingResult*) findMatch: (NSString*) pattern inText:(NSString*) text;

@end

@interface IFUtility (Miscellaneous)

/// Unique identifier
+ (unsigned long) generateID;

/// The content types for a list of filename extensions, for open and save panels
+ (NSArray<UTType*>*) contentTypesForFilenameExtensions: (NSArray<NSString*>*) extensions;

/// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window NS_SWIFT_UI_ACTOR;

+(bool) unzip: (NSURL*) zipFilepath toDirectory:(NSURL*) targetDirectory;

/// Sandboxing
@property (class, readonly, atomic, getter=isSandboxed) BOOL sandboxed;

+ (void) performSelector:(SEL) selector object:(nullable id) object;

// Attributes for NSAttributedString
+(NSDictionary<NSAttributedStringKey,id>*) adjustAttributesFontSize: (NSDictionary<NSAttributedStringKey,id>*) dictionary
                                     size: (CGFloat) fontSize;

@end

NS_ASSUME_NONNULL_END
