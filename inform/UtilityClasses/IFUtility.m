//
//  IFUtility.m
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import "IFUtility.h"
#import "IFPreferences.h"
#import <Foundation/NSCache.h>

@implementation IFUtility

// Are the strings equal, where the strings may be nil...
+ (bool) safeString:(NSString*) string1 insensitivelyEqualsSafeString:(NSString*) string2 {
    if(( string1 == nil ) || ( string2 == nil )) {
        return (string1 == string2);
    }
    return ([string1 caseInsensitiveCompare: string2] == NSOrderedSame);
}

+(bool) url: (NSURL*) url1
     equals: (NSURL*) url2 {
    bool sameScheme = [IFUtility safeString: [url1 scheme]
              insensitivelyEqualsSafeString: [url2 scheme]];
    bool samePath   = [IFUtility safeString: [url1 path]
              insensitivelyEqualsSafeString: [url2 path]];
    bool sameQuery  = [IFUtility safeString: [url1 query]
              insensitivelyEqualsSafeString: [url2 query]];
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

+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args] autorelease];
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
    NSString* contents = [[[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args] autorelease];
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
    NSString* contents = [[[NSString alloc] initWithFormat: alreadyLocalized ? formatString : [self localizedString:formatString]
                                                 arguments: args] autorelease];
    va_end(args);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  [self localizedString: @"OK"]];
    [alert setMessageText:      alreadyLocalized ? title : [self localizedString: title]];
    [alert setInformativeText:  contents];
    [alert setAlertStyle:       warningStyle ? NSWarningAlertStyle : NSInformationalAlertStyle];

    // NOTE: We don't use [NSAlert beginSheetModalForWindow:completionHandler:] because it is only available in 10.9
    [alert beginSheetModalForWindow: window
                      modalDelegate: nil
                     didEndSelector: nil
                        contextInfo: nil];
    [alert release];
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
    NSString* contents = [[[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args] autorelease];
    va_end(args);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  [self localizedString: yes]];
    [alert addButtonWithTitle:  [self localizedString: no]];
    [alert setMessageText:      [self localizedString: title]];
    [alert setInformativeText:  contents];
    [alert setAlertStyle: NSInformationalAlertStyle];

    // NOTE: We don't use [NSAlert beginSheetModalForWindow:completionHandler:] because it is only available in 10.9
    [alert beginSheetModalForWindow: window
                      modalDelegate: modalDelegate
                     didEndSelector: alertDidEndSelector
                        contextInfo: contextInfo];
    [alert release];
}

+ (BOOL) isSandboxed {
    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    return (nil != [environ objectForKey:@"APP_SANDBOX_CONTAINER_ID"]);
}

+(NSURL*) publicLibraryURL {
    NSString* publicLibraryURLString;
    if( [[IFPreferences sharedPreferences] publicLibraryDebug] && ![IFUtility isSandboxed]) {
        publicLibraryURLString = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        publicLibraryURLString = [publicLibraryURLString stringByAppendingPathComponent:@"InformPublicLibrary"];
        publicLibraryURLString = [publicLibraryURLString stringByAppendingPathComponent:@"index.html"];
        return [NSURL fileURLWithPath: publicLibraryURLString];
    }
    return [NSURL URLWithString: [IFUtility localizedString: @"PublicLibraryURL"]];
}

+ (NSString*) informSupportPath: (NSString *)firstArg, ... {
    // Get library directory (possibly in a sandboxed container).
    NSString *newPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];

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

+ (NSString*) pathForInformInternalAppSupport {
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"Internal"];
}

+ (NSString*) pathForInformInternalExtensions {
    return [[IFUtility pathForInformInternalAppSupport] stringByAppendingPathComponent:@"Extensions"];
}

+ (NSString*) pathForInformInternalLibraries {
    return [[IFUtility pathForInformInternalAppSupport] stringByAppendingPathComponent:@"Libraries"];
}

+ (NSString*) pathForInformInternalDocumentation {
    return [[IFUtility pathForInformInternalAppSupport] stringByAppendingPathComponent:@"Documentation"];
}

@end
