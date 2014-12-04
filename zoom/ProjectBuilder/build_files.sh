#!/bin/bash

env
BUILDER=${TARGET_BUILD_DIR}/Builder

if [ "x$1" = "xclean" ]; then
    echo Cleaning interpreter...

    if [ -e build/interp_gen.h ]; then
        rm build/interp_gen.h
    fi
    
    for i in {3,4,5,6}; do
        if [ -e build/interp_z${i}.h ]; then
            rm build/interp_z${i}.h
        fi
    done
    
    if [ -e build/varop.h ]; then
        rm build/varop.h
    fi
else
    echo Building interpreter...
    
    if [ ./src/zcode.ops -nt build/interp_gen.h ]; then
        echo interp_gen.h
        ${BUILDER} build/interp_gen.h -1 ./src/zcode.ops
    fi
    
    for i in {3,4,5,6}; do
        if [ ./src/zcode.ops -nt build/interp_z${i}.h ]; then
            echo interp_z${i}.h
            ${BUILDER} build/interp_z${i}.h $i ./src/zcode.ops
        fi
    done
    
    if [ ./builder/varopdecode.pl -nt build/varop.h ]; then
        echo varop.h
        perl ./builder/varopdecode.pl 4 varop >build/varop.h
    fi
fi
