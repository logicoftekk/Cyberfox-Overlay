EAPI="5"
VIRTUALX_REQUIRED="pgo"
WANT_AUTOCONF="2.1"

MOZCONFIG_OPTIONAL_GTK3=1
MOZCONFIG_OPTIONAL_WIFI=1
MOZCONFIG_OPTIONAL_JIT="enabled"

inherit check-reqs flag-o-matic toolchain-funcs eutils gnome2-utils mozconfig-v6.39 multilib pax-utils fdo-mime autotools virtualx git-r3

DESCRIPTION="Cyberfox Web Browser"
HOMEPAGE="http://8pecxstudios.com/cyberfox-web-browser"

KEYWORDS="~alpha ~amd64 ~arm ~hppa ~ia64 ~ppc ~ppc64 ~x86 ~amd64-linux ~x86-linux"

SLOT="0"
LICENSE="MPL-2.0 GPL-2 LGPL-2.1"
IUSE="bindist egl hardened +minimal neon pgo selinux +gmp-autoupdate test"
RESTRICT="!bindist? ( bindist )"

EGIT_REPO_URI="https://github.com/InternalError503/cyberfox.git"
SRC_URI=""

ASM_DEPEND=">=dev-lang/yasm-1.1"

# Mesa 7.10 needed for WebGL + bugfixes
RDEPEND="
	>=dev-libs/nss-3.19.2
	>=dev-libs/nspr-4.10.8
	selinux? ( sec-policy/selinux-mozilla )"

DEPEND="${RDEPEND}
	pgo? (
		>=sys-devel/gcc-4.5 )
	amd64? ( ${ASM_DEPEND}
		virtual/opengl )
	x86? ( ${ASM_DEPEND}
		virtual/opengl )"

QA_PRESTRIPPED="usr/$(get_libdir)/${PN}/cyberfox"

BUILD_OBJ_DIR="${S}/cf"

pkg_setup() {
	moz_pkgsetup

	# Avoid PGO profiling problems due to enviroment leakage
	# These should *always* be cleaned up anyway
	unset DBUS_SESSION_BUS_ADDRESS \
		DISPLAY \
		ORBIT_SOCKETDIR \
		SESSION_MANAGER \
		XDG_SESSION_COOKIE \
		XAUTHORITY

	if ! use bindist; then
		einfo
		elog "You are enabling official branding. You may not redistribute this build"
		elog "to any users on your network or the internet. Doing so puts yourself into"
		elog "a legal problem with Mozilla Foundation"
		elog "You can disable it by emerging ${PN} _with_ the bindist USE-flag"
	fi

	if use pgo; then
		einfo
		ewarn "You will do a double build for profile guided optimization."
		ewarn "This will result in your build taking at least twice as long as before."
	fi
}

pkg_pretend() {
	# Ensure we have enough disk space to compile
	if use pgo || use debug || use test ; then
		CHECKREQS_DISK_BUILD="8G"
	else
		CHECKREQS_DISK_BUILD="4G"
	fi
	check-reqs_pkg_setup
}

src_unpack() {
	# fetch Cyberfox and CyberCTR from git
	git-r3_fetch https://github.com/InternalError503/CyberCTR.git HEAD
	git-r3_checkout https://github.com/InternalError503/CyberCTR.git "${WORKDIR}"/cyberctr
	git-r3_fetch
	git-r3_checkout
}

src_prepare() {
	# Apply our patches
	epatch "${FILESDIR}"/install_dirs.patch
	epatch "${FILESDIR}"/allow_locked_prefs.patch
	epatch "${FILESDIR}"/avoid_spurious_run_items_in_application_handlers.patch
	epatch "${FILESDIR}"/add_alpha_defines_in_ipc.patch
	epatch "${FILESDIR}"/drop-Wl-build-id.patch
	epatch "${FILESDIR}"/freebsd_jscpucfg.patch
	epatch "${FILESDIR}"/freebsd_libexecinfo.patch
	epatch "${FILESDIR}"/hppa_js_configure.patch
	epatch "${FILESDIR}"/hppa-js-syntax-error.patch

	epatch "${FILESDIR}"/${PN}-35.0-gmp-clearkey-sprintf.patch
	epatch "${FILESDIR}"/${PN}-37.0-jemalloc_configure_unbashify.patch

	# Allow user to apply any additional patches without modifing ebuild
	epatch_user

	# fix permissions
	chmod -R +x "${S}"

	# Enable gnomebreakpad
	if use debug ; then
		sed -i -e "s:GNOME_DISABLE_CRASH_DIALOG=1:GNOME_DISABLE_CRASH_DIALOG=0:g" \
			"${S}"/build/unix/run-mozilla.sh || die "sed failed!"
	fi

	# Ensure that our plugins dir is enabled as default
	sed -i -e "s:/usr/lib/mozilla/plugins:/usr/lib/nsbrowser/plugins:" \
		"${S}"/xpcom/io/nsAppFileLocationProvider.cpp || die "sed failed to replace plugin path for 32bit!"
	sed -i -e "s:/usr/lib64/mozilla/plugins:/usr/lib64/nsbrowser/plugins:" \
		"${S}"/xpcom/io/nsAppFileLocationProvider.cpp || die "sed failed to replace plugin path for 64bit!"

	# Fix sandbox violations during make clean, bug 372817
	sed -e "s:\(/no-such-file\):${T}\1:g" \
		-i "${S}"/config/rules.mk \
		-i "${S}"/nsprpub/configure{.in,} \
		|| die

	# Don't exit with error when some libs are missing which we have in system
	sed '/^MOZ_PKG_FATAL_WARNINGS/s@= 1@= 0@' \
		-i "${S}"/browser/installer/Makefile.in || die

	# Don't error out when there's no files to be removed
	sed 's@\(xargs rm\)$@\1 -f@' \
		-i "${S}"/toolkit/mozapps/installer/packager.mk || die

	eautoreconf

	# Must run autoconf in js/src
	cd "${S}"/js/src || die
	eautoconf

	# Need to update jemalloc's configure
	cd "${S}"/memory/jemalloc/src || die
	WANT_AUTOCONF= eautoconf
}

