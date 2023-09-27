//
//  IFUtility.m
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import "IFUtility.h"
#import "IFPreferences.h"
#import "NSString+IFStringExtensions.h"
#import <Foundation/NSCache.h>
#import <objc/objc-runtime.h>

static NSLock*       uniqueIdLock;
static unsigned long uniqueId = 1000;
static NSURL*        temporaryFolder = nil;
NSTimeInterval const defaultTimeoutInterval = 60.0;
NSErrorDomain        INFORM_ERROR_DOMAIN = @"com.inform7.errors";


CGFloat lerp(CGFloat progress, CGFloat from, CGFloat to) {
    return from + progress * (to - from);
}

CGFloat smoothstep(CGFloat t) {
    // https://en.wikipedia.org/wiki/Smoothstep
    return t*t*(3-2*t);
}

CGFloat smootherstep(CGFloat t) {
    // https://en.wikipedia.org/wiki/Smoothstep#Variations
    return t*t*t*(10+3*t*(2*t-5));
}

CGFloat easeOutQuad(CGFloat t) {
    return t*(2-t);
};

CGFloat easeOutCubic(CGFloat t) {
    t--;
    return t*t*t + 1;
};

@implementation NSString (VersionNumbers)
- (NSString *)shortenedVersionNumberString {
    static NSString *const unnecessaryVersionSuffix = @".0";
    NSString *shortenedVersionNumber = self;

    while ([shortenedVersionNumber hasSuffix:unnecessaryVersionSuffix]) {
        shortenedVersionNumber = [shortenedVersionNumber substringToIndex:shortenedVersionNumber.length - unnecessaryVersionSuffix.length];
    }

    return shortenedVersionNumber;
}
@end

#pragma mark - "IFUtility"
@implementation IFUtility

#pragma mark -  Initialisation
+ (void) initialize {
    uniqueIdLock = [[NSLock alloc] init];
}

#pragma mark - Generating unique IDs
+ (unsigned long) generateID {
    unsigned long new_id;
    [uniqueIdLock lock];
    new_id = uniqueId++;
    [uniqueIdLock unlock];
    return new_id;
}

#pragma mark - String handling
// Are the strings equal, where the strings may be nil...
+ (bool) safeString:(NSString*) string1 insensitivelyEqualsSafeString:(NSString*) string2 {
    if(( string1 == nil ) || ( string2 == nil )) {
        return (string1 == string2);
    }
    return ([string1 caseInsensitiveCompare: string2] == NSOrderedSame);
}

+(bool) url: (NSURL*) url1
     equals: (NSURL*) url2 {
    bool sameScheme = [IFUtility safeString: url1.scheme
              insensitivelyEqualsSafeString: url2.scheme];
    bool samePath   = [IFUtility safeString: url1.path
              insensitivelyEqualsSafeString: url2.path];
    bool sameQuery  = [IFUtility safeString: url1.query
              insensitivelyEqualsSafeString: url2.query];
    return sameScheme && samePath && sameQuery;
}

+ (NSString*) localizedString: (NSString*) key {
    return [[NSBundle mainBundle] localizedStringForKey: key
                                                  value: key
                                                  table: nil];
}

+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value {
    return [[NSBundle mainBundle] localizedStringForKey: key
                                                  value: value
                                                  table: nil];
}

+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value
                        table: (NSString*) table {
    return [[NSBundle mainBundle] localizedStringForKey: key
                                                  value: value
                                                  table: table];
}

#pragma mark - URL scheme parsing
+ (NSDictionary*) queryParametersFromURL:(NSURL*) sourceURL {
    NSMutableDictionary* results = [[NSMutableDictionary alloc] init];

    NSString* path = sourceURL.resourceSpecifier.stringByRemovingPercentEncoding;
    NSArray* query = [path componentsSeparatedByString: @"?"];
    if( query.count < 2 ) {
        return results;
    }
    query = [query[1] componentsSeparatedByString:@"#"];

    NSArray* keyValues = [query[0] componentsSeparatedByString: @"="];

    for( NSInteger i = 0; i < (keyValues.count-1); i += 2 ) {
        results[keyValues[i]] = keyValues[i+1];
    }
    return results;
}

