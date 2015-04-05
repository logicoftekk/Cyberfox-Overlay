# Cyberfox-Overlay
Unofficial [portage][external-portage] overlay for [Gentoo Linux][external-gentoo] providing ebuilds for [Cyberfox][external-cyberfox]

### Using Layman
If you do not know what `layman` is then please read the [documentation][docs-layman] first.

1. `emerge -av layman`
2. Modify `/etc/layman/layman.cfg`:

        overlays  : https://raw.github.com/logicoftekk/Cyberfox-Overlay/master/repositories.xml

3. `layman -L`
4. `layman -a cyberfox-overlay`

[docs-layman]: https://www.gentoo.org/proj/en/overlays/userguide.xml


## Available ebuilds
            www-client/cyberfox
            www-client/cyberfox-bin

* * *
### Credits
- [Contributors][contrib-people]
- [Gentoo Linux][external-gentoo]
- [Cyberfox][external-cyberfox]

[external-portage]: https://wiki.gentoo.org/wiki/Project:Portage
[contrib-people]: https://github.com/logicoftekk/Cyberfox-Overlay/graphs/contributors
[external-gentoo]: https://www.gentoo.org/
[external-cyberfox]: https://8pecxstudios.com/cyberfox-web-browser
