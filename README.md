# Claude Desktop RTL Patch — macOS

Adds proper right-to-left (RTL) support for Hebrew and Arabic to **Claude Desktop on macOS**.

Claude Desktop renders all text left-to-right. If you write in Hebrew or Arabic, punctuation
jumps to the wrong side, lists indent backwards, and mixed Hebrew/English lines come out
scrambled. This patch fixes that — while keeping code blocks correctly left-to-right.

This is a macOS port of [shraga100/claude-desktop-rtl-patch](https://github.com/shraga100/claude-desktop-rtl-patch),
which targets the Windows build.

---

## What it does

The patch injects a small JavaScript payload into Claude Desktop's Electron bundle:

- **Direction detection per element** — uses the *first strong character* to decide direction,
  so a Hebrew paragraph that happens to start with a filename or URL still renders RTL.
- **Code stays LTR** — `<pre>`, `<code>` and code blocks are explicitly isolated with
  `unicode-bidi`, so snippets and paths never flip.
- **Live input direction** — the chat box switches direction as you type, per message.
- **Incremental updates** — a `MutationObserver` re-processes only changed subtrees while
  Claude streams a response, instead of re-scanning the whole document.

---

## Why macOS needs more than a CSS patch

The Windows patch only has to edit files. On macOS, three extra problems get in the way:

1. **ASAR integrity checks.** Claude Desktop stores a SHA-256 of the ASAR header in
   `Info.plist`. Changing `app.asar` without updating those hashes makes the app refuse to
   launch — so the script recomputes the hash and rewrites every relevant plist.
2. **`com.apple.macl` protection.** macOS blocks direct writes into app bundles, even as your
   own user. The script works around this by driving **Finder** via AppleScript to perform
   the copy, which carries the necessary permission.
3. **Code signing.** Patching the bundle invalidates Anthropic's signature, and macOS requires
   every binary in a bundle to share one Team ID. The script re-signs everything ad-hoc
   (Team ID `-`), inside out: binaries → frameworks → helper apps → the bundle itself.

---

## Requirements

- macOS
- Claude Desktop at `/Applications/Claude.app`
- Node.js (provides `npx` / `asar`)
- Python 3 (ships with macOS)

---

## Installation

```bash
git clone https://github.com/ChenWolfson/claude-desktop-rtl-patch-mac.git
cd claude-desktop-rtl-patch-mac
./patch.sh
```

Choose option `1`, confirm, and reopen Claude Desktop. A banner confirms the patch is active.

> **Read the script before running it.** It modifies and re-signs an application bundle.
> That is exactly the kind of thing you should not run blindly from the internet — including
> from this repository.

### Optional: a shortcut

```bash
echo "alias rtlfix='cd ~/path/to/claude-desktop-rtl-patch-mac && ./patch.sh'" >> ~/.zshrc
```

---

## After every Claude Desktop update

**Updates overwrite the patch.** Claude Desktop replaces `app.asar` when it updates, which
removes the injection and restores the original hashes. Re-run `./patch.sh` after each update.

---

## Restoring the original

There is no automatic restore — the script cannot keep a backup inside `/Applications`.
To revert, download a fresh copy from [claude.ai/download](https://claude.ai/download) and
drag it over `/Applications/Claude.app`.

---

## Caveats

- **Unofficial.** Not affiliated with or endorsed by Anthropic. Modifying the app bundle is
  unsupported and may violate the terms of service — use at your own risk.
- **Version-dependent.** The injection targets specific bundle paths
  (`.vite/build/mainView.js` and `MainWindowPage-*.js`). A future release could rename these,
  in which case the script reports that it found nothing to inject.
- Verified against Claude Desktop **1.26832.0**.

---

## תמיכה בעברית ב-Claude Desktop (macOS)

Claude Desktop לא תומך בעברית — סימני פיסוק קופצים לצד הלא נכון, רשימות מוזחות הפוך,
ושורות מעורבות עברית/אנגלית יוצאות מבולגנות. הפאטץ' הזה מתקן את זה, ומשאיר בלוקים של קוד
מיושרים לשמאל כמו שצריך.

זהו פורט ל-macOS של [הפאטץ' של shraga100](https://github.com/shraga100/claude-desktop-rtl-patch)
לגרסת Windows.

**התקנה:**

```bash
git clone https://github.com/ChenWolfson/claude-desktop-rtl-patch-mac.git
cd claude-desktop-rtl-patch-mac
./patch.sh
```

בוחרים באפשרות `1`, מאשרים, ופותחים מחדש את Claude Desktop.

**חשוב:** הסקריפט משנה וחותם מחדש את חבילת האפליקציה — כדאי לקרוא אותו לפני שמריצים.
בנוסף, **צריך להריץ אותו מחדש אחרי כל עדכון של Claude Desktop**, כי העדכון דורס את הפאטץ'.

---

## Credits

- Original Windows patch — [shraga100](https://github.com/shraga100/claude-desktop-rtl-patch) (MIT)
- macOS port — [Chen Wolfson](https://github.com/ChenWolfson)

## License

MIT — see [LICENSE](LICENSE).
