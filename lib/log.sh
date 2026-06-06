#!/usr/bin/env bash
# lib/log.sh — shared color definitions and logging helpers
#
# Source this file from any script:
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/log.sh"
#   # or from a known root:
#   source "$DOTFILES_ROOT/lib/log.sh"
#
# Provides two families:
#
#   Validation style (pass/fail/warn/section):
#     pass  "message"    → green ✓
#     fail  "message"    → red ✗  (increments $ERRORS)
#     warn  "message"    → yellow ! (increments $WARNINGS)
#     section "title"    → blue section header
#
#   Script style (log_info/log_success/log_warning/log_error/log_step):
#     log_info    "message"   → blue   [INFO]
#     log_success "message"   → green  [SUCCESS]
#     log_warning "message"   → yellow [WARNING]
#     log_error   "message"   → red    [ERROR]
#     log_step    "message"   → cyan   [STEP]
#
# Callers that use pass/fail/warn must declare:
#   ERRORS=0
#   WARNINGS=0
# before sourcing (or after) so the counters exist.

# ── Color codes ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Validation-style helpers ───────────────────────────────────────────────
pass()    { echo -e "  ${GREEN}✓${NC} $1"; }
fail()    { echo -e "  ${RED}✗${NC} $1"; ((ERRORS++))   || true; }
warn()    { echo -e "  ${YELLOW}!${NC} $1"; ((WARNINGS++)) || true; }
section() { echo -e "\n${BLUE}── $1 ──${NC}"; }

# ── Script-style helpers ───────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${CYAN}[STEP]${NC} $1"; }
