# biyi_app

[![GitHub (pre-)release](https://img.shields.io/github/release/biyidev/biyi_app/all.svg?style=flat-square)](https://github.com/biyidev/biyi_app/releases) [![GitHub (pre-)release](https://img.shields.io/badge/distribute%20with-flutter__distributor-green?style=flat-square)](https://github.com/leanflutter/flutter_distributor)

**Biyi** is a convenient translation and dictionary app written in `Flutter`. [View document](https://biyidev.com/docs/)

> "Biyi" (比译) is the Chinese word for "Comparison + translation".

---

English | [简体中文](./README-ZH.md)

---

![](https://biyidev.com/images/screenshots/biyi_app_extract_text_from_screen_selection.gif)

## Platform Support

| Linux | macOS | Windows |
| :---: | :---: | :-----: |
|   ✔️   |   ✔️   |    ✔️    |

## Installation

Downloads are available on the [Releases](https://github.com/biyidev/biyi_app/releases/latest) page. Also check out the [website](https://biyidev.com/release-notes) for other installation methods.

**To install with Homebrew, run:**

```bash
brew tap biyidev/biyi
brew install biyi
```

## Development

We welcome you to join the development of `Biyi`.

> Please make sure to read the [Contributing Guide](https://github.com/biyidev/biyi_app/blob/main/.github/CONTRIBUTING.md) before making a pull request.

### ⚠️ Linux requirements

- `appindicator3-0.1`
- [`keybinder-3.0`](https://github.com/kupferlauncher/keybinder)

Run the following command

```
sudo apt-get install appindicator3-0.1 libappindicator3-dev
sudo apt-get install keybinder-3.0
```

### Before You Start

1. Create working directory

```
$ mkdir ~/biyidev
$ cd ~/biyidev
```

2. Clone dependency repos via git:

```
$ git clone https://github.com/biyidev/uni_ocr.git
$ git clone https://github.com/biyidev/uni_translate.git
```

3. Clone this repo via git:

```
$ git clone https://github.com/biyidev/biyi_app.git
```

4. Change to `biyi_app` directory

```
$ cd ~/biyidev/biyi_app
```

5. Install dependencies

```
$ flutter pub get
```

### Run app

```
$ flutter run -d linux / macos / windows
```

## Discussion

> Welcome to join the discussion group to share your suggestions and ideas with me.

- WeChat Group Please add my personal WeChat `lijy91` and note `Biyi`
- [QQ Group](https://jq.qq.com/?_wv=1027&k=vYQ5jW7y)
- [Telegram Group](https://t.me/joinchat/nFrk4KsXFc84ZGNl)

## Related Links

- https://github.com/biyidev/biyi_app
- https://github.com/biyidev/uni_ocr
- https://github.com/biyidev/uni_translate
- https://github.com/leanflutter/hotkey_manager
- https://github.com/leanflutter/screen_text_extractor
- https://github.com/leanflutter/tray_manager
- https://github.com/leanflutter/window_manager

## License

[AGPL](./LICENSE)
