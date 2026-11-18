#!/usr/bin/env bash
# =====================================================================
#  install.sh — installer KuboOS
#  Sistema base installato SENZA desktop  ->  KDE Plasma 6 minimale
#
#  Basi supportate:
#    - Ubuntu Server 26.04 LTS  (snap rimossi e bloccati per sempre)
#    - Debian 13 "trixie"
#  (Ubuntu 24.04 NON è supportata: ha Plasma 5, il tema KuboOS è per Plasma 6)
#
#  Cosa installa: solo Plasma essenziale + app di base + KDE Connect
#                 + tema KuboOS (pacchetti kuboos-look e kuboos-defaults)
#  Baloo e KWallet restano installati (dipendenze obbligatorie di KDE)
#  ma vengono DISATTIVATI. Sessione predefinita: X11 (niente lag mouse).
#  Variabili:  SCALE=1|2 (scala schermo)   KUBOOS=0 (senza tema)
#
#  Uso:  wget -qO- https://raw.githubusercontent.com/danymarchetti2000-ita/KuboView/main/install.sh | sudo bash
# =====================================================================
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Esegui con sudo (es. wget -qO- <link> | sudo bash)"; exit 1; }
export DEBIAN_FRONTEND=noninteractive
SCALE="${SCALE:-2}"   # 2 = 200% (schermo 14" 2560x1440). Per Full HD: SCALE=1
KUBOOS="${KUBOOS:-1}" # 1 = applica il tema KuboOS, 0 = solo Plasma minimale
TEMA_URL="${TEMA_URL:-https://github.com/danymarchetti2000-ita/KuboView/releases/latest/download}"
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"

log() { printf '\n\033[1;33m== %s ==\033[0m\n' "$*"; }

. /etc/os-release
case "${ID}:${VERSION_CODENAME:-}" in
  ubuntu:resolute) DISTRO=ubuntu ;;
  debian:trixie)   DISTRO=debian ;;
  ubuntu:noble)    echo "Ubuntu 24.04 ha Plasma 5: serve Ubuntu Server 26.04 o Debian 13."; exit 1 ;;
  *)               echo "Sistema non supportato: ${PRETTY_NAME:-?}"; exit 1 ;;
esac
log "Sistema rilevato: ${PRETTY_NAME}  (kernel $(uname -r))"

# ---------------------------------------------------------------------
if [[ $DISTRO == ubuntu ]]; then
  log "1/8  Ubuntu: rimozione completa di snap"
  if command -v snap >/dev/null 2>&1; then
    for _ in 1 2 3; do
      for s in $(snap list 2>/dev/null | awk 'NR>1 {print $1}'); do
        snap remove --purge "$s" 2>/dev/null || true
      done
    done
  fi
  systemctl disable --now snapd.socket snapd.service snapd.seeded.service 2>/dev/null || true
  apt-get purge -y snapd 2>/dev/null || true
  rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd "/home/${USER_NAME}/snap" /root/snap
  cat > /etc/apt/preferences.d/no-snap.pref <<'EOF'
# KuboOS: snapd bloccato, nessun pacchetto può reinstallarlo
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
else
  log "1/8  Debian: abilito contrib, non-free, non-free-firmware"
  if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
    sed -i -E 's/^Components:.*/Components: main contrib non-free non-free-firmware/' \
      /etc/apt/sources.list.d/debian.sources
  fi
  if [[ -f /etc/apt/sources.list ]]; then
    sed -i -E '/^deb(-src)? .*(debian|security)/ s/ main( .*)?$/ main contrib non-free non-free-firmware/' \
      /etc/apt/sources.list
    sed -i -E '/^deb(-src)? cdrom:/ s/^/# /' /etc/apt/sources.list
  fi
fi

# ---------------------------------------------------------------------
log "2/8  Firefox ufficiale Mozilla (.deb, niente snap né ESR)"
# ---------------------------------------------------------------------
apt-get update
apt-get install -y --no-install-recommends wget ca-certificates gnupg sudo
install -d -m 0755 /etc/apt/keyrings
wget -qO /etc/apt/keyrings/packages.mozilla.org.asc \
  https://packages.mozilla.org/apt/repo-signing-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  > /etc/apt/sources.list.d/mozilla.list
cat > /etc/apt/preferences.d/mozilla.pref <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
if [[ $DISTRO == ubuntu ]]; then
  # il pacchetto "firefox" di Ubuntu installa la snap: bloccato
  cat >> /etc/apt/preferences.d/mozilla.pref <<'EOF'

Package: firefox*
Pin: release o=Ubuntu
Pin-Priority: -1
EOF
fi

# ---------------------------------------------------------------------
log "3/8  KDE Plasma 6 minimale (senza pacchetti consigliati)"
# ---------------------------------------------------------------------
PKGS=(
  # cuore di Plasma
  plasma-desktop plasma-workspace plasma-integration kde-cli-tools
  kwin-x11 kwin-wayland xwayland xserver-xorg xserver-xorg-input-libinput
  breeze kde-style-breeze breeze-gtk-theme kde-config-gtk-style
  xdg-desktop-portal-kde polkit-kde-agent-1
  # accesso e blocco schermo
  sddm sddm-theme-breeze kde-config-sddm kde-config-screenlocker
  # impostazioni e hardware
  systemsettings kinfocenter kscreen powerdevil
  plasma-nm network-manager plasma-pa pipewire-audio wireplumber
  bluedevil bluez
  # app essenziali
  dolphin kio-extras konsole kate ark kde-spectacle gwenview okular
  plasma-systemmonitor
  # KDE Connect, software, Flatpak
  kdeconnect plasma-discover plasma-discover-backend-flatpak flatpak
  # font, browser, utility
  fonts-noto-core fonts-noto-color-emoji xdg-user-dirs
  firefox firefox-l10n-it
)
# Ubuntu divide le sessioni Plasma in pacchetti separati
[[ $DISTRO == ubuntu ]] && PKGS+=(plasma-session-x11 plasma-session-wayland linux-firmware)

