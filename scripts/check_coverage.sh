#!/usr/bin/env bash
set -euo pipefail

# Default threshold is 15% (matching baseline; configurable via argument or MIN_COVERAGE env var)
MIN_COVERAGE="${1:-${MIN_COVERAGE:-15}}"

echo "=========================================="
echo "    Chainkey Test Coverage Verification   "
echo "=========================================="
echo "Enforcing minimum coverage threshold: ${MIN_COVERAGE}%"
echo ""

TOTAL_LF=0
TOTAL_LH=0

printf "%-35s %-12s %-12s %-10s\n" "Package" "Lines Found" "Lines Hit" "Coverage"
printf "%-35s %-12s %-12s %-10s\n" "-----------------------------------" "------------" "------------" "----------"

# Find all lcov.info in packages (excluding example)
COVERAGE_FILES=$(find packages -mindepth 2 -maxdepth 4 -name "lcov.info" | grep -v "/example/" | sort || true)

if [ -z "$COVERAGE_FILES" ]; then
  echo "Error: No coverage files found under packages/*/coverage/lcov.info"
  exit 1
fi

for cov in $COVERAGE_FILES; do
  pkg=$(echo "$cov" | awk -F'/' '{print $2}')
  
  LF=$(awk -F: '/LF:/ {lf+=$2} END {print lf+0}' "$cov")
  LH=$(awk -F: '/LH:/ {lh+=$2} END {print lh+0}' "$cov")
  
  TOTAL_LF=$((TOTAL_LF + LF))
  TOTAL_LH=$((TOTAL_LH + LH))
  
  if [ "$LF" -gt 0 ]; then
    PCT=$(awk "BEGIN {printf \"%.2f\", ($LH / $LF) * 100}")
  else
    PCT="0.00"
  fi
  
  printf "%-35s %-12s %-12s %-10s%%\n" "$pkg" "$LF" "$LH" "$PCT"
done

printf "%-35s %-12s %-12s %-10s\n" "-----------------------------------" "------------" "------------" "----------"

if [ "$TOTAL_LF" -gt 0 ]; then
  TOTAL_PCT=$(awk "BEGIN {printf \"%.2f\", ($TOTAL_LH / $TOTAL_LF) * 100}")
else
  TOTAL_PCT="0.00"
fi

printf "%-35s %-12s %-12s %-10s%%\n" "TOTAL" "$TOTAL_LF" "$TOTAL_LH" "$TOTAL_PCT"
echo "=========================================="

# Threshold check
CHECK=$(awk "BEGIN {print ($TOTAL_PCT >= $MIN_COVERAGE) ? 1 : 0}")

if [ "$CHECK" -eq 1 ]; then
  echo "Coverage check PASSED (${TOTAL_PCT}% >= ${MIN_COVERAGE}%)"
  exit 0
else
  echo "Coverage check FAILED: Total coverage (${TOTAL_PCT}%) is below required threshold (${MIN_COVERAGE}%)"
  exit 1
fi
