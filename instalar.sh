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
NEED_FIGMA_CLI=false

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

# — figma-cli
FIGMA_CLI_STATUS=""
if require_command fig-start; then
  FIGMA_CLI_STATUS="${GREEN}✅  figma-cli — instalado${RESET}"
else
  FIGMA_CLI_STATUS="${RED}❌  figma-cli — NO instalado${RESET}"
  NEED_FIGMA_CLI=true
fi

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
echo -e "   $FIGMA_CLI_STATUS"
separator

# ── Resumen de lo que se va a hacer ──────────────────────────
echo ""
NOTHING_TO_DO=true

if $NEED_NODE || $NEED_GIT || $NEED_BUN || $NEED_CLAUDE || $NEED_FIGMA || $NEED_FIGMA_CLI; then
  NOTHING_TO_DO=false
  echo -e "  ${BOLD}📦  Se va a instalar / configurar:${RESET}"
  $NEED_NODE      && echo -e "   ${CYAN}→${RESET} Node.js"
  $NEED_GIT       && echo -e "   ${CYAN}→${RESET} git"
  $NEED_BUN       && echo -e "   ${CYAN}→${RESET} Bun"
  $NEED_CLAUDE    && echo -e "   ${CYAN}→${RESET} Claude Code"
  $NEED_FIGMA     && echo -e "   ${CYAN}→${RESET} Figma MCP Server"
  $NEED_FIGMA_CLI && echo -e "   ${CYAN}→${RESET} figma-cli"
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
  $NEED_FIGMA     && n=$((n+1))
  $NEED_FIGMA_CLI && n=$((n+1))
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

# ── figma-cli ─────────────────────────────────────────────────
if $NEED_FIGMA_CLI; then
  step "Instalando figma-cli"
  run_quietly "Instalando figma-cli desde GitHub" npm install -g github:silships/figma-cli || {
    warn "Reintentando con sudo..."
    sudo npm install -g github:silships/figma-cli 2>/dev/null
  }
  if require_command fig-start; then
    ok "figma-cli instalado"
  else
    fail "No se pudo instalar figma-cli"
  fi
fi

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
# figma-cli
if require_command fig-start; then
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "figma-cli:" "✅ Instalado"
else
  printf "${CYAN}${BOLD}║${RESET}  %-18s  %s\n" "figma-cli:" "⚠️  Ver advertencias arriba"
fi
echo -e "${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}╠══════════════════════════════════════════════════════╣${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  ${BOLD}PRÓXIMOS PASOS:${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}"
echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}1.${RESET} Abrí una terminal NUEVA (para recargar el PATH)"
echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}2.${RESET} Ejecutá ${BOLD}claude${RESET} para iniciar"
echo -e "${CYAN}${BOLD}║${RESET}  ${GREEN}3.${RESET} Para Figma: /mcp → figma → Authenticate"
echo -e "${CYAN}${BOLD}║${RESET}"
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
