#!/bin/bash

env
BUILDER=${TARGET_BUILD_DIR}/Builder
TARGETDIR=${PROJECT_DIR}/build

if [ ! -d ${TARGETDIR} ]; then
    mkdir ${TARGETDIR}
fi

if [ "x$1" = "xclean" ]; then
    echo Cleaning interpreter...

    if [ -e ${TARGETDIR}/interp_gen.h ]; then
        rm ${TARGETDIR}/interp_gen.h
    fi
    
    for i in {3,4,5,6}; do
        if [ -e ${TARGETDIR}/interp_z${i}.h ]; then
            rm ${TARGETDIR}/interp_z${i}.h
        fi
    done
    
    if [ -e ${TARGETDIR}/varop.h ]; then
        rm ${TARGETDIR}/varop.h
    fi
else
    echo Building interpreter...
    
    if [ ./src/zcode.ops -nt ${TARGETDIR}/interp_gen.h ]; then
        echo interp_gen.h
        ${BUILDER} ${TARGETDIR}/interp_gen.h -1 ${SRCROOT}/src/zcode.ops
    fi
    
    for i in {3,4,5,6}; do
        if [ ./src/zcode.ops -nt ${TARGETDIR}/interp_z${i}.h ]; then
            echo interp_z${i}.h
            ${BUILDER} ${TARGETDIR}/interp_z${i}.h $i ${SRCROOT}/src/zcode.ops
        fi
    done
    
    if [ ./builder/varopdecode.pl -nt ${TARGETDIR}/varop.h ]; then
        echo varop.h
        perl ./builder/varopdecode.pl 4 varop >${TARGETDIR}/varop.h
    fi
fi
