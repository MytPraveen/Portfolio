#!/bin/sh
# ============================================================
# entrypoint.sh - Production entrypoint with signal handling
# ============================================================

set -e

echo "=========================================="
echo "Starting DevOps Portfolio Container"
echo "Version: ${VERSION:-unknown}"
echo "Build Date: ${BUILD_DATE:-unknown}"
echo "=========================================="

# Execute nginx in foreground with exec (proper signal handling)
exec nginx -g "daemon off;"