+ (NSString*) fragmentFromURL:(NSURL*) sourceURL {
    NSString* path = sourceURL.resourceSpecifier.stringByRemovingPercentEncoding;
    NSArray* array = [path componentsSeparatedByString:@"#"];
    if( array.count < 2 ) {
        return @"";
    }
    return array[1];
}

+ (NSString*) heirarchyFromURL:(NSURL*) sourceURL {
    NSString* path = sourceURL.resourceSpecifier.stringByRemovingPercentEncoding;
    NSInteger query  = [path indexOf:@"?"];
    NSInteger hash   = [path indexOf:@"#"];
    NSInteger result = path.length;
    if( query != NSNotFound ) result = MIN(result, query);
    if( hash  != NSNotFound ) result = MIN(result, hash);

    return [path substringToIndex: result];
}

+ (NSArray*) decodeSourceSchemeURL:(NSURL*) sourceURL {
    NSString* path = sourceURL.resourceSpecifier.stringByRemovingPercentEncoding;

    // Get line number from fragment
    NSString* fragment = [IFUtility fragmentFromURL: sourceURL];
    if (fragment.length == 0) {
        NSLog(@"Bad source URL, no fragment: %@", path);
        return @[];
    }

    // sourceLine can have format 'line10' or '10'. 'line10' is more likely
    int lineNumber = fragment.intValue;

    if (lineNumber == 0 && [[fragment substringToIndex: 4] isEqualToString: @"line"]) {
        lineNumber = [fragment substringFromIndex: 4].intValue;
    }

    // Get source filename
    NSString* sourceFile = [IFUtility heirarchyFromURL: sourceURL];
    if( sourceFile == nil ) {
        return nil;
    }

    // Get test case from query parameters
    NSDictionary * parameters = [IFUtility queryParametersFromURL: sourceURL];
    NSString* testCase = parameters[@"case"];
    if( testCase == nil ) testCase = @"";

    return @[sourceFile, testCase, @(lineNumber)];
}

+ (NSArray*) decodeSkeinSchemeURL:(NSURL*) skeinURL {
    // e.g: Input 'skein:1003?case=B' returns [B,1003]

    if( ![skeinURL.scheme isEqualToStringCaseInsensitive: @"skein"] )
    {
        return nil;
    }

    // Get node id from heirarchy
    NSString* nodeIdString = [IFUtility heirarchyFromURL: skeinURL];

    // Get test case from query parameters
    NSDictionary * parameters = [IFUtility queryParametersFromURL: skeinURL];
    NSString* testCase = parameters[@"case"];
    if( testCase == nil ) testCase = @"";

    return @[testCase, nodeIdString];
}

#pragma mark - Alert dialogs
+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);
    
    [[self class] runAlertWindow: window
                       localized: NO
                         warning: YES
                           title: [self localizedString: title]
                         message: @"%@", contents];
}

+ (void) runAlertInformationWindow: (NSWindow*) window
                             title: (NSString*) title
                           message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);
    
    [[self class] runAlertWindow: window
                       localized: NO
                         warning: NO
                           title: [self localizedString: title]
                         message: @"%@", contents];
}


+ (void) runAlertWindow: (NSWindow*) window
              localized: (BOOL) alreadyLocalized
                warning: (BOOL) warningStyle
                  title: (NSString*) title
                message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: alreadyLocalized ? formatString : [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  [self localizedString: @"OK"]];
    alert.messageText = alreadyLocalized ? title : [self localizedString: title];
    alert.informativeText = contents;
    alert.alertStyle = warningStyle ? NSAlertStyleWarning : NSAlertStyleInformational;

    [alert beginSheetModalForWindow: window completionHandler:^(NSModalResponse returnCode) {
        
    }];
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
                     message: (NSString*) formatString
                        args: (va_list) args {
    NSString* contents = [[NSString alloc] initWithFormat: formatString
                                                 arguments: args];

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  yes];
    [alert addButtonWithTitle:  no];
    alert.messageText = title;
    alert.informativeText = contents;
    alert.alertStyle = NSAlertStyleInformational;
    if (@available(macOS 11.0, *)) {
        switch (desIdx) {
            case NSNotFound:
                // do nothing
                break;
                
            case 0:
            case 1:
                alert.buttons[desIdx].hasDestructiveAction = YES;
                
            default:
                break;
        }
    }

    if (window == nil) {
        NSModalResponse response = [alert runModal];
        [self modalYesNoResponse: response
                          window: window
                   modalDelegate: modalDelegate
                  didEndSelector: alertDidEndSelector
                     contextInfo: contextInfo];
    }

    [alert beginSheetModalForWindow: window completionHandler: ^(NSModalResponse response) {
        [self modalYesNoResponse: response
                          window: window
                   modalDelegate: modalDelegate
                  didEndSelector: alertDidEndSelector
                     contextInfo: contextInfo];
    }];
}

