# KuboView — installer KuboOS

Trasforma un sistema **installato senza desktop** in un desktop **KDE Plasma 6
minimale**, pronto per il tema KuboOS.

Basi supportate: **Ubuntu Server 26.04 LTS** (snap rimossi e bloccati) e **Debian 13**.
Ubuntu 24.04 non è supportata perché ha ancora Plasma 5.

## Installazione

1. Installa il sistema base:
   - **Ubuntu Server 26.04 LTS**: scegli *Ubuntu Server (minimized)*, non selezionare nessuno snap
   - **Debian 13 netinst**: password di root vuota; in *Selezione del software*
     togli tutti i desktop, tieni *server SSH* e *utilità di sistema standard*
2. Al primo avvio accedi e lancia:

```bash
wget -qO- https://raw.githubusercontent.com/danymarchetti2000-ita/KuboView/main/install.sh | sudo bash
```

3. Riavvia: `sudo reboot`

## Cosa fa

| | |
|---|---|
| Desktop | Plasma 6 con `--no-install-recommends`: solo l'essenziale |
| App | Dolphin, Konsole, Kate, Ark, Spectacle, Gwenview, Okular, Discover + Flatpak, **KDE Connect** |
| Browser | Firefox ufficiale Mozilla (non ESR) |
| Leggerezza | Baloo (indicizzazione) e KWallet **disattivati** |
| Sessione | X11 predefinita al primo accesso |
| HiDPI | scala 200% (modifica `SCALE` nello script per altri schermi) |
| Rete | NetworkManager; le password Wi-Fi restano nel sistema (spunta *"Tutti gli utenti possono connettersi"*) |

Su Ubuntu gli snap vengono rimossi e `snapd` bloccato con un pin APT; Firefox arriva dal repository Mozilla.

Schermo Full HD? Usa `... | sudo env SCALE=1 bash`.
