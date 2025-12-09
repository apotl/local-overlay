# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Incredibly fast JavaScript runtime, bundler, test runner, and package manager"
HOMEPAGE="https://bun.sh https://github.com/oven-sh/bun"

# Bun provides pre-built binaries for multiple architectures
SRC_URI="
	amd64? ( https://github.com/oven-sh/bun/releases/download/bun-v${PV}/bun-linux-x64.zip -> ${P}-linux-x64.zip )
	arm64? ( https://github.com/oven-sh/bun/releases/download/bun-v${PV}/bun-linux-aarch64.zip -> ${P}-linux-aarch64.zip )
"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# Bun is a statically linked binary with minimal runtime dependencies
RDEPEND="
	sys-libs/glibc
	sys-libs/zlib
"

BDEPEND="app-arch/unzip"

QA_PREBUILT="
	opt/bun/bin/bun
"

src_unpack() {
	default

	# Set S based on architecture
	if use amd64; then
		S="${WORKDIR}/bun-linux-x64"
	elif use arm64; then
		S="${WORKDIR}/bun-linux-aarch64"
	fi
}

src_install() {
	# Create installation directory
	local install_dir="/opt/bun"

	# Install the bun binary
	exeinto "${install_dir}/bin"
	doexe bun

	# Install completions if they exist
	if [[ -d completions ]]; then
		insinto /usr/share/bash-completion/completions
		doins completions/bun.bash

		insinto /usr/share/fish/vendor_completions.d
		doins completions/bun.fish

		insinto /usr/share/zsh/site-functions
		doins completions/_bun
	fi

	# Create symlinks in /usr/bin
	dosym "${install_dir}/bin/bun" /usr/bin/bun
	dosym "${install_dir}/bin/bun" /usr/bin/bunx
}

pkg_postinst() {
	elog "Bun ${PV} has been installed."
	elog ""
	elog "Bun is an all-in-one JavaScript runtime & toolkit designed for speed,"
	elog "complete with a bundler, test runner, and Node.js-compatible package manager."
	elog ""
	elog "Getting started:"
	elog "  bun --help           Show available commands"
	elog "  bun init             Initialize a new project"
	elog "  bun install          Install dependencies"
	elog "  bun run <script>     Run a script"
	elog ""
	elog "Documentation: https://bun.sh/docs"
}