src_configure() {
	MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"
	MEXTENSIONS="default"
	# Google API keys (see http://www.chromium.org/developers/how-tos/api-keys)
	# Note: These are for Gentoo Linux use ONLY. For your own distribution, please
	# get your own set of keys.
	_google_api_key=AIzaSyDEAOvatFo0eTgsV_ZlEzx0ObmepsMzfAc

	####################################
	#
	# mozconfig, CFLAGS and CXXFLAGS setup
	#
	####################################

	mozconfig_init
	mozconfig_config

	# It doesn't compile on alpha without this LDFLAGS
	use alpha && append-ldflags "-Wl,--no-relax"

	# Add full relro support for hardened
	use hardened && append-ldflags "-Wl,-z,relro,-z,now"

	if use neon ; then
		mozconfig_annotate '' --with-fpu=neon
		mozconfig_annotate '' --with-thumb=yes
		mozconfig_annotate '' --with-thumb-interwork=no
	fi
	if [[ ${CHOST} == armv* ]] ; then
		mozconfig_annotate '' --with-float-abi=hard
		mozconfig_annotate '' --enable-skia
		if ! use system-libvpx ; then
			sed -i -e "s|softfp|hard|" \
				"${S}"/media/libvpx/moz.build
		fi
	fi
	use egl && mozconfig_annotate 'Enable EGL as GL provider' --with-gl-provider=EGL
	# Setup api key for location services
	echo -n "${_google_api_key}" > "${S}"/google-api-key
	mozconfig_annotate '' --with-google-api-keyfile="${S}/google-api-key"

	# Branding
	mozconfig_annotate '' --with-distribution-id=cyberfox
	mozconfig_annotate '' --with-app-name=cyberfox
	mozconfig_annotate '' --with-app-basename=cyberfox
	if use bindist; then
		mozconfig_annotate '' --with-branding=browser/branding/unofficial
	else
		mozconfig_annotate '' --with-branding=browser/branding/official-linux
	fi

	# Config
	mozconfig_annotate '' --enable-extensions="${MEXTENSIONS}"
	mozconfig_annotate '' --disable-mailnews
	mozconfig_annotate '' --enable-release
	mozconfig_annotate '' --enable-stdcxx-compat
	mozconfig_annotate '' --with-pthreads

	# Disable unwanted features
	mozconfig_annotate '' --disable-pay
	mozconfig_annotate '' --disable-metro
	mozconfig_annotate '' --disable-maintenance-service
	mozconfig_annotate '' --disable-services-healthreport
	mozconfig_annotate '' --disable-moz-services-healthreport
	mozconfig_annotate '' --disable-moz_services_healthreport
	mozconfig_annotate '' --disable-data-reporting
	mozconfig_annotate '' --disable-telemetry-reporting
	mozconfig_annotate '' --disable-auto-deps
	mozconfig_annotate '' --disable-ipdl-tests
	mozconfig_annotate '' --disable-update-channel
	mozconfig_annotate '' --disable-update-packaging
	mozconfig_annotate '' --enable-debugger-info-modules=no
	mozconfig_annotate '' --disable-debugger-info-modules
	mozconfig_annotate '' --disable-mochitest
	mozconfig_annotate '' --disable-mochitests
	mozconfig_annotate '' --disable-accessibility
	mozconfig_annotate '' --disable-parental-controls
	mozconfig_annotate '' --disable-logging
	mozconfig_annotate '' --disable-elf-hack

	# Other settings
	mozconfig_annotate '' --with-default-mozilla-five-home=${MOZILLA_FIVE_HOME}
	mozconfig_annotate '' --enable-ion

	# Allow for a proper pgo build
	if use pgo; then
		echo "mk_add_options PROFILE_GEN_SCRIPT='\$(PYTHON) \$(OBJDIR)/_profile/pgo/profileserver.py'" >> "${S}"/.mozconfig
	fi

	echo "mk_add_options MOZ_OBJDIR=${BUILD_OBJ_DIR}" >> "${S}"/.mozconfig

	# Finalize and report settings
	mozconfig_final

	if [[ $(gcc-major-version) -lt 4 ]]; then
		append-cxxflags -fno-stack-protector
	fi
	# workaround for funky/broken upstream configure...
	emake -f client.mk configure
}

