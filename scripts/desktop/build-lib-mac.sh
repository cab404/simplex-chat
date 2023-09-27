#!/bin/bash

set -e

OS=mac
ARCH="${1:-`uname -a | rev | cut -d' ' -f1 | rev`}"
if [ "$ARCH" == "arm64" ]; then
    ARCH=aarch64
fi
LIB_EXT=dylib
LIB=libHSsimplex-chat-*-inplace-ghc*.$LIB_EXT
GHC_LIBS_DIR=$(ghc --print-libdir)

BUILD_DIR=dist-newstyle/build/$ARCH-*/ghc-*/simplex-chat-*

rm -rf $BUILD_DIR
cabal build lib:simplex-chat lib:simplex-chat --ghc-options="-optl-Wl,-rpath,@loader_path -optl-Wl,-L$GHC_LIBS_DIR/rts -optl-lHSrts_thr-ghc8.10.7 -optl-lffi"

cd $BUILD_DIR/build
mkdir deps 2> /dev/null || true

# It's not included by default for some reason. Compiled lib tries to find system one but it's not always available
cp $GHC_LIBS_DIR/rts/libffi.dylib ./deps

DYLIBS=`otool -L $LIB | grep @rpath | tail -n +2 | cut -d' ' -f 1 | cut -d'/' -f2`
RPATHS=`otool -l $LIB | grep "path "| cut -d' ' -f11`

PROCESSED_LIBS=()

function copy_deps() {
    local LIB=$1
    if [[ "${PROCESSED_LIBS[*]}" =~ "$LIB" ]]; then
    	return 0
    fi

    PROCESSED_LIBS+=$LIB
	local DYLIBS=`otool -L $LIB | grep @rpath | tail -n +2 | cut -d' ' -f 1 | cut -d'/' -f2`
	local NON_FINAL_RPATHS=`otool -l $LIB | grep "path "| cut -d' ' -f11`
	local RPATHS=`otool -l $LIB | grep "path "| cut -d' ' -f11 | sed "s|@loader_path/..|$GHC_LIBS_DIR|"`

	cp $LIB ./deps
    if [[ "$NON_FINAL_RPATHS" == *"@loader_path/.."* ]]; then
        # Need to point the lib to @loader_path instead
		install_name_tool -add_rpath @loader_path ./deps/`basename $LIB`
	fi
	#echo LIB $LIB
	#echo DYLIBS ${DYLIBS[@]}
	#echo RPATHS ${RPATHS[@]}

	for DYLIB in $DYLIBS; do
	    for RPATH in $RPATHS; do
	        if [ -f "$RPATH/$DYLIB" ]; then
	            #echo DEP IS "$RPATH/$DYLIB"
	            if [ ! -f "deps/$DYLIB" ]; then
	            	cp "$RPATH/$DYLIB" ./deps
	            fi
	            copy_deps "$RPATH/$DYLIB"
	        fi
	    done
	done
}

copy_deps $LIB
rm deps/`basename $LIB`

cd -

rm -rf apps/multiplatform/common/src/commonMain/cpp/desktop/libs/$OS-$ARCH/
rm -rf apps/multiplatform/desktop/src/jvmMain/resources/libs/$OS-$ARCH/
rm -rf apps/multiplatform/desktop/build/cmake

mkdir -p apps/multiplatform/common/src/commonMain/cpp/desktop/libs/$OS-$ARCH/
cp -r $BUILD_DIR/build/deps apps/multiplatform/common/src/commonMain/cpp/desktop/libs/$OS-$ARCH/
cp $BUILD_DIR/build/libHSsimplex-chat-*-inplace-ghc*.$LIB_EXT apps/multiplatform/common/src/commonMain/cpp/desktop/libs/$OS-$ARCH/

cd apps/multiplatform/common/src/commonMain/cpp/desktop/libs/$OS-$ARCH/

LIBCRYPTO_PATH=$(otool -l deps/libHSdrct-*.$LIB_EXT | grep libcrypto | cut -d' ' -f11)
install_name_tool -change $LIBCRYPTO_PATH @rpath/libcrypto.1.1.$LIB_EXT deps/libHSdrct-*.$LIB_EXT
cp $LIBCRYPTO_PATH deps/libcrypto.1.1.$LIB_EXT
chmod 755 deps/libcrypto.1.1.$LIB_EXT
install_name_tool -id "libcrypto.1.1.$LIB_EXT" deps/libcrypto.1.1.$LIB_EXT
install_name_tool -id "libffi.8.$LIB_EXT" deps/libffi.$LIB_EXT

LIBCRYPTO_PATH=$(otool -l $LIB | grep libcrypto | cut -d' ' -f11)
if [ -n "$LIBCRYPTO_PATH" ]; then
    install_name_tool -change $LIBCRYPTO_PATH @rpath/libcrypto.1.1.$LIB_EXT $LIB
fi

LIBCRYPTO_PATH=$(otool -l deps/libHSsmplxmq*.$LIB_EXT | grep libcrypto | cut -d' ' -f11)
if [ -n "$LIBCRYPTO_PATH" ]; then
    install_name_tool -change $LIBCRYPTO_PATH @rpath/libcrypto.1.1.$LIB_EXT deps/libHSsmplxmq*.$LIB_EXT
fi

for lib in $(find . -type f -name "*.$LIB_EXT"); do
    RPATHS=`otool -l $lib | grep -E "path /Users/|path /usr/local|path /opt/" | cut -d' ' -f11`
    for RPATH in $RPATHS; do
        install_name_tool -delete_rpath $RPATH $lib
    done
done

LOCAL_DIRS=`for lib in $(find . -type f -name "*.$LIB_EXT"); do otool -l $lib | grep -E "/Users|/opt/|/usr/local" && echo $lib; done`
if [ -n "$LOCAL_DIRS" ]; then
    echo These libs still point to local directories:
    echo $LOCAL_DIRS
    exit 1
fi

cd -
scripts/desktop/prepare-vlc-mac.sh