+ (void) modalYesNoResponse: (NSModalResponse) returnCode
                     window: (NSWindow*) window
              modalDelegate: (id) modalDelegate
             didEndSelector: (SEL) alertDidEndSelector
                contextInfo: (void *) contextInfo {
    if (!modalDelegate || !alertDidEndSelector) {
        return;
    }
#if 0
    NSMethodSignature * methodSignature = [[modalDelegate class]
                                    instanceMethodSignatureForSelector: alertDidEndSelector];
    NSInvocation * delegateInvocation = [NSInvocation
                                   invocationWithMethodSignature:methodSignature];

    [delegateInvocation setArgument:(void*)&window atIndex:2];
    [delegateInvocation setArgument:&returnCode atIndex:3];
    [delegateInvocation setArgument:(void*)&contextInfo atIndex:4];
    [delegateInvocation invoke];
#else
    // Hack!
    IMP imp = [modalDelegate methodForSelector: alertDidEndSelector];
    void (*func)(id, SEL, NSWindow*, NSInteger, void *) = (void *) imp;
    func(modalDelegate, alertDidEndSelector, window, returnCode, contextInfo);
#endif
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
                     message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    [self runAlertYesNoWindow:window
                        title:title
                          yes:yes
                           no:no
                modalDelegate:modalDelegate
               didEndSelector:alertDidEndSelector
                  contextInfo:contextInfo
             destructiveIndex:NSNotFound
                      message:formatString
                         args:args];
    va_end(args);
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
            destructiveIndex: (NSInteger) desIdx
                     message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    [self runAlertYesNoWindow:window
                        title:title
                          yes:yes
                           no:no
                modalDelegate:modalDelegate
               didEndSelector:alertDidEndSelector
                  contextInfo:contextInfo
             destructiveIndex:desIdx
                      message:formatString
                         args:args];
    va_end(args);
}

+ (void) showExtensionError: (IFExtensionResult) result
                 withWindow: (NSWindow*) window {
    // TODO: Do we want to customise the error message depending on the IFExtensionResult?
    switch (result) {
        case IFExtensionNotFound:
            break;
        case IFExtensionNotValid:
            break;
        case IFExtensionAlreadyExists:
            break;
        case IFExtensionCantWriteDestination:
            break;
        case IFExtensionSuccess:
        default:
            return;
    }
    [IFUtility runAlertWarningWindow: window
                               title: @"Failed to Install Extension"
                             message: @"Failed to Install Extension Explanation"];
}

// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window {

    NSSavePanel* panel = [NSSavePanel savePanel];

    panel.allowedFileTypes = @[@"txt"];

    // Work out starting directory
    NSString*   prefString   = [[NSUserDefaults standardUserDefaults] objectForKey: @"IFTranscriptURL"];
    NSURL*      directoryURL = [NSURL URLWithString: prefString];
    if (directoryURL == nil) {
        directoryURL = [NSURL fileURLWithPath: NSHomeDirectory()];
    }

    panel.directoryURL = directoryURL;

    // Show it
    [panel beginSheetModalForWindow: window completionHandler:^(NSInteger returnCode)
     {
         if (returnCode != NSModalResponseOK) return;

         // Remember the directory we last saved into
         if ( panel.directoryURL.absoluteString != nil ) {
             NSString* writePrefString = panel.directoryURL.absoluteString;
             [[NSUserDefaults standardUserDefaults] setObject: writePrefString
                                                       forKey: @"IFTranscriptURL"];
         }

         // Save the data
         NSData* stringData = [string dataUsingEncoding: NSUTF8StringEncoding];
         [stringData writeToURL: panel.URL
                     atomically: YES];
     }];
}


