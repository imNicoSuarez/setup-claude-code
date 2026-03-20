#!/usr/bin/env bash
# ============================================================
#  🤖  INSTALADOR DE CLAUDE CODE
#  Verifica qué tenés instalado y solo instala lo que falta.
# ============================================================

set -euo pipefail

# ── Colores ───────────────────────────────────────────────────
BOLD="\033[1m"
DIM="\033[2m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
CYAN="\033[0;36m"
BLUE="\033[0;34m"
RESET="\033[0m"

ERRORS=()
SPINNER_PID=""
BACKGROUND_PID=""

# ── OS ────────────────────────────────────────────────────────
OS="unknown"
case "$(uname -s)" in
  Darwin) OS="mac" ;;
  Linux)  OS="linux" ;;
esac

if [ "$OS" = "unknown" ]; then
  echo -e "${RED}❌  Sistema no soportado. Usá macOS o Linux.${RESET}"
  exit 1
fi

# ── Helpers UI ────────────────────────────────────────────────
require_command() { command -v "$1" &>/dev/null; }

ok()   { echo -e "  ${GREEN}✅  $1${RESET}"; }
warn() { echo -e "  ${YELLOW}⚠️   $1${RESET}"; }
info() { echo -e "  ${DIM}→  $1${RESET}"; }
fail() { echo -e "  ${RED}❌  $1${RESET}"; ERRORS+=("$1"); }

separator() {
  echo -e "${DIM}  ──────────────────────────────────────────────────────${RESET}"
}

section() {
  echo ""
  echo -e "${BLUE}${BOLD}  $1${RESET}"
  separator
}

