#!/usr/bin/env bash
# =============================================================================
# Claude Desktop RTL Patch — macOS
# Adds smart Hebrew/Arabic (RTL) support to Claude Desktop on macOS.
#
# Based on the Windows patch by shraga100:
# https://github.com/shraga100/claude-desktop-rtl-patch
#
# Usage:
#   git clone https://github.com/ChenWolfson/claude-desktop-rtl-patch-mac.git
#   cd claude-desktop-rtl-patch-mac && ./patch.sh
#
# This script modifies files inside /Applications/Claude.app. Read it before
# running it.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

log()     { echo -e "  ${CYAN}[*] $1${NC}"; }
success() { echo -e "  ${GREEN}[+] $1${NC}"; }
warn()    { echo -e "  ${YELLOW}[!] $1${NC}"; }
step()    { echo -e "\n${MAGENTA}► $1${NC}"; }
die()     { echo -e "  ${RED}[✗] $1${NC}"; exit 1; }

CLAUDE_APP="/Applications/Claude.app"
RESOURCES="$CLAUDE_APP/Contents/Resources"
ASAR_PATH="$RESOURCES/app.asar"
TMP_DIR="/tmp/claude_rtl_$$"
PATCHED="/private/var/tmp/app.asar.patched"

# ── RTL JavaScript payload ────────────────────────────────────────────────────
RTL_JS='// --- CLAUDE RTL PATCH START ---
;(function() {
    '"'"'use strict'"'"';
    if (typeof document === '"'"'undefined'"'"') return;
    try {
        var WRITING_SEL = '"'"'[data-testid="chat-input"]'"'"';
        // Broad editor detector, used by every skip-guard below.
        // The chat input testid changes between Claude Desktop versions. When it
        // does, a WRITING_SEL-only guard stops matching and we start stamping
        // dir/style onto nodes ProseMirror owns. ProseMirror then redraws, which
        // re-fires our observer, which stamps again -- an infinite loop that
        // freezes the app. It reproduces most reliably by typing "-" then a
        // digit, since that makes ProseMirror restructure the line into a list.
        var EDITOR_SEL = '"'"'[data-testid="chat-input"], [contenteditable="true"], [contenteditable=""], [contenteditable="plaintext-only"], .ProseMirror, [role="textbox"]'"'"';
        // The composer toolbar positions the send button with logical insets
        // (end-*). Flipping an ancestor to dir="rtl" resolves that offset to the
        // opposite physical edge, clipping the button and breaking Enter-to-send.
        var COMPOSER_SEL = '"'"'form, [data-testid="chat-input-container"], [class*="composer"], [class*="Composer"]'"'"';
        function isRTL(c) { var code = c.charCodeAt(0); return (code >= 0x0590 && code <= 0x05FF) || (code >= 0x0600 && code <= 0x06FF) || (code >= 0x0750 && code <= 0x077F) || (code >= 0x08A0 && code <= 0x08FF); }
        function hasRTL(text) { if (!text) return false; for (var i = 0; i < text.length; i++) { if (isRTL(text[i])) return true; } return false; }
        function firstStrong(text) { if (!text) return null; for (var i = 0; i < text.length; i++) { if (isRTL(text[i])) return '"'"'rtl'"'"'; if (/[a-zA-Z]/.test(text[i])) return '"'"'ltr'"'"'; } return null; }
        function textWithoutCode(el) { var out = '"'"''"'"'; var nodes = el.childNodes; for (var i = 0; i < nodes.length; i++) { var n = nodes[i]; if (n.nodeType === 3) { out += n.textContent; } else if (n.nodeType === 1 && n.tagName !== '"'"'CODE'"'"' && n.tagName !== '"'"'PRE'"'"') { out += textWithoutCode(n); } } return out; }
        function stripLeadingLTR(text) { return text.replace(/^[\s]*(?:[\w.\-]+\.[\w]{1,5})\s*/g, '"'"''"'"').replace(/https?:\/\/\S+/g, '"'"''"'"').replace(/[\w.\-]+[\/\\][\w.\-\/\\]+/g, '"'"''"'"').replace(/`[^`]+`/g, '"'"''"'"'); }
        function detectElDir(el) { var full = el.textContent || '"'"''"'"'; if (!hasRTL(full)) return null; var noCode = textWithoutCode(el); var d = firstStrong(noCode); if (d === '"'"'rtl'"'"') return '"'"'rtl'"'"'; var stripped = stripLeadingLTR(noCode); d = firstStrong(stripped); if (d === '"'"'rtl'"'"') return '"'"'rtl'"'"'; return '"'"'rtl'"'"'; }
        function detectTextDir(text) { if (!text || !text.trim()) return null; var d = firstStrong(text); if (d === '"'"'rtl'"'"') return '"'"'rtl'"'"'; if (!hasRTL(text)) return '"'"'ltr'"'"'; var stripped = stripLeadingLTR(text); d = firstStrong(stripped); if (d === '"'"'rtl'"'"') return '"'"'rtl'"'"'; return '"'"'rtl'"'"'; }
        function qsa(root, sel) { var base = root.querySelectorAll ? root : document; var els = Array.from(base.querySelectorAll(sel)); if (root.matches && root.matches(sel)) els.unshift(root); return els; }
        function forceCodeLTR(root) { qsa(root, '"'"'pre, .code-block__code'"'"').forEach(function(b) { if (b.closest(EDITOR_SEL)) return; b.dir = '"'"'ltr'"'"'; b.style.textAlign = '"'"'left'"'"'; b.style.unicodeBidi = '"'"'embed'"'"'; }); qsa(root, '"'"'code'"'"').forEach(function(c) { if (c.closest(EDITOR_SEL)) return; if (!c.closest('"'"'pre'"'"') && !c.closest('"'"'.code-block__code'"'"')) c.dir = '"'"'ltr'"'"'; }); }
        function processText(root) {
            qsa(root, '"'"'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, summary, label, dt, dd'"'"').forEach(function(el) {
                if (el.closest(EDITOR_SEL) || el.closest('"'"'pre'"'"') || el.closest('"'"'.code-block__code'"'"')) return;
                var dir = detectElDir(el);
                if (dir) { el.dir = dir; el.style.direction = dir; if (el.tagName === '"'"'LI'"'"') { el.style.listStylePosition = (dir === '"'"'rtl'"'"') ? '"'"'inside'"'"' : '"'"''"'"'; var pl = el.closest('"'"'ul, ol'"'"'); if (pl && dir === '"'"'rtl'"'"' && !pl.hasAttribute('"'"'dir'"'"')) { pl.dir = '"'"'rtl'"'"'; pl.style.direction = '"'"'rtl'"'"'; var pLeft = getComputedStyle(pl).paddingLeft; if (parseFloat(pLeft) > 0) { pl.style.paddingRight = pLeft; pl.style.paddingLeft = '"'"'0'"'"'; } } } }
                else { if (el.hasAttribute('"'"'dir'"'"')) el.removeAttribute('"'"'dir'"'"'); el.style.direction = '"'"''"'"'; if (el.tagName === '"'"'LI'"'"') el.style.listStylePosition = '"'"''"'"'; }
            });
            qsa(root, '"'"'ul, ol'"'"').forEach(function(el) {
                if (el.closest(EDITOR_SEL) || el.closest('"'"'pre'"'"')) return;
                var dir = detectElDir(el);
                if (dir === '"'"'rtl'"'"') { el.dir = '"'"'rtl'"'"'; el.style.direction = '"'"'rtl'"'"'; var pl = getComputedStyle(el).paddingLeft; if (parseFloat(pl) > 0) { el.style.paddingRight = pl; el.style.paddingLeft = '"'"'0'"'"'; } }
                else { if (el.hasAttribute('"'"'dir'"'"')) el.removeAttribute('"'"'dir'"'"'); el.style.direction = '"'"''"'"'; el.style.paddingRight = '"'"''"'"'; el.style.paddingLeft = '"'"''"'"'; }
            });
        }
        function processContainers(root) {
            qsa(root, '"'"'div, span, button, a, label'"'"').forEach(function(el) {
                if (el.closest('"'"'pre'"'"') || el.closest('"'"'code'"'"') || el.closest(EDITOR_SEL) || el.closest(COMPOSER_SEL)) return;
                if (el.querySelector('"'"'p, div, ul, ol, h1, h2, h3, h4, h5, h6, pre, table'"'"')) return;
                if (/^(P|LI|H[1-6]|BLOCKQUOTE|TD|TH|UL|OL)$/.test(el.tagName)) return;
                var text = (el.textContent || '"'"''"'"').trim();
                if (text.length < 2) return;
                if (hasRTL(text)) { el.dir = detectTextDir(text) || '"'"'rtl'"'"'; el.style.textAlign = '"'"'start'"'"'; }
                else if (el.hasAttribute('"'"'dir'"'"')) { el.removeAttribute('"'"'dir'"'"'); el.style.textAlign = '"'"''"'"'; }
            });
        }
        function processInput() {
            document.querySelectorAll(WRITING_SEL).forEach(function(input) {
                var text = input.textContent || input.innerText || '"'"''"'"';
                var dir = detectTextDir(text);
                if (dir === '"'"'rtl'"'"') { input.style.direction = '"'"'rtl'"'"'; input.style.textAlign = '"'"'right'"'"'; input.style.paddingRight = '"'"'25px'"'"'; }
                else { input.style.direction = '"'"'ltr'"'"'; input.style.textAlign = '"'"'left'"'"'; input.style.paddingRight = '"'"''"'"'; }
            });
        }
        function processAll() { processText(document); processContainers(document.body); processInput(); forceCodeLTR(document.body); }
        function injectStyles() {
            if (document.getElementById('"'"'claude-rtl-styles'"'"')) return;
            var s = document.createElement('"'"'style'"'"'); s.id = '"'"'claude-rtl-styles'"'"';
            s.textContent = '"'"'p:not([dir]),li:not([dir]),h1:not([dir]),h2:not([dir]),h3:not([dir]),h4:not([dir]),h5:not([dir]),h6:not([dir]),blockquote:not([dir]),td:not([dir]),th:not([dir]),summary:not([dir]),label:not([dir]),dt:not([dir]),dd:not([dir]){unicode-bidi:plaintext!important;text-align:start!important}pre,.code-block__code{unicode-bidi:embed!important;direction:ltr!important;text-align:left!important}code{unicode-bidi:isolate!important;direction:ltr!important}[dir]{text-align:start!important}[dir="rtl"]{direction:rtl!important}[dir="ltr"]{direction:ltr!important}'"'"';
            document.head.appendChild(s);
        }
        function init() {
            injectStyles(); processAll();
            document.addEventListener('"'"'input'"'"', function(e) {
                var t = e.target;
                if (!t || !(t.tagName === '"'"'TEXTAREA'"'"' || t.tagName === '"'"'INPUT'"'"' || t.isContentEditable)) return;
                var text = t.textContent || t.innerText || t.value || '"'"''"'"';
                var dir = detectTextDir(text);
                if (dir === '"'"'rtl'"'"') { t.style.direction = '"'"'rtl'"'"'; t.style.textAlign = '"'"'right'"'"'; t.style.paddingRight = '"'"'25px'"'"'; }
                else { t.style.direction = '"'"'ltr'"'"'; t.style.textAlign = '"'"'left'"'"'; t.style.paddingRight = '"'"''"'"'; }
            }, true);
            var pendingMuts = [];
            var obs = new MutationObserver(function(muts) {
                var dominated = false;
                for (var i = 0; i < muts.length; i++) { if (muts[i].addedNodes.length > 0 || muts[i].type === '"'"'characterData'"'"') { dominated = true; break; } }
                if (!dominated) return;
                for (var j = 0; j < muts.length; j++) pendingMuts.push(muts[j]);
                if (window._rtlT) return;
                window._rtlT = setTimeout(function() {
                    window._rtlT = null; var toProcess = pendingMuts; pendingMuts = [];
                    var roots = new Set();
                    toProcess.forEach(function(m) { m.addedNodes.forEach(function(n) { if (n.nodeType === 1) roots.add(n); }); if (m.type === '"'"'characterData'"'"' && m.target.parentElement) roots.add(m.target.parentElement); });
                    var expanded = new Set(roots);
                    roots.forEach(function(r) { if (!r.closest) return; var txt = r.closest('"'"'p, li, h1, h2, h3, h4, h5, h6, blockquote, td, th, summary, label, dt, dd'"'"'); if (txt) expanded.add(txt); var list = r.closest('"'"'ul, ol'"'"'); if (list) expanded.add(list); });
                    roots = expanded;
                    if (roots.size > 0 && roots.size <= 30) { roots.forEach(function(r) { processText(r); processContainers(r); forceCodeLTR(r); }); processInput(); } else { processAll(); }
                }, 50);
            });
            obs.observe(document.body, { childList: true, subtree: true, characterData: true });
        }
        if (document.readyState === '"'"'loading'"'"') { document.addEventListener('"'"'DOMContentLoaded'"'"', init); } else { init(); }
    } catch(e) { console.error('"'"'[Claude RTL]'"'"', e); }
})();
// --- CLAUDE RTL PATCH END ---

// --- CLAUDE PATCH WELCOME BANNER START ---
;(function() {
    '"'"'use strict'"'"';
    try {
        if (typeof document === '"'"'undefined'"'"' || typeof localStorage === '"'"'undefined'"'"') return;
        var FLAG_KEY = '"'"'claude-rtl-patch-welcomed'"'"';
        var versionMatch = (navigator.userAgent || '"'"''"'"').match(/Claude\/([\d.]+)/);
        var VERSION = versionMatch ? versionMatch[1] : '"'"'0'"'"';
        if (localStorage.getItem(FLAG_KEY) === VERSION) return;
        function show() {
            if (!document.body || document.getElementById('"'"'claude-rtl-welcome-banner'"'"')) return;
            var bar = document.createElement('"'"'div'"'"');
            bar.id = '"'"'claude-rtl-welcome-banner'"'"';
            bar.dir = '"'"'rtl'"'"';
            bar.style.cssText = '"'"'position:fixed;top:12px;left:50%;transform:translateX(-50%);z-index:2147483647;background:#1f1f1f;color:#fff;border:1px solid #3a3a3a;border-radius:10px;padding:10px 14px;font:14px/1.4 system-ui,sans-serif;box-shadow:0 6px 20px rgba(0,0,0,.4);display:flex;gap:12px;align-items:center;max-width:560px'"'"';
            bar.innerHTML = '"'"'<span style="font-size:18px">\u2713</span><span style="flex:1">\u05d4\u05e4\u05d0\u05d8\u05e5'"'"' + '"'"' \u05d4\u05d5\u05d7\u05dc \u05d1\u05d4\u05e6\u05dc\u05d7\u05d4 \u2014 \u05ea\u05de\u05d9\u05db\u05ea RTL \u05e4\u05e2\u05d9\u05dc\u05d4 \u05e2\u05dc macOS.</span><button id="claude-rtl-banner-close" style="background:transparent;color:#aaa;border:0;font-size:20px;cursor:pointer;padding:0 4px" aria-label="close">\u00d7</button>'"'"';
            document.body.appendChild(bar);
            document.getElementById('"'"'claude-rtl-banner-close'"'"').onclick = function() { localStorage.setItem(FLAG_KEY, VERSION); bar.remove(); };
        }
        if (document.readyState === '"'"'loading'"'"') { document.addEventListener('"'"'DOMContentLoaded'"'"', show); } else { show(); }
    } catch(e) { console.error('"'"'[Claude Welcome Banner]'"'"', e); }
})();
// --- CLAUDE PATCH WELCOME BANNER END ---
'

# ── Python helpers ────────────────────────────────────────────────────────────
PY_COMPUTE_HASH='
import sys, struct, hashlib
with open(sys.argv[1], "rb") as f:
    f.seek(12)
    size = struct.unpack("<I", f.read(4))[0]
    data = f.read(size)
print(hashlib.sha256(data.decode("utf-8").encode("utf-8")).hexdigest())
'

# ── Functions ─────────────────────────────────────────────────────────────────

check_prerequisites() {
    step "Checking prerequisites..."
    [[ -d "$CLAUDE_APP" ]] || die "Claude Desktop not found at $CLAUDE_APP"
    [[ -f "$ASAR_PATH" ]]  || die "app.asar not found at $ASAR_PATH"
    command -v node    >/dev/null 2>&1 || die "Node.js required — install from https://nodejs.org"
    command -v npx     >/dev/null 2>&1 || die "npx not found — install Node.js"
    command -v python3 >/dev/null 2>&1 || die "python3 required"
    npx asar --version >/dev/null 2>&1 || die "npx asar not available — run: npm install -g asar"
    success "All prerequisites satisfied."
}

# PIDs of the main app process, and of anything else running from the bundle.
# `pgrep -x Claude` only ever matched Contents/MacOS/Claude, so every helper --
# including the ones that host Claude Code -- went undetected and the script
# announced "Claude stopped" while binaries from the bundle were still live.
main_pids()   { pgrep -f "^$CLAUDE_APP/Contents/MacOS/Claude$" 2>/dev/null || true; }
helper_pids() { pgrep -f "^$CLAUDE_APP/" 2>/dev/null | grep -vxF "$(main_pids)" 2>/dev/null || true; }

quit_claude() {
    step "Quitting Claude Desktop..."
    osascript -e 'tell application "Claude" to quit' 2>/dev/null || true
    pkill -x "Claude" 2>/dev/null || true

    local waited=0
    while [[ -n "$(main_pids)" && $waited -lt 20 ]]; do   # 20 * 0.5s = 10s cap
        sleep 0.5
        waited=$((waited + 1))
    done

    # Replacing app.asar under a live main process corrupts the install, so this
    # is fatal rather than a warning.
    [[ -n "$(main_pids)" ]] && die "Claude Desktop is still running after 10s. Quit it and try again."

    # Helpers are a different matter: they do not map app.asar, so patching over
    # them is safe. Worth naming, because one of them may be hosting the very
    # terminal this is running in.
    local helpers; helpers=$(helper_pids)
    if [[ -n "$helpers" ]]; then
        warn "Still running from the bundle (harmless, but they keep the old code):"
        while read -r p; do
            [[ -n "$p" ]] && warn "    $(basename "$(ps -o comm= -p "$p" 2>/dev/null)") (pid $p)"
        done <<< "$helpers"
    fi
    success "Claude stopped."
}

# Uses Finder to copy a file — bypasses macOS TCC/com.apple.macl restrictions
finder_copy() {
    local src="$1" dst_dir="$2" final_name="$3"
    osascript << APPLE 2>/dev/null
tell application "Finder"
    try
        set ex to (POSIX file "${dst_dir}${final_name}") as alias
        delete ex
    end try
    set newf to duplicate (POSIX file "${src}") to ((POSIX file "${dst_dir}") as alias)
    set name of newf to "${final_name}"
end tell
APPLE
}

build_patched_asar() {
    step "Phase 1: Extracting ASAR..."
    rm -rf "$TMP_DIR"
    npx asar extract "$ASAR_PATH" "$TMP_DIR"

    step "Phase 2: Injecting RTL JavaScript..."
    local injected=0

    # Inject into preload (mainView.js) and main renderer bundle
    local targets=(
        "$TMP_DIR/.vite/build/mainView.js"
    )
    # Also find the main window renderer bundle
    local renderer
    renderer=$(find "$TMP_DIR/.vite/renderer/main_window" -name "MainWindowPage-*.js" 2>/dev/null | head -1)
    [[ -n "$renderer" ]] && targets+=("$renderer")

    for js_file in "${targets[@]}"; do
        [[ -f "$js_file" ]] || continue
        grep -q "CLAUDE RTL PATCH START" "$js_file" 2>/dev/null && { log "Already patched: $(basename "$js_file")"; continue; }
        local tmp; tmp=$(mktemp)
        printf '%s\n' "$RTL_JS" > "$tmp"
        cat "$js_file" >> "$tmp"
        mv "$tmp" "$js_file"
        log "Injected: $(basename "$js_file")"
        ((injected++))
    done

    [[ $injected -gt 0 ]] && success "Injected into $injected file(s)." || warn "No new files to inject."

    step "Phase 3: Repacking ASAR..."
    npx asar pack "$TMP_DIR" "$PATCHED" --unpack "{*.node,spawn-helper}"
    rm -rf "$TMP_DIR"
    success "Packed to $PATCHED ($(du -sh "$PATCHED" | cut -f1))"
}

install_patch() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Claude Desktop RTL Patch — macOS               ║${NC}"
    echo -e "${CYAN}║   Based on Windows patch by shraga100             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    check_prerequisites
    quit_claude
    build_patched_asar

    step "Phase 4: Computing hashes..."
    local old_hash new_hash
    old_hash=$(python3 - "$ASAR_PATH"   <<< "$PY_COMPUTE_HASH")
    new_hash=$(python3 - "$PATCHED"     <<< "$PY_COMPUTE_HASH")
    log "Old hash: $old_hash"
    log "New hash: $new_hash"

    step "Phase 5: Installing patched ASAR via Finder..."
    # macOS protects app bundles with com.apple.macl — Finder has permission to replace files
    finder_copy "$PATCHED" "$RESOURCES/" "app.asar"
    [[ -f "$ASAR_PATH" ]] || die "Failed to install app.asar — see README for manual steps"
    success "app.asar installed."

    step "Phase 6: Updating integrity hashes in Info.plist files..."
    local plists=(
        "$CLAUDE_APP/Contents/Info.plist"
        "$CLAUDE_APP/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist"
        "$CLAUDE_APP/Contents/Frameworks/Claude Helper.app/Contents/Info.plist"
        "$CLAUDE_APP/Contents/Frameworks/Claude Helper (GPU).app/Contents/Info.plist"
        "$CLAUDE_APP/Contents/Frameworks/Claude Helper (Plugin).app/Contents/Info.plist"
        "$CLAUDE_APP/Contents/Frameworks/Claude Helper (Renderer).app/Contents/Info.plist"
    )

    local tmp_plist_dir; tmp_plist_dir=$(mktemp -d)
    local updated=0
    for plist in "${plists[@]}"; do
        [[ -f "$plist" ]] || continue
        grep -q "$old_hash" "$plist" 2>/dev/null || continue
        local fname; fname=$(basename "$(dirname "$plist")")_Info.plist
        sed "s/$old_hash/$new_hash/g" "$plist" > "$tmp_plist_dir/$fname"
        finder_copy "$tmp_plist_dir/$fname" "$(dirname "$plist")/" "Info.plist"
        log "Updated: $(dirname "$plist" | sed "s|$CLAUDE_APP/||")"
        ((updated++))
    done
    rm -rf "$tmp_plist_dir"
    [[ $updated -gt 0 ]] && success "Updated $updated plist file(s)." || warn "No plist files needed updating."

    step "Phase 7: Verifying the patch..."
    verify_patch
}

# The patch only replaces app.asar -- an unsigned resource -- and rewrites the
# ASAR integrity hash in Info.plist. No Mach-O binary is modified, so every
# executable keeps its original Anthropic signature and the app launches
# normally.
#
# Earlier versions re-signed the whole bundle ad-hoc here, on the assumption
# that patching invalidated the signature. It does not, and the re-signing never
# actually worked: every codesign call failed with "Operation not permitted",
# because a shell has no App Management right over another app's bundle -- the
# same restriction that forces finder_copy above. The failures were hidden by
# 2>/dev/null, so the step reported success for months while doing nothing.
#
# Not re-signing is also the better outcome. The bundle keeps Anthropic's real
# Developer ID signature and its hardened runtime, instead of being downgraded
# to an ad-hoc signature with its entitlements stripped.
#
# One visible consequence: `codesign --verify` reports a modified Info.plist,
# because the resource seal no longer matches. macOS does not consult that seal
# when launching an already-installed, unquarantined app.
verify_patch() {
    local ok=1 actual team

    if grep -aq "CLAUDE RTL PATCH START" "$ASAR_PATH"; then
        success "RTL payload is present in app.asar."
    else
        warn "RTL payload NOT found in app.asar."
        ok=0
    fi

    actual=$(python3 - "$ASAR_PATH" <<< "$PY_COMPUTE_HASH")
    if grep -q "$actual" "$CLAUDE_APP/Contents/Info.plist" 2>/dev/null; then
        success "ASAR integrity hash matches Info.plist."
    else
        warn "ASAR integrity hash does not match Info.plist — Claude will refuse to start."
        ok=0
    fi

    team=$(codesign -dv "$CLAUDE_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')
    if [[ -n "$team" && "$team" != "not set" ]]; then
        success "Code signature untouched (Team $team)."
    else
        warn "This bundle has no Team ID — something has re-signed it ad-hoc."
    fi

    [[ $ok -eq 1 ]] || die "Patch did not apply cleanly. Reinstall Claude Desktop from https://claude.ai/download and try again."

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   RTL patch installed successfully!               ║${NC}"
    echo -e "${GREEN}║   Open Claude Desktop — Hebrew/Arabic now works  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}  ⚠️  Run this script again after each Claude Desktop update.${NC}"
    echo ""
    echo -e "${CYAN}  Note: 'codesign --verify' will report a modified Info.plist.${NC}"
    echo -e "${CYAN}  That is expected — see the comment above verify_patch().${NC}"
    echo ""
}

restore_patch() {
    echo ""
    echo -e "${CYAN}► Restoring original Claude Desktop...${NC}"
    quit_claude

    # Download original from Claude — we can't keep a backup since we can't write to /Applications
    echo -e "${YELLOW}  There is no automatic restore. To restore:${NC}"
    echo -e "${YELLOW}  1. Download Claude Desktop from https://claude.ai/download${NC}"
    echo -e "${YELLOW}  2. Drag the new .app over /Applications/Claude.app${NC}"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Claude Desktop RTL Patch — macOS               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo "  1) Install / Re-apply RTL patch"
echo "  2) How to restore original"
echo "  3) Exit"
echo ""
read -rp "  Select option [1-3]: " CHOICE

case "$CHOICE" in
    1)
        read -rp "  This modifies Claude Desktop files. Continue? [y/N]: " C
        [[ "$C" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
        install_patch
        ;;
    2) restore_patch ;;
    3) echo "Bye."; exit 0 ;;
    *) die "Invalid option." ;;
esac
