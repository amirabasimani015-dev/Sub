#!/usr/bin/env bash
# ADRENALIN subscription template installer for PasarGuard
set -Eeuo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/amirabasimani015-dev/adrenalin-sub/main}"
PG_DIR="${PG_DIR:-/opt/pasarguard}"
PG_DATA="${PG_DATA:-/var/lib/pasarguard}"
ENVF="$PG_DIR/.env"
TPL_DIR="$PG_DATA/templates/subscription"
TPL_FILE="$TPL_DIR/index.html"
ORIG="$TPL_FILE.orig-adrenalin"
ENV_BAK="$PG_DIR/.env.adrenalin.bak"
PING_JSON="$TPL_DIR/adr-ping.json"

say(){ printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "دستور $1 نصب نیست"; }

[[ "$(id -u)" -eq 0 ]] || die "با root اجرا کن: sudo bash install.sh"
need curl
need grep
need sed

restart_panel(){
  if command -v pasarguard >/dev/null 2>&1; then
    pasarguard restart -n || pasarguard restart
  elif [[ -f "$PG_DIR/docker-compose.yml" ]] && command -v docker >/dev/null 2>&1; then
    (cd "$PG_DIR" && docker compose up -d --force-recreate)
  else
    warn "فرمان ریستارت خودکار پیدا نشد؛ بعداً اجرا کن: pasarguard restart"
  fi
}
setenv(){
  local key="$1" value="$2"
  sed -i -E "/^[[:space:]#]*${key}[[:space:]]*=/d" "$ENVF"
  printf '%s="%s"\n' "$key" "$value" >> "$ENVF"
}

if [[ "${1:-}" == "uninstall" ]]; then
  [[ -f "$ENVF" ]] || die "$ENVF پیدا نشد."
  if [[ -f "$ENV_BAK" ]]; then
    cp -a "$ENV_BAK" "$ENVF"
    say ".env از بکاپ برگردانده شد"
  else
    warn "بکاپ .env وجود ندارد؛ تنظیمات قالب به‌صورت خودکار تغییر داده نشد."
  fi
  if [[ -f "$ORIG" ]]; then
    mv -f "$ORIG" "$TPL_FILE"
    say "قالب قبلی برگردانده شد"
  else
    rm -f "$TPL_FILE"
    say "قالب ADRENALIN حذف شد"
  fi
  rm -f "$PING_JSON"
  restart_panel
  say "حذف انجام شد"
  exit 0
fi

[[ -f "$ENVF" ]] || die "$ENVF پیدا نشد. مسیر پنل را با PG_DIR مشخص کن."
[[ -d "$PG_DATA" ]] || die "$PG_DATA پیدا نشد. مسیر دیتا را با PG_DATA مشخص کن."

mkdir -p "$TPL_DIR"
[[ -f "$ENV_BAK" ]] || cp -a "$ENVF" "$ENV_BAK"

# Keep the original template once; never overwrite the first backup.
if [[ -f "$TPL_FILE" && ! -f "$ORIG" ]] && ! grep -q 'id="pg-links"' "$TPL_FILE"; then
  cp -a "$TPL_FILE" "$ORIG"
fi

say "دانلود قالب از GitHub..."
TMP="$(mktemp)"
trap 'rm -f "${TMP:-}"' EXIT
curl --retry 3 --retry-delay 2 -fsSL "$REPO_RAW/index.html" -o "$TMP" || die "دانلود index.html ناموفق بود: $REPO_RAW/index.html"

# Validate the downloaded page before touching the live template.
grep -qi '<!doctype html' "$TMP" || die "فایل دانلودی HTML معتبر نیست؛ قالب فعلی دست‌نخورده ماند."
grep -q 'pg-links' "$TMP" || die "فایل HTML ناقص است (pg-links پیدا نشد)؛ قالب فعلی دست‌نخورده ماند."
grep -q '</html>' "$TMP" || die "فایل HTML انتهای معتبر ندارد؛ قالب فعلی دست‌نخورده ماند."

install -m 0644 "$TMP" "$TPL_FILE"
rm -f "$TMP"
trap - EXIT

# The template uses this optional include. Create an empty valid JSON file
# so the page can render even if the optional ping worker is not installed.
[[ -f "$PING_JSON" ]] || printf '{}\n' > "$PING_JSON"
chmod 0644 "$PING_JSON"

setenv CUSTOM_TEMPLATES_DIRECTORY "$PG_DATA/templates/"
setenv SUBSCRIPTION_PAGE_TEMPLATE "subscription/index.html"
say "تنظیمات قالب در .env ثبت شد"

restart_panel

echo
say "نصب قالب انجام شد."
echo "مسیر قالب: $TPL_FILE"
echo "بکاپ تنظیمات: $ENV_BAK"
echo "برای تست:"
echo "  curl -sS -H 'Accept: text/html' 'https://دامنه:پورت/sub/توکن' | head -c 300"
echo
warn "این نسخه قالب را نصب می‌کند؛ سرویس پینگ سمت سرور جداگانه نصب نشده است."
