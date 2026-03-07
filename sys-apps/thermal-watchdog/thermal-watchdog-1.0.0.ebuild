# Copyright 2026 Alec
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit systemd

DESCRIPTION="Thermal watchdog daemon — reboots at 92C (k10temp)"
HOMEPAGE="https://github.com/alec/gentoo-alec-local-overlay"
SRC_URI=""
S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"

DEPEND=""
RDEPEND=""
BDEPEND="sys-devel/gcc"

src_unpack() {
	cp "${FILESDIR}"/thermal-watchdog.c "${S}/" || die
	cp "${FILESDIR}"/Makefile "${S}/" || die
}

src_compile() {
	emake
}

src_install() {
	dobin thermal-watchdog
	systemd_dounit "${FILESDIR}"/thermal-watchdog.service
}

pkg_postinst() {
	elog "Enable with: systemctl enable --now thermal-watchdog"
}
