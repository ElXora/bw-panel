#!/bin/bash
# ============================================================
#
#   ██╗  ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
#   ██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
#   █████╔╝ ██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝
#   ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝
#   ██║  ██╗██║  ██║╚██████╔╝██╔╝ ██╗   ██║
#   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝
#
#   Kroxy Panel — One-Command Installer
#   Black & White Theme | Heliactyl Base
# ============================================================
# NOTE: intentionally NO "set -e" — we handle every error
# manually so the script never silently exits mid-install.

RESET='\033[0m'
BOLD='\033[1m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'

step()  { echo -e "\n${WHITE}${BOLD}[•] $1${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail()  { echo -e "\n${RED}${BOLD}[✗] $1${RESET}\n"; exit 1; }
dim()   { echo -e "  ${DIM}$1${RESET}"; }
ask()   { echo -e "\n${WHITE}${BOLD}$1${RESET}"; }

INSTALL_DIR="/opt/kroxy"
SERVICE_NAME="kroxy"
ALREADY_INSTALLED=false

# ── Banner ─────────────────────────────────────────────────
clear
echo -e "${WHITE}${BOLD}"
cat << 'BANNER'

  ██╗  ██╗██████╗  ██████╗ ██╗  ██╗██╗   ██╗
  ██║ ██╔╝██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
  █████╔╝ ██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝
  ██╔═██╗ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝
  ██║  ██╗██║  ██║╚██████╔╝██╔╝ ██╗   ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

BANNER
echo -e "${RESET}${GRAY}  Kroxy Panel Installer — Black & White Edition${RESET}"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
sleep 0.4

# ── Root check ─────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  fail "Run as root: sudo bash install.sh"
fi

# ── Already installed check ────────────────────────────────
if [ -f "$INSTALL_DIR/app.js" ]; then
  ALREADY_INSTALLED=true
  warn "Kroxy is already installed at $INSTALL_DIR"
  dim "Dependency install will be skipped."
fi

# ── User input ─────────────────────────────────────────────
ask "→ Pterodactyl panel URL (e.g. https://panel.yourdomain.com):"
read -rp "  URL: " PANEL_URL
if [ -z "$PANEL_URL" ]; then fail "Panel URL cannot be empty."; fi

ask "→ Your admin email:"
read -rp "  Email: " ADMIN_EMAIL
if [ -z "$ADMIN_EMAIL" ]; then fail "Admin email cannot be empty."; fi

ask "→ Port for Kroxy (press Enter for default 3001):"
read -rp "  Port: " APP_PORT
APP_PORT="${APP_PORT:-3001}"

ask "→ Discord OAuth Client ID:"
read -rp "  Client ID: " DISCORD_CLIENT_ID
if [ -z "$DISCORD_CLIENT_ID" ]; then fail "Discord Client ID cannot be empty."; fi

ask "→ Discord OAuth Client Secret:"
read -rp "  Client Secret: " DISCORD_CLIENT_SECRET
if [ -z "$DISCORD_CLIENT_SECRET" ]; then fail "Discord Client Secret cannot be empty."; fi

ask "→ Discord Bot Token (optional — press Enter to skip):"
read -rp "  Bot Token: " DISCORD_BOT_TOKEN
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-placeholder}"

ask "→ Session secret (press Enter to auto-generate):"
read -rp "  Secret: " SESSION_SECRET
if [ -z "$SESSION_SECRET" ]; then
  SESSION_SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 48)
  ok "Auto-generated session secret."
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo -e "  ${WHITE}${BOLD}Summary${RESET}"
dim "  Panel URL   : $PANEL_URL"
dim "  Admin Email : $ADMIN_EMAIL"
dim "  Port        : $APP_PORT"
dim "  Install Dir : $INSTALL_DIR"
dim "  API Key     : set manually in settings.json after install"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo ""
ask "→ Proceed? (y/N):"
read -rp "  " CONFIRM
CONFIRM_LOWER=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
if [ "$CONFIRM_LOWER" != "y" ] && [ "$CONFIRM_LOWER" != "yes" ]; then
  echo -e "\n${GRAY}  Cancelled.${RESET}\n"
  exit 0
fi

# ── Dependencies ───────────────────────────────────────────
if [ "$ALREADY_INSTALLED" = false ]; then

  step "Updating apt packages..."
  apt-get update -qq || warn "apt-get update had warnings — continuing."
  apt-get install -y curl git unzip sqlite3 > /dev/null 2>&1 || warn "Some packages may have failed — continuing."
  ok "System packages done."

  step "Installing Node.js 20..."
  NODE_OK=false
  if command -v node > /dev/null 2>&1; then
    NODE_VER=$(node -v 2>/dev/null | cut -d. -f1 | tr -d 'v')
    if [ "$NODE_VER" -ge 18 ] 2>/dev/null; then
      ok "Node.js $(node -v) already present — skipping."
      NODE_OK=true
    fi
  fi
  if [ "$NODE_OK" = false ]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1 || warn "nodesource setup had warnings."
    apt-get install -y nodejs > /dev/null 2>&1 || fail "Node.js install failed."
    ok "Node.js $(node -v) installed."
  fi

  step "Installing PM2..."
  if command -v pm2 > /dev/null 2>&1; then
    ok "PM2 already present — skipping."
  else
    npm install -g pm2 > /dev/null 2>&1 || fail "PM2 install failed."
    ok "PM2 installed."
  fi

else
  step "Skipping dependency install (already installed)."
  NODE_VER=$(node -v 2>/dev/null || echo "not found")
  PM2_VER=$(pm2 -v 2>/dev/null || echo "not found")
  ok "Node.js $NODE_VER"
  ok "PM2 $PM2_VER"
