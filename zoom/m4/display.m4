dnl
dnl A short m4 module to display pretty status messages (with the aid of tput)
dnl

dnl UTIL_DISPLAY_INIT
dnl Locates the tput program and works out the codes to use
AC_DEFUN(UTIL_DISPLAY_INIT,
  [
    AC_PATH_PROG(UTIL_PROG_TPUT, tput, notput)

    UTIL_DISPLAY_CODE(UTIL_CODE_B, bold, bold, [*])
    UTIL_DISPLAY_CODE(UTIL_CODE_NB, sgr0,, [*])
    UTIL_DISPLAY_CODE(UTIL_CODE_U, smul, underline, [_])
    UTIL_DISPLAY_CODE(UTIL_CODE_NU, rmul,, [_])
    UTIL_DISPLAY_CODE(UTIL_CODE_CY, setf 6, cyan)
    UTIL_DISPLAY_CODE(UTIL_CODE_NCY, sgr0)
  ])

dnl UTIL_DISPLAY_CODE(Variable, Code, [Name, Value-if-not-found])
dnl Works out the code to get a given attribute. If Name is empty,
dnl no message is displayed.
AC_DEFUN(UTIL_DISPLAY_CODE,
  [
    if test $UTIL_PROG_TPUT = notput; then
      $1=$4
    else
      if test "x$3" != 'x'; then
        AC_MSG_CHECKING(code for $3)
      fi

      UTIL_DISPLAY_TEMP=`$UTIL_PROG_TPUT $2`
      UTIL_DISPLAY_RESET=`$UTIL_PROG_TPUT sgr0`
      if test "x$UTIL_DISPLAY_TEMP" = "x"; then
        $1=$4
        if test "x$3" != 'x'; then
          AC_MSG_RESULT(not available)
        fi
      else
        $1=$UTIL_DISPLAY_TEMP
        if test "x$3" != 'x'; then
          AC_MSG_RESULT(${UTIL_DISPLAY_TEMP}ok${UTIL_DISPLAY_RESET})
        fi
      fi
    fi
  ])

dnl UTIL_DISPLAY_HEADER(Author, Year)
dnl Displays a copyright message and suggests some appropriate reading
dnl material. You need the variables PACKAGE and VERSION defined
AC_DEFUN(UTIL_DISPLAY_HEADER,
  [
    AC_MSG_RESULT()
    echo [${UTIL_CODE_CY}${UTIL_CODE_B}${UTIL_CODE_U}$PACKAGE${UTIL_CODE_NU}${UTIL_CODE_NB}${UTIL_CODE_NCY} version ${VERSION} configuration script]
    AC_MSG_RESULT([Copyright (c) ${UTIL_CODE_B}$1${UTIL_CODE_NB}, $2])
    AC_MSG_RESULT([Please see the file ${UTIL_CODE_B}COPYING${UTIL_CODE_NB} for the information on copying and warranties])
    AC_MSG_RESULT([Check the ${UTIL_CODE_B}README${UTIL_CODE_NB} and ${UTIL_CODE_B}INSTALL${UTIL_CODE_NB} files for important information on installing])
    AC_MSG_RESULT([this software])
  ])

dnl UTIL_DISPLAY_SECTION(msg)
dnl Displays 'Now configuring msg', with msg in bold
AC_DEFUN(UTIL_DISPLAY_SECTION,
  [
    AC_MSG_RESULT()
    AC_MSG_RESULT([  Now configuring ${UTIL_CODE_B}$1${UTIL_CODE_NB}])
  ])

dnl UTIL_DISPLAY_INFO
dnl Displays 'msg' in bold
AC_DEFUN(UTIL_DISPLAY_INFO,
  [
    AC_MSG_RESULT()
    AC_MSG_RESULT([  ${UTIL_CODE_B}$1${UTIL_CODE_NB}])
  ])
