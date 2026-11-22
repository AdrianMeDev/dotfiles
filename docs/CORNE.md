# Corne v4 (Vial)

Das Layout liegt in [`corne_v4.vil`](../corne_v4.vil) (Vial-Protokoll `6`, VIA-Protokoll `9`, 6 Layer, keine Makros).
Alle Vertrags-Bindings aus [`manifests/keybindings.tsv`](../manifests/keybindings.tsv) sind über einen einzelnen Layer-Hold erreichbar und werden durch [`tests/test_corne_layout.py`](../tests/test_corne_layout.py) geprüft.

## Layer-Übersicht

### Layer 0 – Base

```text
Linke Hälfte                                         Rechte Hälfte
Tab    Q      W      E      R      T     [MO(1)]     [MO(5)] Y      U      I      O      P      Bspc
Esc    A      S      D      F      G     [MO(2)]     [MO(4)] H      J      K      L      ;      '
LShift Z      X      C      V      B                         N      M      ,      .      /      RShift
                     MO(3)  LAlt   LT(2,Space)       LT(1,Enter) LT(5,Bspc) LT(4,RAlt)
```

### Layer 1 – Symbole (`MO(1)` oder `LT(1, Enter)` halten)

```text
Linke Hälfte                                         Rechte Hälfte
·      !      @      #      $      %      ·          ·      &      *      =      +      &      ·
`      [      {      (      <      \      ·          ·      '      ]      }      )      >      /
·      -      _      :      ?      "                        .      ,      ;      ?      "      ·
                     ·      ·      ·                 ·      ·      ·
```

### Layer 2 – Navigation & Bearbeiten (`MO(2)` oder `LT(2, Space)` halten)

```text
Linke Hälfte                                         Rechte Hälfte
·      ·      ·      ·      ·      ·      ·          ·      Ins    Home   PgUp   PgDn   End    Del
·      LGui   LAlt   LCtrl  LShift ·      ·          ·      Left   Down   Up     Right  End    Esc
·      C-z    C-x    C-c    C-v    ·                        Home   Del    PgDn   PgUp   Ins    ·
                     ·      ·      ·                 ·      ·      ·
```

### Layer 3 – WM, Medien & RGB (`MO(3)` auf dem linken Daumen halten)

```text
Linke Hälfte                                         Rechte Hälfte
RGBTog A-Q    A-Ent  A-Spc  A-R    A-F    RGBMod     MNext  A-1    A-2    A-3    A-4    A-5    Mute
RGBHui A-P    A-H    A-J    A-K    A-L    RGBHud     MPrev  A-6    A-7    A-8    A-9    Win-L  MPly
·      A-S    A-V    A-X    RGBSai RGBSad                   A-Left A-Down A-Up   A-Rgt  MStp   W-S-S
                     ·      RGBVai RGBVad            Win-V  VolUp  VolDn
```

- `A-…` = `Alt+…`, `W-S-S` = `Win+Shift+S`.
- `LShift` auf Layer 0 (`r2c0`) bleibt auf Layer 3 transparent (`KC_TRNS`), sodass `LShift + MO(3) + Taste` direkt die jeweilige `Alt+Shift+…`-Kombination sendet.

### Layer 4 – Deutsche Umlaute (`MO(4)` oder `LT(4, RAlt)` halten)

```text
Linke Hälfte                                         Rechte Hälfte
·      ·      ·      ·      ·      ·      ·          ·      ·      ·      ·      ·      ·      ·
·      RAlt-A RAlt-S ·      ·      ·      ·          ·      ·      ·      ·      ·      ·      ·
·      ·      ·      ·      ·      ·                        ·      ·      ·      ·      ·      ·
                     ·      ·      ·                 ·      ·      ·
```

(Mit dem EurKEY-Layout (Linux: xkb `eu`; Windows: manuell installieren, siehe `windows/README.md`) ergeben `RAlt+A/S/O/U` die Zeichen `ä`, `ß`, `ö`, `ü`; `RAlt+O` und `RAlt+U` liegen auf der rechten oberen Buchstabenreihe `O` bzw. `U`.)

### Layer 5 – Zahlen & Operatoren (`MO(5)` oder `LT(5, Bspc)` halten)

```text
Linke Hälfte                                         Rechte Hälfte
·      1      2      3      4      5      ·          ·      —      —      —      —      —      ·
·      6      7      8      9      0      ·          ·      +      -      *      /      =      ·
·      LGui   LAlt   LCtrl  LShift —                        (      )      [      ]      \      ·
                     ·      ·      ·                 ·      ·      ·
```

## Vertrags-Bindings auf dem Corne

| Aktion (`manifests/keybindings.tsv`) | Vertrag (Linux / Windows) | Corne-Akkord |
| --- | --- | --- |
| Fokus links / unten / oben / rechts | `alt+h/j/k/l` oder `alt+pfeile` | `MO(3) + H/J/K/L` oder `MO(3) + N/M/,/.` |
| Fenster verschieben | `alt+shift+h/j/k/l` oder `alt+shift+pfeile` | `LShift + MO(3) + H/J/K/L` oder `N/M/,/.` |
| Workspace 1–9 wechseln | `alt+1..9` | `MO(3) + Y/U/I/O/P` (1–5) bzw. `H/J/K/L` (6–9) |
| Fenster auf Workspace 1–9 | `alt+shift+1..9` | `LShift + MO(3) + Y/U/I/O/P` bzw. `H/J/K/L` |
| Fenster schließen / Terminal / Launcher | `alt+q` / `alt+enter` / `alt+space` | `MO(3) + Q` / `W` / `E` |
| Resize-Modus / Vollbild | `alt+r` / `alt+f` | `MO(3) + R` / `T` |
| Resize-Modus steuern / beenden | `h/j/k/l`, `pfeile`, `esc`, `enter`, `alt+r` | Layer 0 `H/J/K/L`, `Esc`, `Enter`, `MO(2)`-Pfeile, `MO(3) + R` |
| Schwebendes Fenster | `alt+shift+space` | `LShift + MO(3) + E` (oder `LAlt + LShift + Space`) |
| Reload / Pause | `alt+shift+r` / `alt+shift+p` | `LShift + MO(3) + R` / `A` |
| Lock | `alt+shift+x` (Linux) / `win+l` (Windows) | `LShift + MO(3) + F` (Linux) / `MO(3) + ;` (Windows) |
| Zwischenablage-Verlauf | `alt+v` (Linux) / `win+v` (Windows) | `MO(3) + D` (Linux) / `MO(3) + LT(1,Enter)`-Position (Windows) |
| Screenshot | `alt+shift+s` (Linux) / `win+shift+s` (Windows) | `LShift + MO(3) + S` (Linux) / `MO(3) + RShift`-Position (Windows) |

## Vial einrichten und Layout laden

### Linux (`corne`-Modul)

Das Modul `corne` läuft nur im Profil `desktop` außerhalb von WSL2 (`./install.sh --only corne` oder `dot install --only corne`):

- **Vial:** Auf Arch/CachyOS wird `vial-appimage` über den AUR-Helfer installiert. Auf Fedora und Debian (`x86_64`) lädt der Installer das stabile Upstream-AppImage von `vial-kb/vial-gui` mit SHA-256-Prüfung, entpackt es nach `~/.local/opt/vial` und legt den Wrapper `~/.local/bin/vial` sowie einen Desktop-Starter unter `~/.local/share/applications/vial.desktop` an.
- **udev-Regel:** Schreibt `/etc/udev/rules.d/99-vial.rules` (`ATTRS{serial}=="vial:f64c2b3c"`, `MODE="0660"`, `GROUP="users"`, `TAG+="uaccess"`, `TAG+="udev-acl"`) und lädt die Regeln per `udevadm` neu. Eine abweichende bestehende Regel wird nur mit `--backup` gesichert und ersetzt.
- **Prüfung:** `dot doctor` prüft sowohl `vial` als auch `/etc/udev/rules.d/99-vial.rules`.
- **Layout laden:** Corne anschließen, `vial` ohne `sudo` starten, über `File -> Load saved layout...` die Datei `corne_v4.vil` aus dem Repository laden.

### Windows (`windows/dot.ps1`)

- **Vial:** `windows/dot.ps1 install` (bzw. `bootstrap.ps1`) lädt das aktuelle stabile `Vial-v*-portable.zip` von `vial-kb/vial-gui` (mit SHA-256-Prüfung, sofern GitHub einen Digest liefert) nach `%LOCALAPPDATA%\Vial`, schreibt die Versionsmarkierung `.version` und legt die Startmenü-Verknüpfung `Vial.lnk` an.
- **Aktualisierung & Diagnose:** `windows/dot.ps1 update` aktualisiert Vial bei einer neueren Release-Version; `windows/dot.ps1 doctor` prüft `.version` und `Vial.exe`.
- **Layout laden:** Corne anschließen, **Vial** über das Startmenü starten und `corne_v4.vil` über `File -> Load saved layout...` laden.