fi

# ── Copy files ─────────────────────────────────────────────
step "Setting up Kroxy files..."

# Cleanly stop PM2 process without touching the shell session
pm2 stop "$SERVICE_NAME" > /dev/null 2>&1 || true

mkdir -p "$INSTALL_DIR"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$SCRIPT_DIR/app.js" ]; then
  dim "Copying panel files..."
  cp -r "$SCRIPT_DIR/." "$INSTALL_DIR/" 2>/dev/null || fail "Failed to copy files to $INSTALL_DIR"
  ok "Files copied to $INSTALL_DIR"
else
  fail "app.js not found. Place install.sh in the same folder as the Kroxy panel files and re-run."
fi

# ── Write settings.json ────────────────────────────────────
step "Writing settings.json..."

SETTINGS_FILE="$INSTALL_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ] && [ "$ALREADY_INSTALLED" = true ]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak" 2>/dev/null || true
  dim "Backed up old settings.json → settings.json.bak"
fi

cat > "$SETTINGS_FILE" << SETTINGS
{
  "name": "Kroxy",
  "logo": "https://avatars.githubusercontent.com/u/188295803?s=400&v=4",
  "pterodactyl": {
    "domain": "${PANEL_URL}",
    "key": "ptla_REPLACEME"
  },
  "announcements": {
    "enabled": false,
    "message": ""
  },
  "timezone": "UTC",
  "version": "1.0.0",
  "testing": false,
  "website": {
    "port": ${APP_PORT},
    "secret": "${SESSION_SECRET}"
  },
  "oauth2": {
    "id": "${DISCORD_CLIENT_ID}",
    "secret": "${DISCORD_CLIENT_SECRET}",
    "link": "${PANEL_URL}",
    "callbackpath": "/callback",
    "prompt": false
  },
  "linkvertise": {
    "userid": "50000",
    "dailyLimit": 1,
    "coins": 10
  },
  "database": "sqlite://database.sqlite",
  "api": {
    "email": { "enabled": false, "resend": "" },
    "client": {
      "accountSwitcher": false,
      "api": { "enabled": true, "code": "${SESSION_SECRET}" },
      "j4r": { "enabled": false, "ads": [] },
      "bot": {
        "token": "${DISCORD_BOT_TOKEN}",
        "joinguild": { "enabled": false, "guildid": ["000000000000000000"] },
        "giverole": { "enabled": false, "guildid": "000000000000000000", "roleid": "000000000000000000" }
      },
      "passwordgenerator": { "signup": true, "length": 16 },
      "allow": {
        "newusers": true,
        "regen": false,
        "server": { "create": true, "modify": true, "delete": true }
      },
      "coins": { "enabled": true, "name": "Coins" },
      "packages": {
        "default": "free",
        "list": {
          "free": { "ram": 2048, "disk": 10240, "cpu": 100, "servers": 2 }
        }
      },
      "locations": { "1": { "name": "Default", "enabled": true } },
      "eggs": {},
      "renewal": false
    },
    "afk": { "enabled": true, "path": "/afk", "every": 60, "coins": 1 }
  },
  "renewals": { "status": false, "cost": 10, "period": 7 }
}
SETTINGS

ok "settings.json written."

# ── npm install ────────────────────────────────────────────
step "Installing npm dependencies..."
cd "$INSTALL_DIR" || fail "Cannot cd to $INSTALL_DIR"
npm install > /dev/null 2>&1 || fail "npm install failed — check logs."
ok "npm packages installed."

# ── Start with PM2 ────────────────────────────────────────
step "Starting Kroxy with PM2..."

pm2 delete "$SERVICE_NAME" > /dev/null 2>&1 || true
pm2 start app.js --name "$SERVICE_NAME" > /dev/null 2>&1 || fail "PM2 failed to start app.js"
pm2 save > /dev/null 2>&1 || true

# Register PM2 on boot — output to /dev/null so no extra eval needed
pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true
systemctl enable pm2-root > /dev/null 2>&1 || true

ok "Kroxy is running."

# ── Done ──────────────────────────────────────────────────
echo ""
echo -e "${WHITE}${BOLD}"
cat << 'DONE'
  ┌─────────────────────────────────────────────┐
  │          ✓  Kroxy is installed!             │
  └─────────────────────────────────────────────┘
DONE
echo -e "${RESET}"
echo -e "  ${WHITE}${BOLD}Dashboard${RESET}    http://YOUR_SERVER_IP:${APP_PORT}"
echo -e "  ${WHITE}${BOLD}Panel URL${RESET}    ${PANEL_URL}"
echo -e "  ${WHITE}${BOLD}Install Dir${RESET}  ${INSTALL_DIR}"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠  Final step — set your Pterodactyl API key:${RESET}"
echo -e "  ${DIM}  nano ${INSTALL_DIR}/settings.json${RESET}"
echo -e "  ${DIM}  Find: \"key\": \"ptla_REPLACEME\"${RESET}"
echo -e "  ${DIM}  Replace with your Application API key from Pterodactyl admin${RESET}"
echo -e "  ${DIM}  Then run: pm2 restart ${SERVICE_NAME}${RESET}"
echo ""
echo -e "  ${DIM}Other commands:${RESET}"
echo -e "  ${DIM}  pm2 logs ${SERVICE_NAME}      — live logs${RESET}"
echo -e "  ${DIM}  pm2 restart ${SERVICE_NAME}   — restart${RESET}"
echo -e "  ${DIM}  pm2 stop ${SERVICE_NAME}      — stop${RESET}"
echo ""
