//
//  InformTests-Bridging-Header.h
//  Inform
//
//  App classes exposed to the unit tests. The test bundle is loaded into Inform.app
//  (BUNDLE_LOADER), so the classes themselves come from the app at runtime.
//

#import <Foundation/Foundation.h>
#import "IFSemVer.h"
#import "IFUtility.h"
#import "IFSkein.h"
#import "IFSkeinItem.h"
#import "IFSkeinView.h"
#import "IFSkeinReportView.h"
#import "IFToolbarManager.h"
#import "IFSkeinReportItemView.h"
#import "IFPreferences.h"
#import "IFSyntaxManager.h"
#import "IFSyntaxData.h"
#import "IFSyntaxStyles.h"
#import "IFNaturalHighlighter.h"
#import "IFInform6Highlighter.h"
#import "IFInform7MutableString.h"
#import "IFProject.h"
#import "IFProjectFile.h"
#import "IFProjectController.h"
#import "IFWebViewHelper.h"
#import "IFRuntimeErrorParser.h"
#import "IFCompilerSettings.h"
#import "IFExtensionsManager.h"
#import "IFInBuild.h"
#import "IFNaturalIntel.h"
#import "IFIntelFile.h"
#import "IFIntelSymbol.h"
#import "IFSourceSharedActions.h"
#import "IFGamePage.h"
#import "IFFindResult.h"
#import "IFScanner.h"
#import "IFDiffer.h"
#import "NSBundle+IFBundleExtensions.h"
