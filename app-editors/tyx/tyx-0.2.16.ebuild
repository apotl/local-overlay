# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

CRATES="
"

inherit cargo desktop xdg

DESCRIPTION="A LyX-like experience rewritten for Typst and the modern era"
HOMEPAGE="https://tyx-editor.com https://github.com/tyx-editor/TyX"
SRC_URI="
	https://github.com/tyx-editor/TyX/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

# Tauri dependencies
DEPEND="
	dev-libs/glib:2
	dev-libs/openssl:=
	net-libs/webkit-gtk:4.1
	x11-libs/gtk+:3
	x11-libs/cairo
	x11-libs/gdk-pixbuf:2
	x11-libs/pango
"

RDEPEND="${DEPEND}"

BDEPEND="
	|| (
		>=dev-lang/rust-1.70:=
		>=dev-lang/rust-bin-1.70:=
	)
	net-libs/nodejs[npm]
	sys-apps/bun
	virtual/pkgconfig
	net-misc/curl
"

S="${WORKDIR}/TyX-${PV}"

QA_FLAGS_IGNORED="usr/bin/tyx"

src_prepare() {
	default

	# Install npm dependencies using bun
	bun install --frozen-lockfile || die "bun install failed"
}

src_compile() {
	# Build WASM components
	einfo "Building WASM components..."
	bun run prebuild || die "WASM build failed"

	# Build the Tauri application
	einfo "Building Tauri application..."
	bunx tauri build --bundles none || die "Tauri build failed"
}

src_install() {
	# Install the binary
	dobin "src-tauri/target/release/tyx"

	# Install desktop file if it exists
	if [[ -f "src-tauri/tyx.desktop" ]]; then
		domenu "src-tauri/tyx.desktop"
	else
		# Create a basic desktop file
		make_desktop_entry tyx "TyX Editor" tyx "Office;TextEditor" \
			"Comment=Modern document editor for Typst\nMimeType=text/plain;"
	fi

	# Install icon if available
	for size in 32 64 128 256; do
		if [[ -f "src-tauri/icons/${size}x${size}.png" ]]; then
			newicon -s ${size} "src-tauri/icons/${size}x${size}.png" tyx.png
		fi
	done

	# Install icon.png as fallback
	if [[ -f "src-tauri/icons/icon.png" ]]; then
		newicon -s 128 "src-tauri/icons/icon.png" tyx.png
	fi
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "TyX is currently in early development and breaking changes"
	elog "are introduced frequently. Please report any issues to:"
	elog "https://github.com/tyx-editor/TyX/issues"
}
