dnl autoconf script for Infer
dnl run ./autogen.sh to generate a configure script
dnl
dnl Copyright (c) 2015 - present Facebook, Inc.
dnl All rights reserved.
dnl
dnl This source code is licensed under the BSD style license found in the
dnl LICENSE file in the root directory of this source tree. An additional grant
dnl of patent rights can be found in the PATENTS file in the same directory.

AC_PREREQ([2.63])

# WARNING: AC_INIT only accepts string literals so the version number
# has to be kept in sync with below
AC_INIT([Infer],
        [0.7.0],
        [https://github.com/facebook/infer/issues/])
AC_CONFIG_SRCDIR([infer/src/backend/sil.ml])

# WARNING: keep in sync with above
INFER_MAJOR=0
INFER_MINOR=7
INFER_PATCH=0

AC_SUBST([INFER_MAJOR])
AC_SUBST([INFER_MINOR])
AC_SUBST([INFER_PATCH])

# record if we are in a release of Infer
AC_MSG_CHECKING([if we are in an Infer release build])
is_infer_release=no
AS_IF([test -f ".release"], [is_infer_release=yes])
INFER_IS_RELEASE=$is_infer_release
AC_SUBST([INFER_IS_RELEASE])
AC_MSG_RESULT([$is_infer_release])

# to compile the facebook-clang-plugins
AC_ARG_VAR([CLANG_PREFIX], [directory where clang is installed (defaults=$PWD/facebook-clang-plugins/clang)])
AS_IF([test "x$CLANG_PREFIX" = "x"], [
  CLANG_PREFIX="$(pwd)/facebook-clang-plugins/clang"
])

AC_ARG_VAR([CLANG_INCLUDES], [clang headers directories (defaults=$CLANG_PREFIX/include)])
AS_IF([test "x$CLANG_INCLUDES" = "x"], [
  CLANG_INCLUDES="$CLANG_PREFIX/include"
])


AC_ARG_ENABLE(c-analyzers,
  AS_HELP_STRING([--disable-c-analyzers],
    [do not build the C/C++/ObjC analyzers (default is to build them)]),
  ,
  enable_c_analyzers=yes)
BUILD_C_ANALYZERS=$enable_c_analyzers
AC_SUBST([BUILD_C_ANALYZERS])

AC_ARG_ENABLE(java-analyzers,
  AS_HELP_STRING([--disable-java-analyzers],
    [do not build the Java analyzers (default is to build them)]),
  ,
  enable_java_analyzers=yes)

BUILD_JAVA_ANALYZERS=$enable_java_analyzers
AC_SUBST([BUILD_JAVA_ANALYZERS])

AC_ARG_WITH(fcp-clang,
  AS_HELP_STRING([--without-fcp-clang],
    [do not use $CLANG_PREFIX/bin/clang to override the default compiler (default is to override if in an infer release)]),
  ,
  with_fcp_clang=$is_infer_release)

AS_IF([test "x$enable_c_analyzers" = "xyes"], [
  AC_MSG_CHECKING([whether to use the compilers in $CLANG_PREFIX/bin])
  case "$with_fcp_clang" in
    no)
      AC_MSG_RESULT([no])
    ;;
    yes)
      CC=$CLANG_PREFIX/bin/clang
      CXX=$CLANG_PREFIX/bin/clang++
      OBJC=$CLANG_PREFIX/bin/clang
      AC_MSG_RESULT([yes])
    ;;
    *)
      AC_MSG_ERROR([invalid value for --without-fcp-clang; use "yes" or "no"])
    ;;
  esac

  AC_CHECK_TOOL([SHASUM], [shasum], [no])
  AC_ASSERT_PROG([shasum], [$SHASUM])
])
# end if($enable_c_analyzers)


AC_CHECK_TOOL([PYTHON27], [python2.7], [no])
AC_ASSERT_PROG([python2.7], [$PYTHON27])

AC_CHECK_TOOL([XCODE_SELECT], [xcode-select], [no])
AC_SUBST([XCODE_SELECT])


# prefer clang over gcc because the plugins makes use of
# clang-specific #pragma's
AC_PROG_CC(clang gcc)
AC_PROG_AWK
AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET

