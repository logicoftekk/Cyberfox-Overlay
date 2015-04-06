// Ensure preference can not be changed by users
lockPref("app.update.auto", false);
lockPref("app.update.enabled", false);
lockPref("intl.locale.matchOS",                true);
// Allow user to change based on needs
defaultPref("browser.display.use_system_colors",  true);
defaultPref("spellchecker.dictionary_path", "/usr/share/myspell");
defaultPref("browser.shell.checkDefaultBrowser",  false);
defaultPref("browser.selfsupport.url", "");
// Preferences that should be reset every session
pref("browser.EULA.override",              true); 