#pragma mark - Sandboxing
+ (BOOL) isSandboxed {
    NSDictionary* environ = [NSProcessInfo processInfo].environment;
    return (nil != environ[@"APP_SANDBOX_CONTAINER_ID"]);
}

#pragma mark - Getting useful paths / URLs
+(NSURL*) publicLibraryURL {
#ifdef DEBUG
    NSString* redirectFile = [NSHomeDirectory() stringByAppendingPathComponent:@"redirect_inform.txt"];
    NSString* redirection = [NSString stringWithContentsOfFile: redirectFile
                                                       encoding: NSUTF8StringEncoding
                                                          error: NULL].stringByTrimmingWhitespace;
    if (redirection.length > 0) {
        return [NSURL URLWithString: redirection];
    }
#endif

    if( [IFPreferences sharedPreferences].publicLibraryDebug && ![IFUtility isSandboxed]) {
        NSString* publicLibraryURLString;
        publicLibraryURLString = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        publicLibraryURLString = [publicLibraryURLString stringByAppendingPathComponent:@"InformPublicLibrary"];
        publicLibraryURLString = [publicLibraryURLString stringByAppendingPathComponent:@"index.html"];
        return [NSURL fileURLWithPath: publicLibraryURLString];
    }
    return [NSURL URLWithString: [IFUtility localizedString: @"PublicLibraryURL"]];
}

+ (NSString*) informSupportPath: (NSString *)firstArg, ... {
    // Get library directory (possibly in a sandboxed container).
    NSString *newPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];

    // Add inform subdirectory
    newPath = [newPath stringByAppendingPathComponent:@"Inform"];

    // Add any additional subdirectories
    va_list args;
    va_start(args, firstArg);
    for (NSString *arg = firstArg; arg != nil; arg = va_arg(args, NSString*))
    {
        newPath = [newPath stringByAppendingPathComponent: arg];
    }
    va_end(args);

    // Return path
    return newPath;
}

+ (NSString*) pathForInformExternalAppSupport {
    return [self informSupportPath: nil, nil];
}

+ (NSString*) pathForInformExternalExtensions {
    return [IFUtility informSupportPath: @"Extensions", nil];
}

+ (NSString*) pathForInformExternalLibraries {
    return [IFUtility informSupportPath: @"Libraries", nil];
}

+ (NSString*) pathForInformExternalDocumentation {
    return [IFUtility informSupportPath: @"Documentation", nil];
}

+(BOOL) isLatestMajorMinorCompilerVersion: (NSString*) compilerVersion {
    NSString* version = [IFUtility fullCompilerVersion: compilerVersion];
    NSString* currentVersion = [IFUtility coreBuildVersion];

    // If version wanted is equal to the current version, use the current version
    if ([version isEqualToStringCaseInsensitive:currentVersion])
    {
        return TRUE;
    }
    // If version wanted is equal to the 'major.minor' of the current version, good enough, use the current version
    NSString* currentMajorMinor = [IFUtility majorMinor: currentVersion];
    if ([version isEqualToString:currentMajorMinor])
    {
        return TRUE;
    }
    return FALSE;
}

+(BOOL) compilerVersion: (NSString*) compilerVersion isAfter: (NSString*) afterVersion {
    return [IFUtility compilerVersionCompare: compilerVersion other: afterVersion] == NSOrderedDescending;
}

+(BOOL) compilerVersion: (NSString*) compilerVersion isNoLaterThan: (NSString*) otherVersion {
    return [IFUtility compilerVersion: otherVersion isAfter: compilerVersion];
}

+ (NSString*) fullCompilerVersion: (NSString*)version
{
    if ([version isEqualToStringCaseInsensitive: @""] ||
        [version isEqualToStringCaseInsensitive: @"****"])
    {
        return [IFUtility coreBuildVersion];
    }
    return version;
}

