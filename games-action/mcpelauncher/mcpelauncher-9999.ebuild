# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit cmake git-r3 flag-o-matic

DESCRIPTION="Unofficial launcher for Minecraft Bedrock Edition on Linux"
HOMEPAGE="https://github.com/minecraft-linux/mcpelauncher-manifest"
EGIT_REPO_URI="https://github.com/minecraft-linux/mcpelauncher-manifest.git"
EGIT_SUBMODULES=( '*' )

LICENSE="GPL-3 MIT"
SLOT="0"
KEYWORDS=""
IUSE="webview"
RESTRICT="network-sandbox"

DEPEND="
	>=dev-build/cmake-3.0
	media-libs/mesa
	media-libs/libglvnd[X]
	x11-libs/libX11
	x11-libs/libXrandr
	x11-libs/libXinerama
	x11-libs/libXcursor
	x11-libs/libXi
	net-misc/curl
	dev-libs/openssl:=
	sys-libs/zlib
	media-libs/libpng:=
	dev-libs/libzip
	media-libs/alsa-lib
	media-sound/pulseaudio-daemon
	dev-libs/libevdev
	x11-libs/libxkbcommon
	dev-cpp/nlohmann_json
	webview? (
		dev-qt/qtwebengine:6
		dev-qt/qtbase:6[gui,widgets,network]
	)
"
RDEPEND="${DEPEND}"
BDEPEND="
	dev-vcs/git
	llvm-core/clang
"

src_configure() {
	# Use clang as the official docs recommend it and it handles _Atomic better
	export CC=clang
	export CXX=clang++
	
	# Disable fortify source - the launcher has some buffer operations that trigger false positives
	append-cppflags -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0
	
	# Ensure PIC for all static libraries
	append-cflags -fPIC
	append-cxxflags -fPIC
	
	local mycmakeargs=(
		-DCMAKE_BUILD_TYPE=Release
		-DCMAKE_INSTALL_PREFIX="${EPREFIX}/opt/${PN}"
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON
		-DCMAKE_INSTALL_RPATH="\$ORIGIN/../lib"
		-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
		-DJNI_USE_JNIVM=ON
		-DGAMEWINDOW_SYSTEM=SDL3
		-DENABLE_DEV_PATHS=OFF
		-DBUILD_WEBVIEW=$(usex webview ON OFF)
		-DBUILD_UI=OFF
		-DBUILD_CLIENT=ON
		-DUSE_OWN_CURL=OFF
	)
	cmake_src_configure
}

src_install() {
	cmake_src_install

	# Manually install shared libraries that CMake doesn't install
	dodir /opt/${PN}/lib
	
	# Find and install all .so files from the build directory
	find "${BUILD_DIR}" -name "*.so" -type f -exec cp {} "${ED}/opt/${PN}/lib/" \; || die "Failed to copy libraries"
	
	# Create simple wrapper script without LD_LIBRARY_PATH
	dodir /usr/bin
	cat > "${ED}/usr/bin/mcpelauncher-client" <<-EOF || die
		#!/bin/bash
		exec "${EPREFIX}/opt/${PN}/bin/mcpelauncher-client" "\$@"
	EOF
	fperms +x /usr/bin/mcpelauncher-client
}

pkg_postinst() {
	elog "Minecraft Bedrock Edition launcher has been installed to /opt/${PN}"
	elog ""
	elog "To run the game, you need to:"
	elog "1. Extract the Minecraft APK from Google Play"
	elog "2. Place it in ~/.local/share/mcpelauncher/"
	elog "3. Run: mcpelauncher-client"
	elog ""
	elog "For more information, visit:"
	elog "  https://minecraft-linux.github.io"
}