spinner_start() {
  local msg="$1"
  (
    local s=0
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    while kill -0 "$BACKGROUND_PID" 2>/dev/null; do
      printf "\r  ${CYAN}${frames[$s]}${RESET}  ${DIM}%s...${RESET}" "$msg"
      s=$(( (s+1) % ${#frames[@]} ))
      sleep 0.1
    done
    printf "\r"
  ) &
  SPINNER_PID=$!
}

spinner_stop() {
  [ -n "${SPINNER_PID:-}" ] && { kill "$SPINNER_PID" 2>/dev/null || true; wait "$SPINNER_PID" 2>/dev/null || true; SPINNER_PID=""; printf "\r"; }
}

run_quietly() {
  local label="$1"; shift
  local tmp; tmp=$(mktemp)
  ("$@" > "$tmp" 2>&1) &
  BACKGROUND_PID=$!
  spinner_start "$label"
  local rc=0
  wait "$BACKGROUND_PID" || rc=$?
  spinner_stop
  rm -f "$tmp"
  return $rc
}

# ══════════════════════════════════════════════════════════════
# FASE 1 — DIAGNÓSTICO (solo lectura, sin instalar nada)
# ══════════════════════════════════════════════════════════════

clear
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║       🤖  INSTALADOR DE CLAUDE CODE  🤖               ║${RESET}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${DIM}  Analizando tu sistema...${RESET}"
echo ""

# ── Estado de cada componente ─────────────────────────────────
NEED_NODE=false
NEED_BUN=false
NEED_GIT=false
NEED_CLAUDE=false
NEED_FIGMA=false
NEED_FRONTENDER_MCP=false
NEED_FIGMA_PLUGIN=false
# NEED_FIGMA_CLI=false               # ux-figma-cli desactivado temporalmente
# OLD_FIGMA_CLI_INSTALLED=false
# NEW_FIGMA_CLI_DIR="$HOME/.ux-figma-cli"

# — Node.js
NODE_STATUS=""
if require_command node; then
  NODE_VER=$(node --version | tr -d 'v')
  MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [ "$MAJOR" -ge 18 ]; then
    NODE_STATUS="${GREEN}✅  Node.js v${NODE_VER}${RESET}"
  else
    NODE_STATUS="${YELLOW}⚠️   Node.js v${NODE_VER} (desactualizado, se va a actualizar)${RESET}"
    NEED_NODE=true
  fi
else
  NODE_STATUS="${RED}❌  Node.js — NO instalado${RESET}"
  NEED_NODE=true
fi

# — npm
NPM_STATUS=""
if require_command npm; then
  NPM_VER=$(npm --version)
  NPM_STATUS="${GREEN}✅  npm v${NPM_VER}${RESET}"
else
  NPM_STATUS="${RED}❌  npm — NO instalado (se instala con Node.js)${RESET}"
fi

# — git
GIT_STATUS=""
if require_command git; then
  GIT_VER=$(git --version | awk '{print $3}')
  GIT_STATUS="${GREEN}✅  git v${GIT_VER}${RESET}"
else
  GIT_STATUS="${RED}❌  git — NO instalado${RESET}"
  NEED_GIT=true
fi

# — bun
BUN_STATUS=""
if require_command bun || [ -f "$HOME/.bun/bin/bun" ]; then
  BUN_VER=$(bun --version 2>/dev/null || "$HOME/.bun/bin/bun" --version 2>/dev/null || echo "?")
  BUN_STATUS="${GREEN}✅  bun v${BUN_VER}${RESET}"
else
  BUN_STATUS="${YELLOW}⚠️   bun — NO instalado (opcional, se va a instalar)${RESET}"
  NEED_BUN=true
fi

# — Claude Code
CLAUDE_STATUS=""
if require_command claude; then
  CLAUDE_VER=$(claude --version 2>&1 | head -1)
  CLAUDE_STATUS="${GREEN}✅  Claude Code ${CLAUDE_VER}${RESET}"
else
  CLAUDE_STATUS="${RED}❌  Claude Code — NO instalado${RESET}"
  NEED_CLAUDE=true
fi

# — Figma MCP
FIGMA_STATUS=""
if require_command claude && claude mcp list 2>/dev/null | grep -q "figma"; then
  FIGMA_STATUS="${GREEN}✅  Figma MCP — ya registrado${RESET}"
else
  FIGMA_STATUS="${RED}❌  Figma MCP — NO registrado${RESET}"
  NEED_FIGMA=true
fi

# — Frontender Web MCP
FRONTENDER_MCP_STATUS=""
if require_command claude && claude mcp list 2>/dev/null | grep -q "Frontender-Web-MCP"; then
  FRONTENDER_MCP_STATUS="${GREEN}✅  Frontender Web MCP — ya registrado${RESET}"
else
  FRONTENDER_MCP_STATUS="${RED}❌  Frontender Web MCP — NO registrado${RESET}"
  NEED_FRONTENDER_MCP=true
fi

# — Figma Plugin (claude-plugins-official)
FIGMA_PLUGIN_STATUS=""
if require_command claude && claude plugin list 2>/dev/null | grep -qi "figma"; then
  FIGMA_PLUGIN_STATUS="${GREEN}✅  Figma plugin — ya instalado${RESET}"
else
  FIGMA_PLUGIN_STATUS="${RED}❌  Figma plugin — NO instalado${RESET}"
  NEED_FIGMA_PLUGIN=true
fi

# — ux-figma-cli (desactivado temporalmente)
# FIGMA_CLI_STATUS=""
# # Detectar versión vieja (silships/figma-cli en ~/.figma-cli)
# if [ -d "$HOME/.figma-cli/.git" ] && git -C "$HOME/.figma-cli" remote get-url origin 2>/dev/null | grep -qi "figma-cli"; then
#   OLD_FIGMA_CLI_INSTALLED=true
# fi
# # Detectar versión nueva
# if [ -d "$NEW_FIGMA_CLI_DIR/.git" ] && git -C "$NEW_FIGMA_CLI_DIR" remote get-url origin 2>/dev/null | grep -qi "ux-figma-cli"; then
#   FIGMA_CLI_STATUS="${GREEN}✅  ux-figma-cli — instalado${RESET}"
# elif $OLD_FIGMA_CLI_INSTALLED; then
#   FIGMA_CLI_STATUS="${YELLOW}⚠️   figma-cli (versión vieja) instalado — se va a migrar al nuevo${RESET}"
#   NEED_FIGMA_CLI=true
# else
#   FIGMA_CLI_STATUS="${RED}❌  ux-figma-cli — NO instalado${RESET}"
#   NEED_FIGMA_CLI=true
# fi

# ── Mostrar diagnóstico ───────────────────────────────────────
section "📋 DIAGNÓSTICO DE TU SISTEMA"

echo -e "  ${BOLD}Herramientas base:${RESET}"
echo -e "   $NODE_STATUS"
echo -e "   $NPM_STATUS"
echo -e "   $GIT_STATUS"
echo -e "   $BUN_STATUS"
echo ""
echo -e "  ${BOLD}Claude Code y plugins:${RESET}"
echo -e "   $CLAUDE_STATUS"
echo -e "   $FIGMA_STATUS"
echo -e "   $FRONTENDER_MCP_STATUS"
echo -e "   $FIGMA_PLUGIN_STATUS"
# echo -e "   $FIGMA_CLI_STATUS"  # ux-figma-cli desactivado temporalmente
separator

# ── Resumen de lo que se va a hacer ──────────────────────────
echo ""
NOTHING_TO_DO=true

if $NEED_NODE || $NEED_GIT || $NEED_BUN || $NEED_CLAUDE || $NEED_FIGMA || $NEED_FRONTENDER_MCP || $NEED_FIGMA_PLUGIN; then
  NOTHING_TO_DO=false
  echo -e "  ${BOLD}📦  Se va a instalar / configurar:${RESET}"
  $NEED_NODE              && echo -e "   ${CYAN}→${RESET} Node.js"
  $NEED_GIT               && echo -e "   ${CYAN}→${RESET} git"
  $NEED_BUN               && echo -e "   ${CYAN}→${RESET} Bun"
  $NEED_CLAUDE            && echo -e "   ${CYAN}→${RESET} Claude Code"
  $NEED_FIGMA             && echo -e "   ${CYAN}→${RESET} Figma MCP Server"
  $NEED_FRONTENDER_MCP    && echo -e "   ${CYAN}→${RESET} Frontender Web MCP"
  $NEED_FIGMA_PLUGIN      && echo -e "   ${CYAN}→${RESET} Figma Plugin (claude-plugins-official)"
  # $NEED_FIGMA_CLI && echo -e "   ${CYAN}→${RESET} ux-figma-cli${OLD_FIGMA_CLI_INSTALLED:+ (migración desde versión vieja)}"  # desactivado temporalmente
else
  echo -e "  ${GREEN}${BOLD}🎉  ¡Todo ya está instalado y configurado!${RESET}"
fi

echo ""
read -rp "  Presioná ENTER para continuar (o Ctrl+C para cancelar): "
echo ""

if $NOTHING_TO_DO; then
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}║      ✅  TODO EN ORDEN — NADA QUE INSTALAR            ║${RESET}"
  echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}${BOLD}║${RESET}  Ejecutá ${BOLD}claude${RESET} en la terminal para empezar          ${CYAN}${BOLD}║${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo ""
  exit 0
fi

# ══════════════════════════════════════════════════════════════
# FASE 2 — INSTALACIÓN (solo lo que falta)
# ══════════════════════════════════════════════════════════════

STEP=0
count_steps() {
  local n=0
  $NEED_NODE      && n=$((n+1))
  $NEED_GIT       && n=$((n+1))
  $NEED_BUN       && n=$((n+1))
  $NEED_CLAUDE    && n=$((n+1))
  $NEED_FIGMA             && n=$((n+1))
  $NEED_FRONTENDER_MCP    && n=$((n+1))
  $NEED_FIGMA_PLUGIN      && n=$((n+1))
  # $NEED_FIGMA_CLI && n=$((n+1))  # ux-figma-cli desactivado temporalmente
  echo $n
}
TOTAL=$(count_steps)

step() {
  STEP=$((STEP+1))
  echo ""
  echo -e "${BLUE}${BOLD}  ▸ Paso ${STEP}/${TOTAL} — $1${RESET}"
  separator
}

# ── Funciones de instalación ──────────────────────────────────

install_node_mac() {
  if require_command brew; then
    brew install node 2>/dev/null || brew upgrade node 2>/dev/null || true
  elif require_command nvm; then
    nvm install 22 && nvm use 22
  else
    info "Instalando Homebrew primero..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew install node
  fi
}

install_node_linux() {
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null
  sudo apt-get install -y nodejs 2>/dev/null
}

# ── Node.js ───────────────────────────────────────────────────
if $NEED_NODE; then
  step "Instalando Node.js"
  if [ "$OS" = "mac" ]; then
    run_quietly "Instalando Node.js" install_node_mac && ok "Node.js $(node --version) instalado" || fail "No se pudo instalar Node.js"
  else
    run_quietly "Instalando Node.js" install_node_linux && ok "Node.js $(node --version) instalado" || fail "No se pudo instalar Node.js"
  fi
fi

# ── git ───────────────────────────────────────────────────────
if $NEED_GIT; then
  step "Instalando git"
  if [ "$OS" = "mac" ]; then
    run_quietly "Instalando git" bash -c "brew install git" && ok "git $(git --version | awk '{print $3}') instalado" || fail "No se pudo instalar git"
  else
    run_quietly "Instalando git" bash -c "sudo apt-get install -y git" && ok "git instalado" || fail "No se pudo instalar git"
  fi
fi

# ── Bun ───────────────────────────────────────────────────────
if $NEED_BUN; then
  step "Instalando Bun"
  run_quietly "Instalando Bun" bash -c "curl -fsSL https://bun.sh/install | bash" || true
  if [ -f "$HOME/.bun/bin/bun" ]; then
    ok "Bun instalado"
  else
    warn "Bun no disponible (no es crítico para Claude Code)"
  fi
fi
export PATH="$HOME/.bun/bin:$PATH"

# ── Claude Code ───────────────────────────────────────────────
if $NEED_CLAUDE; then
  step "Instalando Claude Code"
  run_quietly "Descargando Claude Code" npm install -g @anthropic-ai/claude-code || {
    warn "Reintentando con sudo..."
    sudo npm install -g @anthropic-ai/claude-code 2>/dev/null
  }
  if require_command claude; then
    CLAUDE_VER=$(claude --version 2>&1 | head -1)
    ok "Claude Code ${CLAUDE_VER}"
  else
    fail "No se pudo instalar Claude Code"
  fi
fi

# ── Figma MCP ─────────────────────────────────────────────────
if $NEED_FIGMA; then
  step "Registrando Figma MCP"
  if require_command claude; then
    claude mcp add --scope user --transport http figma https://mcp.figma.com/mcp 2>&1 && \
      ok "Figma MCP registrado globalmente" || fail "No se pudo registrar Figma MCP"
  else
    warn "Claude Code no disponible, saltando Figma MCP"
  fi
fi

# ── Frontender Web MCP ────────────────────────────────────────
if $NEED_FRONTENDER_MCP; then
  step "Registrando Frontender Web MCP"
  if require_command claude; then
    claude mcp add Frontender-Web-MCP -- mcp-remote-proxy https://frontender-web-mcp.melioffice.com/mcp --transport http 2>&1 && \
      ok "Frontender Web MCP registrado" || fail "No se pudo registrar Frontender Web MCP"
  else
    warn "Claude Code no disponible, saltando Frontender Web MCP"
  fi
fi

# ── Figma Plugin ───────────────────────────────────────────────
if $NEED_FIGMA_PLUGIN; then
  step "Instalando Figma Plugin"
  if require_command claude; then
    claude plugin install figma@claude-plugins-official 2>&1 && \
      ok "Figma plugin instalado" || fail "No se pudo instalar el Figma plugin"
  else
    warn "Claude Code no disponible, saltando Figma plugin"
  fi
fi

# ── ux-figma-cli (desactivado temporalmente) ──────────────────
# if $NEED_FIGMA_CLI; then
#   step "Instalando ux-figma-cli"
#
#   # Desinstalar versión vieja si existe
#   if $OLD_FIGMA_CLI_INSTALLED; then
#     info "Eliminando figma-cli (versión anterior)..."
#     rm -rf "$HOME/.figma-cli"
#     # Limpiar alias viejo del shell rc
#     for RC_CLEAN in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
#       if [ -f "$RC_CLEAN" ] && grep -q "alias fig-start=" "$RC_CLEAN"; then
#         if [ "$OS" = "mac" ]; then
#           sed -i '' '/alias fig-start=/d' "$RC_CLEAN"
#           sed -i '' '/# Figma CLI/d' "$RC_CLEAN"
#         else
#           sed -i '/alias fig-start=/d' "$RC_CLEAN"
#           sed -i '/# Figma CLI/d' "$RC_CLEAN"
#         fi
#         info "Alias anterior eliminado de $RC_CLEAN"
#       fi
#     done
#     ok "figma-cli anterior desinstalado"
#   fi
#
#   # Clonar o actualizar el nuevo repo
#   if [ -d "$NEW_FIGMA_CLI_DIR/.git" ]; then
#     info "Actualizando repo existente en $NEW_FIGMA_CLI_DIR"
#     run_quietly "Actualizando ux-figma-cli" bash -c "cd '$NEW_FIGMA_CLI_DIR' && git pull" || true
#   else
#     [ -d "$NEW_FIGMA_CLI_DIR" ] && rm -rf "$NEW_FIGMA_CLI_DIR"
#     run_quietly "Clonando ux-figma-cli" git clone git@github.com:imNicoSuarez/ux-figma-cli.git "$NEW_FIGMA_CLI_DIR" || {
#       fail "No se pudo clonar el repositorio ux-figma-cli"
#     }
#   fi
#
#   if [ -d "$NEW_FIGMA_CLI_DIR" ]; then
#     # Instalar dependencias
#     run_quietly "Instalando dependencias de ux-figma-cli" bash -c "cd '$NEW_FIGMA_CLI_DIR' && npm install" || {
#       fail "npm install falló en ux-figma-cli"
#     }
#
#     # Ejecutar setup-alias para agregar fig-start al shell rc
#     info "Ejecutando setup-alias..."
#     (cd "$NEW_FIGMA_CLI_DIR" && npm run setup-alias 2>&1) || {
#       fail "npm run setup-alias falló"
#     }
#
#     # Detectar shell rc y hacer source
#     SHELL_RC=""
#     if [ -f "$HOME/.zshrc" ]; then
#       SHELL_RC="$HOME/.zshrc"
#     elif [ -f "$HOME/.bashrc" ]; then
#       SHELL_RC="$HOME/.bashrc"
#     elif [ -f "$HOME/.bash_profile" ]; then
#       SHELL_RC="$HOME/.bash_profile"
#     fi
#
#     if [ -n "$SHELL_RC" ]; then
#       # shellcheck disable=SC1090
#       source "$SHELL_RC" 2>/dev/null || true
#     fi
#
#     if require_command fig-start || ([ -n "$SHELL_RC" ] && source "$SHELL_RC" 2>/dev/null && require_command fig-start); then
#       ok "ux-figma-cli instalado — usá 'fig-start' en una terminal nueva"
#     else
#       warn "ux-figma-cli configurado — abrí una terminal nueva y ejecutá 'fig-start'"
#     fi
#   fi
# fi

# ══════════════════════════════════════════════════════════════
# FASE 3 — RESUMEN FINAL
# ══════════════════════════════════════════════════════════════

echo ""
echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
if [ ${#ERRORS[@]} -eq 0 ]; then
  echo -e "${CYAN}${BOLD}║         ✅  INSTALACIÓN COMPLETADA CON ÉXITO          ║${RESET}"
else
  echo -e "${CYAN}${BOLD}║       ⚠️   INSTALACIÓN COMPLETADA CON ADVERTENCIAS    ║${RESET}"
fi
echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}"
# Claude Code
FINAL_CLAUDE=$(claude --version 2>&1 | head -1 || echo "no disponible")
printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Claude Code:" "$FINAL_CLAUDE"
# Figma MCP
if require_command claude && claude mcp list 2>/dev/null | grep -q "figma"; then
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Figma MCP:" "✅ Registrado"
else
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Figma MCP:" "⚠️  Verificar en Claude Code"
fi
# Frontender Web MCP
if require_command claude && claude mcp list 2>/dev/null | grep -q "Frontender-Web-MCP"; then
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Frontender MCP:" "✅ Registrado"
else
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Frontender MCP:" "⚠️  Verificar en Claude Code"
fi
# Figma Plugin
if require_command claude && claude plugin list 2>/dev/null | grep -qi "figma"; then
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Figma Plugin:" "✅ Instalado"
else
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "Figma Plugin:" "⚠️  Verificar en Claude Code"
fi
# ux-figma-cli (desactivado temporalmente)
# if require_command fig-start || { [ -d "$NEW_FIGMA_CLI_DIR/node_modules" ] && grep -q "fig-start" "$HOME/.zshrc" 2>/dev/null; }; then
#   printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "ux-figma-cli:" "✅ Instalado (nueva terminal para fig-start)"
# else
#   printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "ux-figma-cli:" "⚠️  Ver advertencias arriba"
# fi
echo -e "${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  ${BOLD}PRÓXIMOS PASOS:${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}1.${RESET} Abrí una terminal NUEVA (para recargar el PATH)"
echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}2.${RESET} Ejecutá ${BOLD}claude${RESET} para iniciar Claude Code"
echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}3.${RESET} Para Figma MCP: /mcp → figma → Authenticate"
echo -e "${CYAN}${BOLD}║${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}3.${RESET} Ejecutá ${BOLD}uxclaude${RESET} para conectarte a Figma ${GREEN}✅ recomendado${RESET}"  # ux-figma-cli desactivado temporalmente
# echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════╣${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  ${BOLD}UX FIGMA CLI — CÓMO USAR:${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  ${CYAN}uxclaude${RESET}    Inicia Figma + plugin + Claude Code ${GREEN}← recomendado${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  ${CYAN}fig-start${RESET}   Alias alternativo (mismo efecto)"
# echo -e "${CYAN}${BOLD}║${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  ${BOLD}Instalación del plugin (1 sola vez):${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  En Figma: Plugins → Development → Import plugin from manifest"
# echo -e "${CYAN}${BOLD}║${RESET}  Manifest: ${YELLOW}$NEW_FIGMA_CLI_DIR/plugin/manifest.json${RESET}"
# echo -e "${CYAN}${BOLD}║${RESET}  Luego: Plugins → Development → UX Claude  (cada sesión)"
# echo -e "${CYAN}${BOLD}║${RESET}"
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════╣${RESET}"
  echo -e "${CYAN}${BOLD}║${RESET}  ${RED}${BOLD}ERRORES:${RESET}"
  for err in "${ERRORS[@]}"; do
    printf "${CYAN}${BOLD}║${RESET}  ${RED}• %s${RESET}\n" "$err"
  done
  echo -e "${CYAN}${BOLD}║${RESET}"
fi
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