+ (NSString*) pathForCompiler: (NSString *)compilerVersion
{
    // Older versions of compiler
    if ([IFUtility compilerVersion: compilerVersion isNoLaterThan: @"6M62"]) {
        NSString* executablePath = [NSBundle mainBundle].executablePath.stringByDeletingLastPathComponent;
        NSString* version = [IFUtility fullCompilerVersion: compilerVersion];
        return [[executablePath stringByAppendingPathComponent: version] stringByAppendingPathComponent: @"ni"];
    }
    // Newer versions of compiler
    return [IFUtility pathForInformExecutable: @"ni" version: compilerVersion];
}

+ (NSString*) pathForInformInternalAppSupport: (NSString *)compilerVersion
{
    NSString* resourcePath = [NSBundle mainBundle].resourcePath;
    if ([IFUtility isLatestMajorMinorCompilerVersion: compilerVersion]) {
        // If using external Inform Core 'Internal' data...
        if ([IFPreferences sharedPreferences].useExternalInformCoreDirectory) {
            NSString* informCore = [IFPreferences sharedPreferences].externalInformCoreDirectory;
            return [[informCore stringByAppendingPathComponent:@"inform7"] stringByAppendingPathComponent: @"Internal"];
        }
        return [resourcePath stringByAppendingPathComponent: @"Internal"];
    }
    NSString* version = [IFUtility fullCompilerVersion: compilerVersion];
    return [[resourcePath stringByAppendingPathComponent: @"retrospective"] stringByAppendingPathComponent: version];
}

+ (NSString*) pathForInformExecutable: (NSString*) executableName
                              version: (NSString*) compilerVersion
{
    if ([IFUtility isLatestMajorMinorCompilerVersion: compilerVersion]) {
        if ([IFPreferences sharedPreferences].useExternalInformCoreDirectory) {
            // Use external locations for executables
            NSString* informCore = [IFPreferences sharedPreferences].externalInformCoreDirectory;

            if ([executableName isEqualToStringCaseInsensitive:@"ni"]) {
                return [informCore stringByAppendingPathComponents: @"inform7/Tangled/inform7"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"inform7"]) {
                return [informCore stringByAppendingPathComponents: @"inform7/Tangled/inform7"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"cBlorb"]) {
                return [informCore stringByAppendingPathComponents: @"inblorb/Tangled/inblorb"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"inbuild"]) {
                return [informCore stringByAppendingPathComponents: @"inbuild/Tangled/inbuild"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"inform6"]) {
                return [informCore stringByAppendingPathComponents: @"inform6/Tangled/inform6"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"intest"]) {
                // NOTE: This is outside the 'Inform Core' directory (alongside it)
                return [informCore stringByAppendingPathComponents: @"../intest/Tangled/intest"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"glulxe"]) {
                return [informCore stringByAppendingPathComponents: @"inform6/Tests/Assistants/dumb-glulx/glulxe/glulxe"];
            }
            if ([executableName isEqualToStringCaseInsensitive:@"dumb-frotz"]) {
                return [informCore stringByAppendingPathComponents: @"inform6/Tests/Assistants/dumb-frotz/dumb-frotz"];
            }

            // Anything else falls through...
        }
    }
    return [[NSBundle mainBundle] pathForAuxiliaryExecutable: executableName];
}

+ (NSComparisonResult) compilerVersionCompare: (NSString*) version1
                                        other: (NSString*) version2
{
    version1 = [[self class] fullCompilerVersion: version1];
    version2 = [[self class] fullCompilerVersion: version2];

    BOOL isV1Dotted = [version1 containsSubstring: @"."];
    BOOL isV2Dotted = [version2 containsSubstring: @"."];

    // One version is dotted, the other not
    if (isV1Dotted != isV2Dotted) {
        if (isV1Dotted) {
            return NSOrderedDescending;
        }
        return NSOrderedAscending;
    }

    if (isV1Dotted) {
        // Both versions are dotted, we use numerical search compare after removing any trailing ".0"s so that "1" = "1.0" = "1.0.0"
        return [[version1 shortenedVersionNumberString] compare:[version2 shortenedVersionNumberString] options:NSNumericSearch];
    }

    // Neither version is dotted, use regular string compare
    return [version1 compare:version2 options: NSCaseInsensitiveSearch];
}

