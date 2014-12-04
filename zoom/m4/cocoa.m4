dnl Detect the presence of Apple's Cocoa API

AC_DEFUN(COCOA_DETECT, [
   AC_CACHE_CHECK([for Cocoa], cocoa_present, [
     AC_TRY_COMPILE([
	#include <Cocoa/Cocoa.h>
	], [ NSApplicationMain(0, NULL); ],
	[
	  cocoa_old_LDFLAGS="$LDFLAGS"
	  LDFLAGS="$LDFLAGS -framework Cocoa"
	  AC_TRY_LINK([
	    #include <Cocoa/Cocoa.h>
	    ], [ NSApplicationMain(0, NULL); ],
	    [ cocoa_present=yes ],
	    [ cocoa_presnet=no ])
	],
	cocoa_present=no)
     ])

   if test "x$cocoa_present" = "xyes"; then
     LDFLAGS="$LDFLAGS -framework Cocoa"
   fi
])
