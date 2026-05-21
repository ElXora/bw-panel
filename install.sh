#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════╗
# ║   ShadowlessDash B&W Panel — One-Command Installer  ║
# ║   by @MrAwo69                                        ║
# ╚══════════════════════════════════════════════════════╝

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Colors ──────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
W='\033[1;37m'
D='\033[0;37m'
N='\033[0m'

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
  echo -e "${R}[✗] Panel URL is required.${N}"
  exit 1
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

apt-get install -y -qq \
  curl \
  git \
  unzip \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  >/dev/null 2>&1

# ── Install Node.js 20 safely ───────────────────────────
NODE_VER=$(node -v 2>/dev/null | cut -d'v' -f2 | cut -d. -f1 || echo "")

if [[ -z "$NODE_VER" || "$NODE_VER" -lt 20 ]]; then
  echo -e "${D}      Installing Node.js 20 safely...${N}"

  apt-get remove -y nodejs npm >/dev/null 2>&1 || true

  rm -f /etc/apt/sources.list.d/nodesource.list

  mkdir -p /etc/apt/keyrings

  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

  echo \
    "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list

  apt-get update -qq

  apt-get install -y nodejs >/dev/null 2>&1

  hash -r

  echo -e "${G}      Node.js $(node -v) installed successfully.${N}"
else
  echo -e "${G}      Node.js $(node -v) already installed.${N}"
fi

# ── Install PM2 ─────────────────────────────────────────
if ! command -v pm2 >/dev/null 2>&1; then
  echo -e "${D}      Installing PM2...${N}"

  npm install -g pm2 --silent >/dev/null 2>&1

  echo -e "${G}      PM2 installed successfully.${N}"
else
  echo -e "${G}      PM2 already installed.${N}"
fi

# ── Setup panel directory ───────────────────────────────
INSTALL_DIR="/var/www/bwpanel"

echo -e "\n${D}[2/5] Setting up panel files in ${INSTALL_DIR}...${N}"

mkdir -p "$INSTALL_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
  cp -r "$SCRIPT_DIR"/. "$INSTALL_DIR/"
fi

cd "$INSTALL_DIR"

# ── Install npm packages ────────────────────────────────
echo -e "\n${D}[3/5] Installing npm packages...${N}"

npm install --silent >/dev/null 2>&1

echo -e "${G}      npm packages installed.${N}"

# ── Write settings.json ─────────────────────────────────
echo -e "\n${D}[4/5] Writing configuration...${N}"

SECRET=$(tr -dc 'a-zA-Z0-9!@#$%^&*' </dev/urandom | head -c 48)

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

          "minimum": {
            "ram": 512,
            "disk": 1024,
            "cpu": 50
          },

          "maximum": {
            "ram": null,
            "disk": null,
            "cpu": null
          },

          "info": {
            "egg": 3,

            "docker_image": "ghcr.io/pterodactyl/yolks:java_17",

            "startup": "java -Xms128M -XX:MaxRAMPercentage=95.0 -Dterminal.jline=false -Dterminal.ansi=true -jar {{SERVER_JARFILE}}",

            "environment": {
              "SERVER_JARFILE": "server.jar",
              "BUILD_NUMBER": "latest"
            },

            "feature_limits": {
              "databases": 1,
              "backups": 1
            }
          }
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

echo -e "${G}      Configuration written successfully.${N}"

# ── Start with PM2 ──────────────────────────────────────
echo -e "\n${D}[5/5] Starting panel with PM2...${N}"

cd "$INSTALL_DIR"

pm2 delete bwpanel >/dev/null 2>&1 || true

pm2 start app.js --name bwpanel >/dev/null 2>&1

pm2 save >/dev/null 2>&1

pm2 startup >/dev/null 2>&1 || true

# ── Finished ────────────────────────────────────────────
echo ""

echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo -e "${G}[✓] Panel installed successfully!${N}"

echo ""

echo -e "${W}  Panel URL:    ${G}http://localhost:${PANEL_PORT}${N}"

echo -e "${W}  Install dir:  ${D}${INSTALL_DIR}${N}"

echo -e "${W}  Config:       ${D}${INSTALL_DIR}/settings.json${N}"

echo ""

echo -e "${D}  PM2 commands:${N}"

echo -e "${D}    pm2 logs bwpanel     — view logs${N}"

echo -e "${D}    pm2 restart bwpanel  — restart${N}"

echo -e "${D}    pm2 stop bwpanel     — stop${N}"

echo ""

echo -e "${Y}[!] Make sure your Discord OAuth redirect URL is:${N}"

echo -e "${W}    ${CALLBACK_URL}${N}"

echo -e "${W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"

echo ""