+ (NSString*) compilerFormatParameterName:(NSString *)version
{
    NSComparisonResult result = [IFUtility compilerVersionCompare: version other:@"6L02"];

    if(result != NSOrderedDescending)
    {
        // Old
        return @"extension";
    }
    // New
    return @"format";
}

+ (NSString*) compilerProjectParameterName:(NSString *) version
{
    NSComparisonResult result = [IFUtility compilerVersionCompare: version other:@"6L02"];

    if(result != NSOrderedDescending)
    {
        // Old
        return @"package";
    }
    // New
    return @"project";
}

+ (NSString*) pathForInformInternalExtensions: (NSString *)version {
    return [[IFUtility pathForInformInternalAppSupport:version] stringByAppendingPathComponent:@"Extensions"];
}

+ (NSString*) pathForInformInternalLibraries: (NSString *)version {
    return [[IFUtility pathForInformInternalAppSupport:version] stringByAppendingPathComponent:@"Libraries"];
}

+ (NSString*) pathForInformInternalDocumentation: (NSString *)version {
    return [[IFUtility pathForInformInternalAppSupport:version] stringByAppendingPathComponent:@"Documentation"];
}

+(NSURL*) temporaryDirectoryURL {
    if( temporaryFolder == nil ) {
        NSError* error;
        temporaryFolder = [[NSURL fileURLWithPath: NSTemporaryDirectory()] URLByAppendingPathComponent: [NSProcessInfo processInfo].globallyUniqueString isDirectory: YES];
        [[NSFileManager defaultManager] createDirectoryAtURL: temporaryFolder
                                 withIntermediateDirectories: YES
                                                  attributes: nil
                                                       error: &error];
    }
    return temporaryFolder;
}

+(BOOL) hasFullscreenSupportFeature {
    // Lion (10.7) introduced fullscreen support
    return NSAppKitVersionNumber >= NSAppKitVersionNumber10_7;
}

+(BOOL) hasScrollElasticityFeature {
    // Lion (10.7) introduced elasticity on scrolling
    return NSAppKitVersionNumber >= NSAppKitVersionNumber10_7;
}

+ (BOOL) hasUpdatedToolbarFeature {
    return NSAppKitVersionNumber > NSAppKitVersionNumber10_10_Max;
}

+(void) performSelector:(SEL) selector object:(id) object {
    if( [object respondsToSelector: selector] ) {
        // ARC safe way to do performSelector (see http://stackoverflow.com/a/20058585/4786529 ) ...
        IMP imp = [object methodForSelector: selector];
        void (*func)(id, SEL) = (void *) imp;
        func(object, selector);
    }
}

+(NSDictionary*) adjustAttributesFontSize: (NSDictionary*) dictionary
                                     size: (CGFloat) fontSize {
    NSMutableDictionary* mutableResult = [dictionary mutableCopy];
    NSFont* font = mutableResult[NSFontAttributeName];
    if (@available(macOS 10.15, *)) {
        font = [font fontWithSize: fontSize];
    } else {
        font = [NSFont fontWithName: font.fontName
                               size: fontSize];
    }
    mutableResult[NSFontAttributeName] = font;
    return [mutableResult copy];
}

+ (NSString*) coreBuildVersion {
    return [IFUtility localizedString: @"Build Version"];
}

+(NSString*) majorMinor: (NSString*) version {
    NSArray *array = [version componentsSeparatedByString:@"."];
    if (array.count >= 3) {
        return [NSString stringWithFormat:@"%@.%@", array[0], array[1]];
    }
    return version;
}

