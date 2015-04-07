EAPI="5"

inherit eutils multilib pax-utils fdo-mime gnome2-utils nsplugins

DESCRIPTION="Cyberfox Web Browser"
SRC_URI="http://downloads.sourceforge.net/project/cyberfox/Zipped%20Format/Cyberfox-37.0.1.en-US.linux-x86_64.tar.bz2"
HOMEPAGE="http://8pecxstudios.com/cyberfox-web-browser"
RESTRICT="strip mirror"

KEYWORDS="-* ~amd64"
SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="selinux startup-notification"

DEPEND="app-arch/unzip"
RDEPEND="dev-libs/atk
	>=sys-apps/dbus-0.60
	>=dev-libs/dbus-glib-0.72
	>=dev-libs/glib-2.26:2
	>=media-libs/alsa-lib-1.0.16
	media-libs/fontconfig
	>=media-libs/freetype-2.4.10
	>=x11-libs/cairo-1.10[X]
	x11-libs/gdk-pixbuf
	>=x11-libs/gtk+-2.14:2
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrender
	x11-libs/libXt
	>=x11-libs/pango-1.22.0
	virtual/freedesktop-icon-theme
	selinux? ( sec-policy/selinux-mozilla )
"

QA_PREBUILT="
	opt/${PN}/*.so
	opt/${PN}/${PN}
	opt/${PN}/${PN/-bin}
	opt/${PN}/webapprt-stub
	opt/${PN}/plugin-container
"

S="${WORKDIR}/Cyberfox"

src_install() {
	declare MOZILLA_FIVE_HOME=/opt/${PN}

	local size sizes icon_path icon name
	sizes="16 32 48"
	icon_path="${S}/browser/chrome/icons/default"
	icon="${PN}"
	name="Cyberfox"

	# Install icons and .desktop for menu entry
	for size in ${sizes}; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		newins "${icon_path}/default${size}.png" "${icon}.png" || die
	done

	# The 128x128 icon has a different name
	insinto "/usr/share/icons/hicolor/128x128/apps"
	newins "${S}/browser/icons/mozicon128.png" "${icon}.png" || die
	# Install a 48x48 icon into /usr/share/pixmaps for legacy DEs
	newicon "${icon_path}/default48.png" "${PN}.png"
	domenu "${FILESDIR}/${PN}.desktop"
	sed -i -e "s:@NAME@:${name}:" -e "s:@ICON@:${icon}:" \
		"${ED}/usr/share/applications/${PN}.desktop" || die

	# Add StartupNotify=true bug 237317
	if use startup-notification; then
		echo "StartupNotify=true" >> "${D}/usr/share/applications/${PN}.desktop" || die
	fi

	# Install Cyberfox in /opt
	dodir ${MOZILLA_FIVE_HOME%/*}
	mv "${S}" "${D}"${MOZILLA_FIVE_HOME} || die

	# Fix prefs that make no sense for a system-wide install
	insinto ${MOZILLA_FIVE_HOME}/defaults/pref/
	doins "${FILESDIR}/local-settings.js"
	# Copy preferences file so we can do a simple rename.
	insinto "${MOZILLA_FIVE_HOME}"
	doins "${FILESDIR}/gentoo-default-prefs.js"

	# Create /usr/bin/cyberfox-bin
	dodir /usr/bin/
	cat <<-EOF >"${D}"/usr/bin/${PN}
	#!/bin/sh
	unset LD_PRELOAD
	LD_LIBRARY_PATH="/opt/cyberfox-bin/"
	GTK_PATH=/usr/lib/gtk-2.0/
	exec /opt/${PN}/Cyberfox-bin "\$@"
	EOF
	fperms 0755 /usr/bin/${PN}

	# revdep-rebuild entry
	insinto /etc/revdep-rebuild
	echo "SEARCH_DIRS_MASK=${MOZILLA_FIVE_HOME}" >> ${T}/10${PN}
	doins "${T}"/10${PN} || die

	# Plugins dir
	share_plugins_dir

	# Required in order to use plugins and even run firefox on hardened.
	pax-mark mr "${ED}"/${MOZILLA_FIVE_HOME}/{cyberfox,cyberfox-bin,plugin-container}
}

pkg_preinst() {
	gnome2_icon_savelist
}

pkg_postinst() {
	# Update mimedb for the new .desktop file
	fdo-mime_desktop_database_update
	gnome2_icon_cache_update
}

pkg_postrm() {
	gnome2_icon_cache_update
}
