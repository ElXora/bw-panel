#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════╗
# ║   ShadowlessDash B&W Panel — One-Command Installer  ║
# ║   by @MrAwo69                                        ║
# ╚══════════════════════════════════════════════════════╝

set -e

# ── Colors ──────────────────────────────────────────────
R='\033[0;31m'  G='\033[0;32m'  Y='\033[1;33m'
W='\033[1;37m'  D='\033[0;37m'  N='\033[0m'

clear
echo -e "${W}"
cat << 'BANNER'
 ██████╗ ██╗    ██╗    ██████╗  █████╗ ███╗   ██╗███████╗██╗     
 ██╔══██╗██║    ██║    ██╔══██╗██╔══██╗████╗  ██║██╔════╝██║     
 ██████╔╝██║ █╗ ██║    ██████╔╝███████║██╔██╗ ██║█████╗  ██║     
 ██╔══██╗██║███╗██║    ██╔═══╝ ██╔══██║██║╚██╗██║██╔══╝  ██║     
 ██████╔╝╚███╔███╔╝    ██║     ██║  ██║██║ ╚████║███████╗███████╗
 ╚═════╝  ╚══╝╚══╝     ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝
BANNER
echo -e "${D}   ShadowlessDash — Black & White Edition — by @MrAwo69${N}"
echo ""

# ── Root check ──────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${R}[✗] Please run as root: sudo bash install.sh${N}"
  exit 1
fi

# ── Prompts ─────────────────────────────────────────────
echo -e "${Y}[?] Panel URL (e.g. https://panel.yourdomain.com):${N}"
read -rp "    > " PANEL_URL
PANEL_URL="${PANEL_URL%/}"
if [[ -z "$PANEL_URL" ]]; then
  echo -e "${R}[✗] Panel URL is required.${N}"; exit 1
fi

echo ""
echo -e "${Y}[?] Discord OAuth Client ID:${N}"
read -rp "    > " DISCORD_ID

echo ""
echo -e "${Y}[?] Discord OAuth Client Secret:${N}"
read -rp "    > " DISCORD_SECRET

echo ""
echo -e "${Y}[?] Discord Bot Token:${N}"
read -rp "    > " BOT_TOKEN

echo ""
echo -e "${Y}[?] What port should the panel run on? [default: 3001]:${N}"
read -rp "    > " PANEL_PORT
PANEL_PORT="${PANEL_PORT:-3001}"

echo ""
echo -e "${Y}[?] Panel display name [default: BW Panel]:${N}"
read -rp "    > " PANEL_NAME
PANEL_NAME="${PANEL_NAME:-BW Panel}"

echo ""
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${W} Installing — please wait...${N}"
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

# ── System deps ─────────────────────────────────────────
echo -e "\n${D}[1/5] Installing system dependencies...${N}"
apt-get update -qq
apt-get install -y -qq curl git unzip nodejs npm 2>/dev/null || true

# Install Node 20 if needed
NODE_VER=$(node -v 2>/dev/null | cut -c2- | cut -d. -f1)
if [[ -z "$NODE_VER" || "$NODE_VER" -lt 18 ]]; then
  echo -e "${D}      Installing Node.js 20...${N}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
  apt-get install -y -qq nodejs > /dev/null 2>&1
fi

# Install PM2
if ! command -v pm2 &> /dev/null; then
  echo -e "${D}      Installing PM2...${N}"
  npm install -g pm2 --silent > /dev/null 2>&1
fi

# ── Download panel ──────────────────────────────────────
INSTALL_DIR="/var/www/bwpanel"
echo -e "\n${D}[2/5] Setting up panel files in ${INSTALL_DIR}...${N}"
mkdir -p "$INSTALL_DIR"

# Copy self (the script's directory = panel files)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
  cp -r "$SCRIPT_DIR"/. "$INSTALL_DIR/"
fi

cd "$INSTALL_DIR"

# ── npm install ─────────────────────────────────────────
echo -e "\n${D}[3/5] Installing npm packages...${N}"
npm install --silent > /dev/null 2>&1

# ── Write settings.json ─────────────────────────────────
echo -e "\n${D}[4/5] Writing configuration...${N}"

SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c 48)
CALLBACK_URL="${PANEL_URL}/auth/callback"

cat > "$INSTALL_DIR/settings.json" << JSON
{
  "name": "${PANEL_NAME}",
  "logo": "https://cdn.discordapp.com/emojis/1234567890.png",
  "pterodactyl": {
    "domain": "${PANEL_URL}",
    "key": "ptla_CHANGEME"
  },
  "announcements": {
    "enabled": false,
    "message": ""
  },
  "timezone": "UTC",
  "version": "1.0.0",
  "testing": false,
  "website": {
    "port": ${PANEL_PORT},
    "secret": "${SECRET}"
  },
  "linkvertise": {
    "userid": "50000",
    "dailyLimit": 1,
    "coins": 10
  },
  "database": "sqlite://database.sqlite",
  "api": {
    "email": {
      "enabled": false,
      "resend": ""
    },
    "client": {
      "accountSwitcher": false,
      "api": {
        "enabled": true,
        "code": "${SECRET}"
      },
      "j4r": {
        "enabled": false,
        "ads": []
      },
      "bot": {
        "token": "${BOT_TOKEN}",
        "joinguild": {
          "enabled": false,
          "guildid": []
        }
      },
      "oauth2": {
        "id": "${DISCORD_ID}",
        "secret": "${DISCORD_SECRET}",
        "link": "${CALLBACK_URL}",
        "callbackpath": "/auth/callback",
        "prompt": true
      },
      "coins": {
        "enabled": true,
        "name": "Credits"
      },
      "packages": {
        "default": "default",
        "list": {
          "default": {
            "ram": 1024,
            "disk": 5120,
            "cpu": 100,
            "servers": 1
          }
        }
      },
      "locations": [
        {
          "name": "Default",
          "id": "1"
        }
      ],
      "eggs": {
        "paper": {
          "display": "Paper Minecraft",
          "minimum": { "ram": 512, "disk": 1024, "cpu": 50 },
          "maximum": { "ram": null, "disk": null, "cpu": null },
          "info": { "egg": 3, "docker_image": "ghcr.io/pterodactyl/yolks:java_17", "startup": "java -Xms128M -XX:MaxRAMPercentage=95.0 -Dterminal.jline=false -Dterminal.ansi=true -jar {{SERVER_JARFILE}}", "environment": { "SERVER_JARFILE": "server.jar", "BUILD_NUMBER": "latest" }, "feature_limits": { "databases": 1, "backups": 1 } }
        }
      }
    },
    "afk": {
      "enabled": false,
      "every": 60,
      "coins": 1
    }
  },
  "renewals": {
    "status": false,
    "cost": 100,
    "time": 7
  }
}
JSON

# ── Start with PM2 ──────────────────────────────────────
echo -e "\n${D}[5/5] Starting panel with PM2...${N}"
cd "$INSTALL_DIR"
pm2 delete bwpanel 2>/dev/null || true
pm2 start app.js --name bwpanel --no-autorestart > /dev/null 2>&1 || \
pm2 start app.js --name bwpanel > /dev/null 2>&1
pm2 save > /dev/null 2>&1
pm2 startup > /dev/null 2>&1 || true

# ── Done ────────────────────────────────────────────────
echo ""
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo -e "${G}[✓] Panel installed successfully!${N}"
echo ""
echo -e "${W}  Panel URL:    ${G}http://localhost:${PANEL_PORT}${N}"
echo -e "${W}  Install dir:  ${D}${INSTALL_DIR}${N}"
echo -e "${W}  Config:       ${D}${INSTALL_DIR}/settings.json${N}"
echo ""
echo -e "${D}  PM2 commands:${N}"
echo -e "${D}    pm2 logs bwpanel    — view logs${N}"
echo -e "${D}    pm2 restart bwpanel — restart${N}"
echo -e "${D}    pm2 stop bwpanel    — stop${N}"
echo ""
echo -e "${Y}[!] Make sure your Discord OAuth redirect URL is:${N}"
echo -e "${W}    ${CALLBACK_URL}${N}"
echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
echo ""
