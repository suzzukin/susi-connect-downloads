# susi connect

Сборки клиента: android, windows и linux. Здесь только файлы, без исходного кода.
Client builds for android, windows and linux. Files only, no source.

<p align="left">
  <a href="https://play.google.com/store/apps/details?id=com.susinetwork.connect"><img alt="Get it on Google Play" src="badges/google-play.svg" width="162"></a>
  &nbsp;
  <a href="https://apps.apple.com/app/id6759531907"><img alt="Download on the App Store" src="badges/app-store.svg" width="144"></a>
</p>

**Прямые загрузки, если магазин недоступен · Direct downloads when a store is out of reach**

<p align="left">
  <a href="https://github.com/suzzukin/susi-connect-downloads/releases/latest/download/susi-connect-android.apk"><img alt="Download the APK" src="https://img.shields.io/badge/apk-android-1C1E20?style=for-the-badge&logo=android&logoColor=F7F8FA&labelColor=0F1113"></a>
  &nbsp;
  <a href="https://github.com/suzzukin/susi-connect-downloads/releases/latest"><img alt="Download the installer" src="https://img.shields.io/badge/setup-windows-1C1E20?style=for-the-badge&logo=windows&logoColor=F7F8FA&labelColor=0F1113"></a>
  &nbsp;
  <a href="https://github.com/suzzukin/susi-connect-downloads/releases/latest"><img alt="Download the package" src="https://img.shields.io/badge/deb%20%C2%B7%20rpm-linux-1C1E20?style=for-the-badge&logo=linux&logoColor=F7F8FA&labelColor=0F1113"></a>
</p>

## Android

Кнопка apk отдаёт файл из последнего релиза: откройте его на телефоне, система спросит разрешение установить файл не из магазина. Подпись та же, что у сборки в google play, — обновления совместимы в обе стороны.

The apk button serves the file from the latest release: open it on the phone and Android will ask for permission to install a file from outside the store. It carries the same signature as the google play build, so updates work in either direction.

## Windows

Кнопка setup отдаёт установщик из последнего релиза. Windows 10 (1809) и новее, x64 и arm64; установщик ставит и приложение, и службу туннеля, поэтому просит права администратора. Он не подписан — SmartScreen предупредит: «Подробнее» → «Выполнить в любом случае». Обновления приложение находит само и показывает в «Настройки → О программе».

The setup button serves the installer from the latest release. Windows 10 (1809) or newer, x64 and arm64; it installs the app and the tunnel service, so it asks for administrator rights. It is not code-signed — SmartScreen will warn: "More info" → "Run anyway". The app finds updates itself and names them under Settings → About.

## Linux

Пакет для своего дистрибутива — из последнего релиза: `.deb` (Ubuntu, Debian, Mint), `.rpm` (Fedora, RHEL, openSUSE), пакет pacman (Arch) или `.tar.gz` с `install.sh` для остальных, x86_64 и ARM64. Пакет ставит приложение и службу туннеля; служба запускается сразу и при каждой загрузке. Нужны Ubuntu 18.04, Debian 9, Fedora 28, RHEL 8, openSUSE Leap 15 или новее. Обновления приложение находит само и показывает в «Настройки → О приложении».

The package for your distribution, from the latest release: `.deb` (Ubuntu, Debian, Mint), `.rpm` (Fedora, RHEL, openSUSE), a pacman package (Arch) or `.tar.gz` with `install.sh` for the rest, x86_64 and ARM64. It installs the app and the tunnel service; the service starts at once and at every boot. Ubuntu 18.04, Debian 9, Fedora 28, RHEL 8, openSUSE Leap 15 or newer. The app finds updates itself and names them under Settings → About.

    sudo apt install ./susi-connect-linux-amd64.deb
    sudo dnf install ./susi-connect-linux-x86_64.rpm
    sudo pacman -U susi-connect-linux-amd64.pkg.tar.zst
    tar -xzf susi-connect-linux-amd64.tar.gz && sudo ./susi-connect-*/install.sh

## Контрольные суммы · Checksums

В каждом релизе лежит `SHA256SUMS.txt`. · Every release ships `SHA256SUMS.txt`.

    sha256sum susi-connect-android.apk
    sha256sum susi-connect-windows-setup.exe
    sha256sum susi-connect-linux-amd64.deb

## Поддержка · Support

[@susi_network_support](https://t.me/susi_network_support)