if test "x$enable_c_analyzers" = "xyes"; then
  AC_PROG_CPP
  AC_PROG_CXX(clang++ g++)

  dnl clang wants either clang version >= 3.1 or gcc version >= 4.7.2 to
  dnl compile itself
  AC_MSG_CHECKING([if the C/C++ compiler is recent enough])
  AC_COMPILE_IFELSE([AC_LANG_SOURCE([[
#ifdef __clang__
#if __clang_major__ < 3 || (__clang_major__ == 3 && __clang_minor__ < 1)
#error compiler is too old
#endif // version check
#elif defined __GNUC__ // __clang__
#if __GNUC__ < 4 || (__GNUC__ == 4 && (__GNUC_MINOR__ < 7 || (__GNUC_MINOR__ == 7 && __GNUC_PATCHLEVEL__ < 2)))
#error compiler is too old
#endif // version check
#endif // __GNUC__
]])],
    [AC_MSG_RESULT([yes])],
    [dnl
      AC_MSG_RESULT([no])
      AC_MSG_ERROR([
Your C/C++ compiler seems to be too old to build clang, which is
required by the facebook-clang-plugins. Please install either
gcc version >= 4.7.2 or clang version >= 3.1.

See the output of `./configure --help` to force the use of a different
C compiler.

Alternatively, you can checkout a release of infer with clang
pre-compiled here:

  https://github.com/facebook/infer/releases/])
   ]
  )

  AC_CHECK_HEADERS([fcntl.h inttypes.h limits.h locale.h malloc.h stddef.h stdint.h stdlib.h string.h sys/mount.h sys/param.h sys/socket.h sys/statfs.h sys/time.h unistd.h wchar.h wctype.h])
fi
# end if($enable_c_analyzers)


# OCaml dependencies
AC_PROG_OCAML
AC_ASSERT_PROG([ocamlc], [$OCAMLC])
# check the version of OCaml
AC_ASSERT_OCAML_MIN_VERSION([4.02.1])
AC_ASSERT_PROG([ocamlopt], [$OCAMLOPT])
AC_ASSERT_PROG([ocamlbuild], [$OCAMLBUILD])
AC_PROG_FINDLIB
AC_PROG_OCAMLLEX
AC_ASSERT_PROG([ocamllex], [$OCAMLLEX])
AC_PROG_OCAMLYACC
AC_ASSERT_PROG([ocamlyacc], [$OCAMLYACC])
AC_ASSERT_OCAML_PKG([atdgen], [], [1.6.0])
AC_ASSERT_OCAML_PKG([biniou])
AC_ASSERT_OCAML_PKG([camlzip], [zip])
AC_ASSERT_OCAML_PKG([easy-format])
AC_ASSERT_OCAML_PKG([extlib], [], [1.5.4])
AC_ASSERT_OCAML_PKG([yojson])

if test "x$enable_java_analyzers" = "xyes"; then
  AC_CHECK_TOOL([JAVA], [java], [no])
  AC_CHECK_TOOL([JAVAC], [javac], [no])
  AC_ASSERT_PROG([javac], [$JAVAC])
  AC_ASSERT_PROG([java], [$JAVA])
  AC_ASSERT_OCAML_PKG([javalib], [], [2.3.1])
  AC_ASSERT_OCAML_PKG([sawja], [], [1.5.1])
  AC_ASSERT_OCAML_PKG([ptrees])

  AC_MSG_CHECKING([for JAVA_HOME])
  cat - <<_ACEOF >conftest.java
public class conftest {
  public static void main(String[[]] args) {
    System.out.println(System.getProperty("java.home"));
    System.exit(0);
  }
}
_ACEOF
  rm -f conftest.class
  if $JAVAC conftest.java; then
    rm -f conftest.java
    _USER_JAVA_HOME=$($JAVA -cp . conftest)
    if rm -f conftest.class; then
       USER_JAVA_HOME=$_USER_JAVA_HOME/..
    else
      AC_MSG_ERROR([Could not run test program with $JAVA])
    fi
  else
    rm -f conftest.java
    AC_MSG_ERROR([Could not compile test program with $JAVAC])
  fi
  AC_MSG_RESULT([$USER_JAVA_HOME])
  AC_SUBST([USER_JAVA_HOME])
fi


AC_CHECK_TOOL([ATDGEN], [atdgen], [no])
AC_ASSERT_PROG([atdgen], [$ATDGEN])
AC_SUBST([ATDGEN])

AC_ARG_ENABLE(ocaml-annot,
  AS_HELP_STRING([--disable-ocaml-annot], [do not build ocaml .annot files]),
  ,
  enable_ocaml_annot=yes)
ENABLE_OCAML_ANNOT=$enable_ocaml_annot
AC_SUBST([ENABLE_OCAML_ANNOT])

AC_ARG_ENABLE(ocaml-bin-annot,
  AS_HELP_STRING([--disable-ocaml-bin-annot], [do not build ocaml .cmt files]),
  ,
  enable_ocaml_bin_annot=yes)
ENABLE_OCAML_BINANNOT=$enable_ocaml_bin_annot
AC_SUBST([ENABLE_OCAML_BINANNOT])


AC_CONFIG_FILES([
  Makefile.config
  Makefile
  infer/Makefile
  infer/models/Makefile
  infer/models/c/Makefile
  infer/models/cpp/Makefile
  infer/models/objc/Makefile
  infer/models/java/Makefile
  infer/src/Makefile
])

AC_OUTPUT
