Pacchetti del tema **KuboOS 0.1.4** adattati a Ubuntu Server 26.04 (funzionano anche su Debian 13).

- `kuboos-look.deb` — palette KuboOS-16, icone pixel art + convertitore automatico, font Chicago, Kvantum, decorazione Platinum, menu KuboOS, GRUB/Plymouth
- `kuboos-defaults.deb` — impostazioni: KWin Platinum (pulsanti a sinistra), Baloo spento, Wi-Fi salvato nel sistema, SDDM, zram, earlyoom

Rispetto ai pacchetti della distro KuboOS: niente modifica di os-release, niente snapshot Timeshift/grub-btrfs.

Li installa da solo `install.sh`. Si rigenerano con `tools/build-debs-ubuntu.sh <repo kuboos> pacchetti`. Icone basate su SerenityOS (BSD-2), font ChicagoFLF (pubblico dominio).
