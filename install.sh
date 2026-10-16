#!/usr/bin/env bash
# ADRENALIN subscription page installer for PasarGuard
set -Eeuo pipefail
REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/amirabasimani015-dev/Sub/main}"
PG_DIR="${PG_DIR:-/opt/pasarguard}"
PG_DATA="${PG_DATA:-/var/lib/pasarguard}"
ENVF="$PG_DIR/.env"
TPL_DIR="$PG_DATA/templates/subscription"
TPL_FILE="$TPL_DIR/index.html"
ORIG="$TPL_FILE.orig-adrenalin"
ENV_BAK="$PG_DIR/.env.adrenalin.bak"

say(){ printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
[[ "$(id -u)" -eq 0 ]] || die "با root اجرا کن: sudo bash install.sh"
command -v curl >/dev/null 2>&1 || die "curl نصب نیست"
command -v grep >/dev/null 2>&1 || die "grep نصب نیست"
command -v sed >/dev/null 2>&1 || die "sed نصب نیست"
[[ -f "$ENVF" ]] || die "$ENVF پیدا نشد؛ مسیر پنل را با PG_DIR مشخص کن."
[[ -d "$PG_DATA" ]] || die "$PG_DATA پیدا نشد؛ مسیر دیتا را با PG_DATA مشخص کن."
mkdir -p "$TPL_DIR"
[[ -f "$ENV_BAK" ]] || cp -a "$ENVF" "$ENV_BAK"
if [[ -f "$TPL_FILE" && ! -f "$ORIG" ]] && ! grep -q 'ADRENALIN' "$TPL_FILE"; then cp -a "$TPL_FILE" "$ORIG"; fi
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
say "دانلود قالب از $REPO_RAW/index.html"
curl --retry 3 --retry-delay 2 -fsSL "$REPO_RAW/index.html" -o "$TMP" || die "دانلود index.html ناموفق بود؛ آن را در ریشه مخزن Sub قرار بده."
grep -qi '<!doctype html' "$TMP" || die "فایل دانلودی HTML معتبر نیست؛ قالب فعلی دست‌نخورده ماند."
grep -qi '</html>' "$TMP" || die "فایل HTML ناقص است؛ قالب فعلی دست‌نخورده ماند."
grep -q 'wgDownload' "$TMP" || die "بخش دانلود WireGuard در HTML پیدا نشد؛ قالب فعلی دست‌نخورده ماند."
install -m 0644 "$TMP" "$TPL_FILE"
rm -f "$TMP"; trap - EXIT
setenv(){ local key="$1" value="$2"; sed -i -E "/^[[:space:]#]*${key}[[:space:]]*=/d" "$ENVF"; printf '%s="%s"\n' "$key" "$value" >> "$ENVF"; }
setenv CUSTOM_TEMPLATES_DIRECTORY "$PG_DATA/templates/"
setenv SUBSCRIPTION_PAGE_TEMPLATE "subscription/index.html"
say "تنظیمات قالب ثبت شد"
if command -v pasarguard >/dev/null 2>&1; then
  pasarguard restart -n || pasarguard restart || warn "ریستارت پنل ناموفق بود؛ دستی ریستارت کن."
elif command -v docker >/dev/null 2>&1 && [[ -f "$PG_DIR/docker-compose.yml" ]]; then
  (cd "$PG_DIR" && docker compose up -d --force-recreate) || warn "ریستارت Docker ناموفق بود."
else
  warn "فرمان ریستارت پیدا نشد؛ پس از بررسی مسیرها، پنل را دستی ریستارت کن."
fi
say "نصب قالب انجام شد: $TPL_FILE"
warn "WireGuard: دکمه دانلود فقط وقتی نمایش داده می‌شود که API مسیر /info فیلد wireguard_config یا wg_config یا wireguard یا wg را با متن معتبر [Interface]/[Peer] برگرداند. این اسکریپت کلید یا کانفیگ WireGuard جعل نمی‌کند."
