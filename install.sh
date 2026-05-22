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

set -euo pipefail

# ── Colors ────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'

# ── Helpers ───────────────────────────────────────────────
step()  { echo -e "\n${WHITE}${BOLD}[•] $1${RESET}"; }
ok()    { echo -e "  ${GREEN}✓${RESET}  $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET}  $1"; }
fail()  { echo -e "\n${RED}${BOLD}[✗] ERROR: $1${RESET}\n"; exit 1; }
dim()   { echo -e "  ${DIM}$1${RESET}"; }
ask()   { echo -e "\n${WHITE}${BOLD}$1${RESET}"; }

INSTALL_DIR="/opt/kroxy"
SERVICE_NAME="kroxy"
ALREADY_INSTALLED=false

# ── Banner ────────────────────────────────────────────────
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
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}\n"
sleep 0.5

# ── Root check ────────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  fail "Please run as root: sudo bash install.sh"
fi

# ── Already installed? ────────────────────────────────────
if [[ -f "$INSTALL_DIR/app.js" ]]; then
  ALREADY_INSTALLED=true
  warn "Kroxy is already installed at ${INSTALL_DIR}"
  echo -e "  ${DIM}Found existing installation. Skipping dependency setup.${RESET}"
fi

# ── Gather user input ─────────────────────────────────────
ask "→ Panel URL — your Pterodactyl panel domain (e.g. https://panel.yourdomain.com):"
read -rp "  URL: " PANEL_URL
[[ -z "$PANEL_URL" ]] && fail "Panel URL cannot be empty."

ask "→ Admin user email (your account on Kroxy):"
read -rp "  Email: " ADMIN_EMAIL
[[ -z "$ADMIN_EMAIL" ]] && fail "Admin email cannot be empty."

ask "→ Port to run Kroxy on (default: 3001):"
read -rp "  Port: " APP_PORT
APP_PORT="${APP_PORT:-3001}"

ask "→ Discord OAuth Client ID:"
read -rp "  Client ID: " DISCORD_CLIENT_ID
[[ -z "$DISCORD_CLIENT_ID" ]] && fail "Discord Client ID cannot be empty."

ask "→ Discord OAuth Client Secret:"
read -rp "  Client Secret: " DISCORD_CLIENT_SECRET
[[ -z "$DISCORD_CLIENT_SECRET" ]] && fail "Discord Client Secret cannot be empty."

ask "→ Discord Bot Token (for role/join features, or press Enter to skip):"
read -rp "  Bot Token: " DISCORD_BOT_TOKEN
DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-placeholder}"

ask "→ Session secret (random string, or press Enter to auto-generate):"
read -rp "  Secret: " SESSION_SECRET
if [[ -z "$SESSION_SECRET" ]]; then
  SESSION_SECRET=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 48)
  ok "Auto-generated session secret."
fi

echo ""
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo -e "  ${WHITE}${BOLD}Summary${RESET}"
dim "  Panel URL  : $PANEL_URL"
dim "  Admin Email: $ADMIN_EMAIL"
dim "  Note       : Pterodactyl API key must be set in settings.json after install"
dim "  Port       : $APP_PORT"
dim "  Install dir: $INSTALL_DIR"
echo -e "${DIM}  ─────────────────────────────────────────────${RESET}"
echo ""
ask "→ Proceed with installation? (y/N):"
read -rp "  " CONFIRM
[[ "${CONFIRM,,}" != "y" && "${CONFIRM,,}" != "yes" ]] && { echo -e "\n${GRAY}  Cancelled.${RESET}\n"; exit 0; }

