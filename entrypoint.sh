#!/bin/sh
# ============================================================
# entrypoint.sh - Production entrypoint with signal handling
# ============================================================

set -e

echo "=========================================="
echo "Starting DevOps Portfolio Container"
echo "=========================================="

# Run nginx in foreground with exec (proper signal handling)
exec nginx -g "daemon off;"
