AC_DEFUN(UTIL_CHECK_CFLAG,
  [
    AC_MSG_CHECKING([if the C compiler ($CC) supports -$1])
    ac_OLD_CFLAGS="$CFLAGS"
    CFLAGS="$CFLAGS -$1"
    AC_TRY_LINK([], [ { int x; x = 1; } ],
      AC_MSG_RESULT(yes),
      AC_MSG_RESULT(no)
      CFLAGS="$ac_OLD_CFLAGS")
  ])

AC_DEFUN(UTIL_CHECK_LDFLAG,
  [
    AC_MSG_CHECKING([if the linker supports -$1])
    ac_OLD_LDFLAGS="$LDFLAGS"
    LDFLAGS="$LDFLAGS -$1"
    AC_TRY_LINK([], [ { int x; x = 1; } ],
      AC_MSG_RESULT(yes),
      AC_MSG_RESULT(no)
      LDFLAGS="$ac_OLD_LDFLAGS")
  ])