apt-get update
apt-get install -y --no-install-recommends "${PKGS[@]}"

# ---------------------------------------------------------------------
log "4/8  Tema KuboOS e alleggerimento (Baloo e KWallet disattivati)"
# ---------------------------------------------------------------------
if [[ $KUBOOS == 1 ]]; then
  T=$(mktemp -d)
  for d in kuboos-look kuboos-defaults; do
    wget -q --show-progress -O "$T/$d.deb" "$TEMA_URL/$d.deb"
  done
  chmod 755 "$T"; chmod 644 "$T"/*.deb
  # kuboos-defaults porta già: kdeglobals, KWin Platinum, Baloo spento,
  # Wi-Fi salvato nel sistema, SDDM, zram, earlyoom, GRUB/Plymouth KuboOS
  apt-get install -y --no-install-recommends "$T/kuboos-look.deb" "$T/kuboos-defaults.deb"
  rm -rf "$T"
else
  mkdir -p /etc/xdg
  cat > /etc/xdg/baloofilerc <<'EOF'
[Basic Settings]
Indexing-Enabled=false
EOF
fi
mkdir -p /etc/xdg
cat > /etc/xdg/kwalletrc <<'EOF'
[Wallet]
Enabled=false
First Use=false
EOF

# ---------------------------------------------------------------------
log "5/8  HiDPI (${SCALE}x) e sessione X11 predefinita"
# ---------------------------------------------------------------------
DPI=$((96 * SCALE))
# scala dello schermo nella configurazione dell'utente (non tocca i file del tema)
if [[ $USER_NAME != root ]]; then
  H=$(getent passwd "$USER_NAME" | cut -d: -f6)
  install -d -o "$USER_NAME" -g "$USER_NAME" "$H/.config"
  if ! grep -q '^\[KScreen\]' "$H/.config/kdeglobals" 2>/dev/null; then
    printf '\n[KScreen]\nScaleFactor=%s\n' "$SCALE" >> "$H/.config/kdeglobals"
    chown "$USER_NAME:$USER_NAME" "$H/.config/kdeglobals"
  fi
fi
cat > /etc/xdg/kcmfonts <<EOF
[General]
forceFontDPI=${DPI}
EOF
mkdir -p /etc/sddm.conf.d /var/lib/sddm
if [[ $KUBOOS == 1 ]]; then
  # SDDM di KuboOS (schermata di accesso su Wayland): aggiungo solo la scala
  cat > /etc/sddm.conf.d/20-kuboview-hidpi.conf <<EOF
[General]
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell,QT_SCALE_FACTOR=${SCALE}
EOF
else
  cat > /etc/sddm.conf.d/10-kuboview.conf <<EOF
[Theme]
Current=breeze

[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=${SCALE},QT_FONT_DPI=${DPI}

[X11]
ServerArguments=-nolisten tcp -dpi ${DPI}
EOF
fi
# al primo accesso SDDM propone la sessione X11 (poi ricorda l'ultima scelta)
cat > /var/lib/sddm/state.conf <<'EOF'
[Last]
Session=/usr/share/xsessions/plasmax11.desktop
EOF
chown -R sddm:sddm /var/lib/sddm 2>/dev/null || true

# ---------------------------------------------------------------------
log "6/8  Rete gestita da NetworkManager"
# ---------------------------------------------------------------------
if [[ $DISTRO == ubuntu ]]; then
  # da systemd-networkd (server) a NetworkManager (desktop)
  apt-get purge -y cloud-init 2>/dev/null || true
  rm -rf /etc/cloud /var/lib/cloud
  mkdir -p /etc/netplan/backup-server
  find /etc/netplan -maxdepth 1 -name '*.yaml' -exec mv {} /etc/netplan/backup-server/ \;
  cat > /etc/netplan/01-network-manager-all.yaml <<'EOF'
network:
  version: 2
  renderer: NetworkManager
EOF
  chmod 600 /etc/netplan/01-network-manager-all.yaml
  netplan generate
  systemctl disable systemd-networkd.service 2>/dev/null || true
  systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
else
  # da ifupdown a NetworkManager
  if [[ -f /etc/network/interfaces ]] && grep -qvE '^\s*(#|$|auto lo|iface lo|source)' /etc/network/interfaces; then
    cp /etc/network/interfaces /etc/network/interfaces.backup-kuboos
    cat > /etc/network/interfaces <<'EOF'
# Le interfacce sono gestite da NetworkManager (backup: interfaces.backup-kuboos)
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
EOF
  fi
fi
systemctl enable NetworkManager

# ---------------------------------------------------------------------
log "7/8  Flathub e avvio grafico"
# ---------------------------------------------------------------------
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
systemctl enable sddm
systemctl set-default graphical.target
[[ $USER_NAME != root ]] && sudo -u "$USER_NAME" xdg-user-dirs-update 2>/dev/null || true

# ---------------------------------------------------------------------
log "8/8  Pulizia"
# ---------------------------------------------------------------------
apt-get autoremove -y --purge
apt-get clean

log "FATTO — riavvia con:  sudo reboot"
cat <<'EOF'
Dopo il riavvio:
 - Wi-Fi: collegati dall'icona di rete (la password resta nel sistema, non in KWallet)
 - Scala: se serve, Impostazioni di sistema -> Schermo -> Scala
 - Sessione: in basso nella schermata di accesso puoi scegliere X11 o Wayland
EOF