+(bool) unzip: (NSURL*) zipURL toDirectory:(NSURL*) targetDirectory {
    // see https://stackoverflow.com/questions/2296667/unzipping-a-file-in-cocoa
    NSFileManager* fm = [NSFileManager defaultManager];
    NSError *error;

    // create a new empty folder (unzipping will fail if any of the payload files already
    // exist at the target location)
    [fm createDirectoryAtURL: targetDirectory
 withIntermediateDirectories: YES
                  attributes: nil
                       error: &error];

    //now create an unzip task
    NSArray *arguments = @[zipURL.path];
    NSTask *unzipTask = [[NSTask alloc] init];
    unzipTask.launchPath = @"/usr/bin/unzip";
    unzipTask.currentDirectoryURL = targetDirectory;
    unzipTask.arguments = arguments;
    [unzipTask launch];
    [unzipTask waitUntilExit];

    if (unzipTask.terminationStatus != 0) {
        return FALSE;
    }
    return TRUE;
}

static int valueForHexChar(unichar c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;

    return 0;
}

+ (NSString*) unescapeString: (NSString*) string {
    // Change '\n', '\t', etc marks in a string to newlines, tabs, etc
    int length = (int) string.length;
    if (length == 0) return @"";

    int outLength = -1;
    int totalLength = 256;
    unichar* newString = malloc(sizeof(unichar)*totalLength);

    int chNum;
    for (chNum = 0; chNum < length; chNum++) {
        // Get the next character
        unichar chr = [string characterAtIndex: chNum];
        unichar outChar = '?';

        // If it's an escape character, parse as appropriate
        if (chr == '\\' && chNum+1<length) {
            // The result depends on the next character
            chNum++;
            unichar nextChar = [string characterAtIndex: chNum];

            switch (nextChar) {
                case 'n':
                    // Newline
                    outChar = 10;
                    break;

                case 'r':
                    // Return
                    outChar = 13;
                    break;

                case 't':
                    // Tab
                    outChar = 9;
                    break;

                default:
                    // Default behaviour is just to strip the '\'
                    outChar = nextChar;
            }
        } else if (chr == '[' && chNum+1 < length) {
            // [=0xffff=] = exact character
            // (different versions of webkit treat the '\' character differently, so we need this to ensure that we get consistent results)
            unichar nextChar = [string characterAtIndex: chNum+1];
            if (nextChar == '=') {
                // [= matched: look for the matching =]
                unichar previous = nextChar;
                int finalChNum;
                for (finalChNum = chNum+1; finalChNum < length; finalChNum++) {
                    unichar mightBeLast = [string characterAtIndex: finalChNum];

                    if (previous == '=' && mightBeLast == ']') {
                        break;
                    }

                    previous = mightBeLast;
                }

                // Get the character number from the string
                NSString* characterString = [string substringWithRange: NSMakeRange(chNum+2, finalChNum-chNum-3)];

                if ([characterString hasPrefix: @"0x"]) {
                    // Is a hexidecimal character
                    int val = 0;
                    int pos;
                    for (pos=2; pos<characterString.length; pos++) {
                        val *= 16;
                        val += valueForHexChar([characterString characterAtIndex: pos]);
                    }
                    outChar = val;
                } else if ([characterString isEqualToString: @"BACK"]) {
                    // Backslash
                    outChar = '\\';
                } else {
                    outChar = '?';
                }

                // Move to the final character
                chNum = finalChNum;
            } else {
                outChar = chr;
            }
        } else {
            // Otherwise, just pass it through
            outChar = chr;
        }

        // Add to the output string
        outLength++;
        if (outLength >= totalLength) {
            totalLength += 256;
            newString = realloc(newString, sizeof(unichar)*totalLength);
        }

        newString[outLength] = outChar;
    }

    // Turn newString into an NSString
    outLength++;
    NSString* result = [NSString stringWithCharacters: newString
                                               length: outLength];
    free(newString);

    return result;
}

+(NSTextCheckingResult*) findMatch: (NSString*) pattern inText:(NSString*) text {
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern
                                                                           options: 0
                                                                             error: &error];
    if (error != nil) {
        NSLog(@"Warning: Runtime error parser. Regex pattern error: %@", error.description);
        return nil;
    }
    NSTextCheckingResult *match = [regex firstMatchInString: text
                                                    options: 0
                                                      range: NSMakeRange(0, text.length)];
    return match;
}

@end
