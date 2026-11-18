#!/usr/bin/env bash
# =====================================================================
#  build-debs-ubuntu.sh — costruisce i pacchetti del tema KuboOS adattati
#  a Ubuntu Server 26.04 (variante "kuboview") partendo dai sorgenti KuboOS.
#
#  Uso:  bash tools/build-debs-ubuntu.sh /percorso/repo/kuboos  [cartella-out]
#
#  Differenze rispetto ai pacchetti della distro KuboOS:
#   - niente dpkg-divert di /usr/lib/os-release (Ubuntu resta Ubuntu)
#   - niente snapshot Timeshift prima di apt e niente grub-btrfs (Ubuntu
#     Server installa su ext4): via le dipendenze timeshift e grub-btrfs
#   - versione con suffisso +kuboview
# =====================================================================
set -euo pipefail
SRC=$(cd "${1:?serve il percorso del repo kuboos}" && pwd)/packages
OUT=$(mkdir -p "${2:-dist}" && cd "${2:-dist}" && pwd)
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

# versione dei pacchetti di base KuboOS
BASEVER=$(awk '/^Version:/{print $2}' "$SRC/kuboos-look/DEBIAN/control")
VER="${BASEVER}+kuboview1"

cp -a "$SRC/kuboos-look" "$SRC/kuboos-defaults" "$W/"
cd "$W"

# --- kuboos-look: identico, cambia solo la versione
sed -i "s/^Version:.*/Version: ${VER}/" kuboos-look/DEBIAN/control

# --- kuboos-defaults: togli ciò che è "da distro"
D=kuboos-defaults
rm -f  $D/etc/apt/apt.conf.d/80-kuboos-snapshot \
       $D/usr/lib/kuboos/pre-apt-snapshot \
       $D/usr/lib/kuboos/os-release
rm -rf $D/usr/lib/systemd/system/grub-btrfsd.service.d
rmdir --ignore-fail-on-non-empty $D/usr/lib/kuboos $D/usr/lib/systemd/system $D/usr/lib/systemd 2>/dev/null || true

sed -i -E \
  -e "s/^Version:.*/Version: ${VER}/" \
  -e 's/^(Depends:.*)$/\1,/' \
  -e '/^Depends:/ s/ (timeshift|grub-btrfs),//g' \
  -e '/^Depends:/ s/,$//' \
  -e 's/^Description:.*/Description: Impostazioni predefinite KuboOS per Ubuntu (KuboView): zram, desktop, SDDM, Wi-Fi nel sistema/' \
  $D/DEBIAN/control
grep -vE '80-kuboos-snapshot' $D/DEBIAN/conffiles > $D/DEBIAN/conffiles.new && mv $D/DEBIAN/conffiles.new $D/DEBIAN/conffiles

cat > $D/DEBIAN/postinst <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
  systemctl daemon-reload >/dev/null 2>&1 || true
  # --- RAM: avvisi di aggiornamento di Discover (~120 MB) fuori da autostart;
  # Discover resta disponibile dal menu
  mkdir -p /usr/share/kuboos/autostart-disattivati
  dpkg-divert --package kuboos-defaults --add --rename \
    --divert /usr/share/kuboos/autostart-disattivati/org.kde.discover.notifier.desktop \
    /etc/xdg/autostart/org.kde.discover.notifier.desktop >/dev/null
  systemctl --global unmask plasma-kaccess.service >/dev/null 2>&1 || true
  # servizio di unattended-upgrades che aspetta lo spegnimento (~30 MB);
  # gli aggiornamenti automatici restano (timer apt-daily-upgrade)
  systemctl disable unattended-upgrades.service >/dev/null 2>&1 || true
  # --- avvio: logo Plymouth KuboOS e menu GRUB nero/ambra
  if command -v plymouth-set-default-theme >/dev/null && [ -f /usr/share/plymouth/themes/kuboos/kuboos.plymouth ]; then
    plymouth-set-default-theme kuboos || true
    update-initramfs -u >/dev/null 2>&1 || true
  fi
  if [ -d /boot/grub ] && command -v update-grub >/dev/null; then update-grub >/dev/null 2>&1 || true; fi
fi
EOF
cat > $D/DEBIAN/postrm <<'EOF'
#!/bin/sh
set -e
if [ "$1" = remove ] || [ "$1" = purge ]; then
  dpkg-divert --package kuboos-defaults --remove --rename \
    --divert /usr/share/kuboos/autostart-disattivati/org.kde.discover.notifier.desktop \
    /etc/xdg/autostart/org.kde.discover.notifier.desktop || true
  systemctl enable unattended-upgrades.service >/dev/null 2>&1 || true
  if [ "$(plymouth-set-default-theme 2>/dev/null)" = kuboos ]; then
    plymouth-set-default-theme --reset || true
    update-initramfs -u >/dev/null 2>&1 || true
  fi
  if [ -d /boot/grub ] && command -v update-grub >/dev/null; then update-grub >/dev/null 2>&1 || true; fi
fi
EOF
chmod 755 $D/DEBIAN/postinst $D/DEBIAN/postrm

# --- costruzione: nomi fissi, così l'installer usa sempre releases/latest/download/<nome>.deb
for d in kuboos-look kuboos-defaults; do
  find "$d" -type d -exec chmod 755 {} +
  dpkg-deb --root-owner-group -Zxz --build "$d" "$OUT/$d.deb" >/dev/null
done
ls -la "$OUT"
