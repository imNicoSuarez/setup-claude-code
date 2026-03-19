# 🤖 Setup Claude Code

Instalador automático de **Claude Code** con todo lo necesario para trabajar: Node.js, git, Bun, el MCP de Figma y las Skills de Antigravity.

Detecta qué ya tenés instalado y **solo instala lo que falta**.

---

## Instalación rápida (sin clonar el repo)

```bash
curl -fsSL https://raw.githubusercontent.com/nicsuarez/setup-claude-code/main/instalar.sh | bash
```

> Reemplazá `nicsuarez` con tu usuario de GitHub si forkeaste el repo.

---

## ¿Qué instala?

| Componente | Descripción |
|---|---|
| **Node.js ≥ 18** | Runtime requerido por Claude Code |
| **npm** | Se instala junto con Node.js |
| **git** | Control de versiones |
| **Bun** | Runtime alternativo (opcional, mejora performance) |
| **Claude Code** | CLI oficial de Anthropic (`@anthropic-ai/claude-code`) |
| **Figma MCP Server** | Integración con Figma via MCP para leer diseños desde Claude |
| **figma-cli** | CLI para trabajar con archivos de Figma desde la terminal ([silships/figma-cli](https://github.com/silships/figma-cli)) |

---

## ¿Cómo funciona?

El instalador tiene 3 fases:

### Fase 1 — Diagnóstico
Escanea el sistema sin modificar nada y muestra el estado de cada componente.

```
  Herramientas base:
   ✅  Node.js v22.x.x
   ✅  npm v10.x.x
   ❌  git — NO instalado
   ⚠️   bun — NO instalado (opcional, se va a instalar)

  Claude Code y plugins:
   ❌  Claude Code — NO instalado
   ❌  Figma MCP — NO registrado
   ❌  Skills de Antigravity — NO instaladas
```

### Fase 2 — Instalación selectiva
Instala **únicamente** lo que no estaba. Si todo está al día, el script termina sin tocar nada.

### Fase 3 — Resumen
Muestra el resultado final con el estado de cada componente y los próximos pasos.

---

## Compatibilidad

| Sistema Operativo | Soporte |
|---|---|
| macOS (Intel / Apple Silicon) | ✅ |
| Linux (Debian / Ubuntu) | ✅ |
| Windows | ❌ |

---

## Requisitos previos

- Conexión a internet
- En macOS: se instala Homebrew automáticamente si no está presente
- En Linux: se requiere `sudo` para instalar paquetes del sistema

---

## Instalación manual (clonando el repo)

```bash
git clone https://github.com/nicsuarez/setup-claude-code.git
cd setup-claude-code
chmod +x instalar.sh
./instalar.sh
```

---

## Próximos pasos después de instalar

1. Abrí una **terminal nueva** para recargar el `PATH`
2. Ejecutá `claude` para iniciar Claude Code
3. Para autenticar Figma: dentro de Claude ejecutá `/mcp` → `figma` → **Authenticate**

---

## Estructura del proyecto

```
setup-claude-code/
├── instalar.sh             # Script principal de instalación
└── .pre-commit-config.yaml # Hooks de pre-commit (trailing whitespace, YAML lint)
```

---

## Contribuir

1. Forkeá el repo
2. Creá una rama: `git checkout -b feature/mi-mejora`
3. Commiteá los cambios: `git commit -m "feat: descripción"`
4. Abrí un Pull Request

---

## Licencia

MIT
