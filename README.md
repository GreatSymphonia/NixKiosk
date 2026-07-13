# NixOS Kiosk LAN ETS

Image NixOS minimale pour un kiosk Firefox avec impression sur Brother QL-570.

Cette image démarre Firefox en mode kiosk via Cage/Wayland et configure automatiquement CUPS avec le pilote Brother QL-570.

## Prérequis

Sur la machine de build :

- Nix avec flakes activés
- Les sources Brother téléchargées localement
- Une Brother QL-570 branchée en USB pour les tests

Les sources Brother ne sont pas versionnées dans Git, car elles ne sont pas redistribuables librement.

## Structure attendue des sources Brother

Le flake attend les fichiers Brother dans :

```text
/var/lib/nixos-vendor/brother-ql570/
├── cupswrapper-ql570-src-1.1.1-1
└── ql570lpr-1.0.1-0.i386
```

## Décompresser les sources Brother

Créer le dossier vendor :

```bash
sudo mkdir -p /var/lib/nixos-vendor/brother-ql570
```

Créer un dossier temporaire :

```bash
mkdir -p ~/tmp/brother-ql570
cd ~/tmp/brother-ql570
```

Copier les fichiers téléchargés Brother dans ce dossier, par exemple :

```bash
cp ~/Downloads/cupswrapper-ql570-src-1.1.1-1.tar.gz .
cp ~/Downloads/ql570lpr-1.0.1-0.i386.deb .
```

### Décompresser le cupswrapper

Si le fichier est un `.tar.gz` :

```bash
tar -xf cupswrapper-ql570-src-1.1.1-1.tar.gz
```

Puis copier le dossier extrait :

```bash
sudo cp -a cupswrapper-ql570-src-1.1.1-1 \
  /var/lib/nixos-vendor/brother-ql570/
```

### Décompresser le paquet LPR `.deb`

```bash
mkdir -p ql570lpr-1.0.1-0.i386

dpkg-deb -x ql570lpr-1.0.1-0.i386.deb \
  ql570lpr-1.0.1-0.i386
```

Puis copier le dossier extrait :

```bash
sudo cp -a ql570lpr-1.0.1-0.i386 \
  /var/lib/nixos-vendor/brother-ql570/
```

### Si le paquet LPR est un `.rpm`

Ouvrir un shell avec les outils nécessaires :

```bash
nix shell nixpkgs#rpmextract nixpkgs#cpio
```

Puis extraire :

```bash
mkdir -p ql570lpr-1.0.1-0.i386
cd ql570lpr-1.0.1-0.i386

rpm2cpio ../ql570lpr-1.0.1-0.i386.rpm | cpio -idm

cd ..
```

Puis copier :

```bash
sudo cp -a ql570lpr-1.0.1-0.i386 \
  /var/lib/nixos-vendor/brother-ql570/
```

## Vérifier la structure finale

```bash
find /var/lib/nixos-vendor/brother-ql570 -maxdepth 2 -type d | sort
```

On doit voir au minimum :

```text
/var/lib/nixos-vendor/brother-ql570
/var/lib/nixos-vendor/brother-ql570/cupswrapper-ql570-src-1.1.1-1
/var/lib/nixos-vendor/brother-ql570/ql570lpr-1.0.1-0.i386
```

Vérifier aussi :

```bash
test -f /var/lib/nixos-vendor/brother-ql570/cupswrapper-ql570-src-1.1.1-1/brcupsconfig/brcupsconfig.c
test -f /var/lib/nixos-vendor/brother-ql570/ql570lpr-1.0.1-0.i386/opt/brother/PTouch/ql570/lpd/rastertobrpt1
```

## Mettre à jour le lock du flake

Après avoir placé les sources Brother :

```bash
nix flake update brother-ql570-src
```

Cela enregistre le contenu local dans `flake.lock`.

## Construire l’ISO

```bash
make build
```

Cela génère :

```text
./nixos-kiosk-lanets.iso
```

## Flasher l’ISO

Identifier le périphérique USB :

```bash
lsblk
```

Puis flasher, par exemple :

```bash
make flash DEVICE=/dev/sdX
```

Attention : remplacer `/dev/sdX` par le bon périphérique. Cette commande efface le disque ciblé.

## Démarrage du kiosk

Au boot, le système :

1. démarre NetworkManager ;
2. démarre CUPS ;
3. configure la Brother QL-570 ;
4. crée le lien de compatibilité `/opt/brother` ;
5. démarre Cage ;
6. lance Firefox en mode kiosk.

## Impression

La queue CUPS configurée est :

```text
QL-570
```

Le format utilisé est :

```text
62x29
```

Firefox est configuré pour imprimer silencieusement vers l’imprimante par défaut.

## Tester l’imprimante manuellement

Depuis le système kiosk ou une session SSH :

```bash
lpstat -t
```

Créer une étiquette de test :

```bash
cat > /tmp/ql570-62x29-test.ps <<'EOF'
%!PS-Adobe-3.0
%%BoundingBox: 0 0 176 82
%%Pages: 1
<< /PageSize [176 82] >> setpagedevice

0 setgray
4 setlinewidth
5 5 166 72 rectstroke

/Helvetica-Bold findfont 16 scalefont setfont
12 48 moveto
(TEST QL570) show

12 24 moveto
(62x29) show

10 10 156 8 rectfill

showpage
EOF
```

Imprimer :

```bash
lp -d QL-570 -o PageSize=62x29 /tmp/ql570-62x29-test.ps
```

Voir les logs CUPS :

```bash
journalctl -u cups --since "2 minutes ago" --no-pager \
  | grep -Ei "Job|Error|failed|stall|stalled|unable|sent|completed|bytes|usb"
```

Un job sain ressemble à :

```text
Sent XXXXX bytes...
Job completed.
```

## Nettoyer la file d’impression

```bash
cancel -a QL-570
cupsenable QL-570
cupsaccept QL-570
```

## Notes importantes

Les fichiers Brother ne doivent pas être commités.

Ils doivent rester dans :

```text
/var/lib/nixos-vendor/brother-ql570
```

Le repo référence ce dossier via un input flake local :

```nix
brother-ql570-src = {
  url = "path:/var/lib/nixos-vendor/brother-ql570";
  flake = false;
};
```

Si les sources Brother changent, il faut relancer :

```bash
nix flake update brother-ql570-src
```

puis reconstruire :

```bash
make build
```

## Dépannage rapide

Vérifier que CUPS voit l’imprimante :

```bash
lpinfo -v | grep -i brother
```

Vérifier que le pilote est visible :

```bash
lpinfo -m | grep -i ql
```

Vérifier le lien de compatibilité Brother :

```bash
ls -l /opt/brother
ls -l /opt/brother/PTouch/ql570/inf/brql570func
```

Vérifier la queue :

```bash
lpstat -t
```

Redémarrer CUPS :

```bash
sudo systemctl restart cups
```

Nettoyer les jobs :

```bash
cancel -a QL-570
```
