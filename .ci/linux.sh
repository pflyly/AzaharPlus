#!/bin/bash -ex

if [ "$TARGET" = "appimage" ]; then
    # Determine the full revision name.
    GITDATE="`git show -s --date=short --format='%ad' | sed 's/-//g'`"
    git remote add upstream https://github.com/AzaharPlus/AzaharPlus.git
    git fetch upstream --no-recurse-submodules
    UPSTREAM_HASH=$(git rev-parse --short=9 upstream/AzaharPlus)
    echo "Final upstream commit hash: $UPSTREAM_HASH"
    echo "GITREV=${UPSTREAM_HASH}" >> "${GITHUB_ENV}"
    UPSTREAM_COUNT=$(git rev-list --count upstream/AzaharPlus)
    echo "Upstream commits count: $UPSTREAM_COUNT"
    echo "GITCOUNT=${UPSTREAM_COUNT}" >> "${GITHUB_ENV}"
    # Compile the AppImage we distribute with Clang.
    export EXTRA_CMAKE_FLAGS=(-DCMAKE_CXX_COMPILER=clang++
                              -DCMAKE_C_COMPILER=clang
                              -DCMAKE_LINKER=/etc/bin/ld.lld
                              -DENABLE_ROOM_STANDALONE=OFF)
    # Bundle required QT wayland libraries
    export EXTRA_QT_PLUGINS="waylandcompositor"
    export EXTRA_PLATFORM_PLUGINS="libqwayland-egl.so;libqwayland-generic.so"
else
    # For the linux-fresh verification target, verify compilation without PCH as well.
    export EXTRA_CMAKE_FLAGS=(-DCITRA_USE_PRECOMPILED_HEADERS=OFF)
fi

if [ "$GITHUB_REF_TYPE" == "tag" ]; then
	export EXTRA_CMAKE_FLAGS=($EXTRA_CMAKE_FLAGS -DENABLE_QT_UPDATE_CHECKER=ON)
fi

mkdir build
cd build
cmake .. -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DENABLE_QT_TRANSLATION=ON \
    -DUSE_DISCORD_PRESENCE=ON \
	"${EXTRA_CMAKE_FLAGS[@]}"
ninja
strip -s bin/Release/*

if [ "$TARGET" = "appimage" ]; then
    ninja bundle
    # Use uruntime to generate dwarfs appimage
    rm -f ./bundle/*.AppImage
    wget -q "https://github.com/VHSgunzo/uruntime/releases/download/v0.3.6/uruntime-appimage-dwarfs-x86_64" -O ./uruntime 
    chmod a+x ./uruntime
    ./uruntime --appimage-mkdwarfs -f --set-owner 0 --set-group 0 --no-history --no-create-timestamp \
    --compression zstd:level=22 -S26 -B32 --header ./uruntime -i ./AppDir-azahar -o AzaharPlus-nightly-$GITDATE-$GITCOUNT-$GITREV.AppImage
    mv ./*.AppImage ./bundle
    
    ccache -s
else
    ccache -s -v
fi

ctest -VV -C Release
