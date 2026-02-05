# Copyright 2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit git-r3

DESCRIPTION="OpenAI-compatible proxy for hot-swapping between local LLM models"
HOMEPAGE="https://github.com/mostlygeek/llama-swap"
EGIT_REPO_URI="https://github.com/mostlygeek/llama-swap.git"
EGIT_COMMIT="v189"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="gui"
RESTRICT="network-sandbox"

BDEPEND="
	dev-lang/go
	gui? ( dev-libs/nodejs )
"

src_compile() {
	if use gui; then
		# Build the Svelte UI — vite outputs into proxy/ui_dist/ which go:embed picks up
		cd "${S}/ui-svelte" || die
		npm install || die "npm install failed"
		npm run build || die "npm run build failed"
		cd "${S}" || die
	else
		# go:embed requires the directory to exist and contain at least one file
		mkdir -p "${S}/proxy/ui_dist" || die
		touch "${S}/proxy/ui_dist/placeholder.txt" || die
	fi

	# Build the Go binary with version metadata injected
	CGO_ENABLED=0 go build \
		-ldflags="-X main.version=${PV} -X main.commit=${EGIT_COMMIT} -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
		-o llama-swap || die "go build failed"
}

src_install() {
	exeinto /usr/bin
	doexe llama-swap
}

pkg_postinst() {
	elog "llama-swap ${PV} has been installed to /usr/bin/llama-swap"
	elog ""
	elog "llama-swap is an OpenAI-compatible proxy that hot-swaps between"
	elog "local LLM inference backends (llama.cpp, vllm, tabbyAPI, etc.)"
	elog ""
	elog "Create a config.yaml and run:"
	elog "  llama-swap --config config.yaml"
	elog ""
	elog "Documentation: https://github.com/mostlygeek/llama-swap"
}