# ── Dependencies (skip if already installed) ──────────────
if [[ "$ALREADY_INSTALLED" == false ]]; then
  step "Installing system dependencies..."
  apt-get update -qq
  apt-get install -y -qq curl git unzip sqlite3 > /dev/null 2>&1
  ok "System packages installed."

  step "Installing Node.js 20..."
  if ! command -v node &>/dev/null || [[ "$(node -v | cut -d. -f1 | tr -d 'v')" -lt 18 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
    ok "Node.js $(node -v) installed."
  else
    ok "Node.js $(node -v) already present — skipping."
  fi

  step "Installing PM2..."
  if ! command -v pm2 &>/dev/null; then
    npm install -g pm2 --silent > /dev/null 2>&1
    ok "PM2 installed."
  else
    ok "PM2 already present — skipping."
  fi
else
  step "Skipping dependency setup (already installed)."
  ok "Node.js $(node -v)"
  ok "PM2 $(pm2 -v 2>/dev/null || echo 'not found — run: npm i -g pm2')"
fi

# ── Copy / update files ───────────────────────────────────
step "Setting up Kroxy files..."

# Stop existing PM2 process cleanly without kicking the session
if pm2 list 2>/dev/null | grep -q "$SERVICE_NAME"; then
  dim "Stopping existing PM2 process (session preserved)..."
  pm2 stop "$SERVICE_NAME" > /dev/null 2>&1 || true
fi

mkdir -p "$INSTALL_DIR"

# Copy panel files (from same dir as this script, or clone)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/app.js" ]]; then
  dim "Copying from local source..."
  cp -r "$SCRIPT_DIR"/. "$INSTALL_DIR/"
  ok "Files copied."
else
  warn "app.js not found next to installer — cloning from GitHub..."
  dim "Make sure the repo URL below is correct, or place install.sh next to the panel files."
  # Fallback: pull from a repo if available
  # git clone https://github.com/yourrepo/kroxy.git "$INSTALL_DIR" > /dev/null 2>&1
  fail "No panel source found. Place install.sh in the same folder as app.js and re-run."
fi

# ── Write settings.json ───────────────────────────────────
step "Writing configuration..."

SETTINGS_FILE="$INSTALL_DIR/settings.json"

# Preserve existing settings.json as backup if updating
if [[ -f "$SETTINGS_FILE" && "$ALREADY_INSTALLED" == true ]]; then
  cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
  dim "Backed up existing settings.json → settings.json.bak"
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
      "api": {
        "enabled": true,
        "code": "${SESSION_SECRET}"
      },
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
warn "Pterodactyl API key not set yet — add it after install:"
dim "  nano ${INSTALL_DIR}/settings.json   →   pterodactyl.key"

# ── Install npm packages ───────────────────────────────────
step "Installing npm dependencies..."
cd "$INSTALL_DIR"
npm install --silent > /dev/null 2>&1
ok "npm packages installed."

# ── PM2 setup ─────────────────────────────────────────────
step "Starting Kroxy with PM2..."
cd "$INSTALL_DIR"

# Delete old process if exists, then start fresh — no shell exit
pm2 delete "$SERVICE_NAME" > /dev/null 2>&1 || true
pm2 start app.js --name "$SERVICE_NAME" --no-autorestart=false > /dev/null 2>&1
pm2 save > /dev/null 2>&1

# Set PM2 to restart on reboot (non-interactive, doesn't affect current session)
pm2 startup systemd -u root --hp /root > /dev/null 2>&1 || true
systemctl enable pm2-root > /dev/null 2>&1 || true

ok "Kroxy started via PM2."

# ── Done ─────────────────────────────────────────────────
echo ""
echo -e "${WHITE}${BOLD}"
cat << 'DONE'
  ┌────────────────────────────────────────────┐
  │         ✓  Kroxy is installed!             │
  └────────────────────────────────────────────┘
DONE
echo -e "${RESET}"
echo -e "  ${WHITE}${BOLD}Dashboard URL${RESET}   http://YOUR_SERVER_IP:${APP_PORT}"
echo -e "  ${WHITE}${BOLD}Panel URL${RESET}       ${PANEL_URL}"
echo -e "  ${WHITE}${BOLD}Admin Email${RESET}     ${ADMIN_EMAIL}"
echo -e "  ${WHITE}${BOLD}Install Dir${RESET}     ${INSTALL_DIR}"
echo ""
echo -e "  ${YELLOW}${BOLD}Next step:${RESET} Set your Pterodactyl API key:"
echo -e "  ${DIM}  nano ${INSTALL_DIR}/settings.json${RESET}"
echo -e "  ${DIM}  → pterodactyl.key = your ptla_xxxx Application API key${RESET}"
echo -e "  ${DIM}  Then: pm2 restart ${SERVICE_NAME}${RESET}"
echo ""
echo -e "  ${DIM}Useful commands:${RESET}"
echo -e "  ${DIM}  pm2 logs ${SERVICE_NAME}       — view live logs${RESET}"
echo -e "  ${DIM}  pm2 restart ${SERVICE_NAME}    — restart panel${RESET}"
echo -e "  ${DIM}  pm2 stop ${SERVICE_NAME}       — stop panel${RESET}"
echo -e "  ${DIM}  nano ${INSTALL_DIR}/settings.json — edit config${RESET}"
echo ""