src_compile() {
	if use pgo; then
		addpredict /root
		addpredict /etc/gconf
		# Reset and cleanup environment variables used by GNOME/XDG
		gnome2_environment_reset

		# Cyberfox tries to use dri stuff when it's run, see bug 380283
		shopt -s nullglob
		cards=$(echo -n /dev/dri/card* | sed 's/ /:/g')
		if test -z "${cards}"; then
			cards=$(echo -n /dev/ati/card* /dev/nvidiactl* | sed 's/ /:/g')
			if test -n "${cards}"; then
				# Binary drivers seem to cause access violations anyway, so
				# let's use indirect rendering so that the device files aren't
				# touched at all. See bug 394715.
				export LIBGL_ALWAYS_INDIRECT=1
			fi
		fi
		shopt -u nullglob
		addpredict "${cards}"

		CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
		MOZ_MAKE_FLAGS="${MAKEOPTS}" SHELL="${SHELL}" \
		Xemake -f client.mk profiledbuild || die "Xemake failed"
	else
		CC="$(tc-getCC)" CXX="$(tc-getCXX)" LD="$(tc-getLD)" \
		MOZ_MAKE_FLAGS="${MAKEOPTS}" SHELL="${SHELL}" \
		emake -f client.mk realbuild
	fi
}

src_install() {
	MOZILLA_FIVE_HOME="/usr/$(get_libdir)/${PN}"

	cd "${BUILD_OBJ_DIR}" || die

	# Pax mark xpcshell for hardened support, only used for startupcache creation.
	pax-mark m "${BUILD_OBJ_DIR}"/dist/bin/xpcshell

	# install CyberCTR
	insinto "${MOZILLA_FIVE_HOME}"/distribution
        doins -r "${WORKDIR}"/cyberctr/distribution/*

	# Add our default prefs for cyberfox
	insinto "${MOZILLA_FIVE_HOME}"/defaults/pref/
	doins "${FILESDIR}/local-settings.js"
	cp "${FILESDIR}/gentoo-default-prefs.js" "${S}/gentoo-default-prefs.js"

	local plugin
	use gmp-autoupdate || for plugin in \
	gmp-gmpopenh264 ; do
		echo "pref(\"media.${plugin}.autoupdate\", false);" >> \
			"${S}/gentoo-default-prefs.js" \
			|| die
	done

	insinto "${MOZILLA_FIVE_HOME}"
	doins "${S}/gentoo-default-prefs.js"

	MOZ_MAKE_FLAGS="${MAKEOPTS}" \
	emake DESTDIR="${D}" install
	insinto /
	local size sizes icon_path icon name
	if use bindist; then
		sizes="16 22 24 32 48 256"
		icon_path="${S}/browser/branding/unofficial"
		icon="${PN}"
		name="Cyberfox"
	else
		sizes="16 22 24 32 48 256"
		icon_path="${S}/browser/branding/official-linux"
		icon="${PN}"
		name="Cyberfox"
	fi

	# Install icons and .desktop for menu entry
	for size in ${sizes}; do
		insinto "/usr/share/icons/hicolor/${size}x${size}/apps"
		newins "${icon_path}/default${size}.png" "${icon}.png" || die
	done
	# The 128x128 icon has a different name
	insinto "/usr/share/icons/hicolor/128x128/apps"
	newins "${icon_path}/mozicon128.png" "${icon}.png" || die
	# Install a 48x48 icon into /usr/share/pixmaps for legacy DEs
	newicon "${icon_path}/content/icon48.png" "${icon}.png"
	newmenu "${FILESDIR}/icon/${PN}.desktop" "${PN}.desktop"
	sed -i -e "s:@NAME@:${name}:" -e "s:@ICON@:${icon}:" \
		"${ED}/usr/share/applications/${PN}.desktop" || die

	# Add StartupNotify=true bug 237317
	if use startup-notification ; then
		echo "StartupNotify=true"\
			 >> "${ED}/usr/share/applications/${PN}.desktop" \
			|| die
	fi

	# Required in order to use plugins and even run cyberfox on hardened.
	if use jit; then
		pax-mark m "${ED}"${MOZILLA_FIVE_HOME}/{cyberfox,cyberfox-bin,plugin-container}
	else
		pax-mark m "${ED}"${MOZILLA_FIVE_HOME}/plugin-container
	fi

	if use minimal; then
		rm -r "${ED}"/usr/include "${ED}${MOZILLA_FIVE_HOME}"/{idl,include,lib,sdk} \
			|| die "Failed to remove sdk and headers"
	fi

	# revdep-rebuild entry
	insinto /etc/revdep-rebuild
	echo "SEARCH_DIRS_MASK=${MOZILLA_FIVE_HOME}" >> ${T}/10${PN}
	doins "${T}"/10${PN} || die
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
