// Ensure preference can not be changed by users
lockPref("app.update.auto", false);
lockPref("app.update.enabled", false);
lockPref("app.update.autoInstallEnabled", false);
lockPref("intl.locale.matchOS", true);
// Allow user to change based on needs
defaultPref("browser.display.use_system_colors", true);
defaultPref("browser.privatebrowsing.autostart", true);
defaultPref("browser.search.suggest.enabled", false);
defaultPref("browser.urlbar.suggest.bookmark", false);
defaultPref("browser.urlbar.suggest.history", false);
defaultPref("browser.urlbar.suggest.openpage", false);
defaultPref("browser.selfsupport.url", "");
defaultPref("browser.shell.checkDefaultBrowser", false);
defaultPref("geo.enabled", false);
defaultPref("media.peerconnection.enabled", false);
// Preferences that should be reset every session
pref("browser.EULA.override", true);