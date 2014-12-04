dnl Detect the presence of Apple's Carbon API

AC_DEFUN(CARBON_DETECT, [
   AC_ARG_ENABLE([carbon],
[  --disable-carbon        Disable the check for the Carbon framework
                          (force building of the X11 version of Zoom under
                          OS X)],
	[],
 	[enable_carbon=yes])

   if test "x$enable_carbon" != "xno"; then
     AC_CACHE_CHECK([for Carbon], carbon_present, [
       AC_TRY_COMPILE([
	  #include <Carbon/Carbon.h>
	  ], [ WindowRef w; SetWTitle(0, ""); ],
	  [
	    carbon_old_LDFLAGS="$LDFLAGS"
	    LDFLAGS="$LDFLAGS -framework Carbon"
	    AC_TRY_LINK([
	      #include <Carbon/Carbon.h>
	      ], [  WindowRef w; SetWTitle(0, ""); ],
	      [ carbon_present=yes ],
	      [ carbon_present=no
	        LDFLAGS="$carbon_old_LD_FLAGS" ])
	  ],
	  carbon_present=no)
       ])

     if test "x$carbon_present" = "xyes"; then
       LDFLAGS="$LDFLAGS -framework Carbon"
     fi
   else
     carbon_present=no
   fi
])

AC_DEFUN(QUICKTIME_DETECT, [
   AC_CACHE_CHECK([for QuickTime], quicktime_present, [
     AC_TRY_COMPILE([
	#include <QuickTime/QuickTime.h>
	], [ GetGraphicsImporterForDataRef(NULL, 'xxxx', NULL); ],
	[
	  carbon_old_LDFLAGS="$LDFLAGS"
	  LDFLAGS="$LDFLAGS -framework QuickTime"
	  AC_TRY_LINK([
	    #include <QuickTime/QuickTime.h>
	    ], [ GetGraphicsImporterForDataRef(NULL, 'xxxx', NULL); ],
	    [ quicktime_present=yes ],
	    [ quicktime_present=no
	      LDFLAGS="$quicktime_old_LD_FLAGS" ])
	],
	quicktime_present=no)
     ])

   if test "x$quicktime_present" = "xyes"; then
     LDFLAGS="$LDFLAGS -framework QuickTime"
   fi
])
