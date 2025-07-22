#!/usr/bin/env bash

# This script runs a benchmark on a locally started etcd server

set -euo pipefail

source ./scripts/test_lib.sh

COMMON_BENCHMARK_FLAGS="--report-perfdash"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <benchmark-name> [tester args...]"
  exit 1
fi

BENCHMARK_NAME="$1"
ARGS="${*:2}"

echo "Starting the etcd server..."
./bin/etcd --data-dir="/tmp/" > /tmp/etcd.log 2>&1 &
etcd_pid=$!
trap 'log_warning -e "Stopping etcd server - PID:$etcd_pid"; kill $etcd_pid 2>/dev/null' EXIT

# Wait until etcd becomes healthy
for retry in {1..10}; do
  if ./bin/etcdctl endpoint health --cluster> /dev/null 2>&1; then
    log_success -e "\\netcd is healthy"
    break
  fi
  log_warning -e "\\nWaiting for etcd to be healthy..."
  sleep 1
  if [[ $retry -eq 10 ]]; then
    log_error -e "\\nFailed to confirm etcd health after $retry attempts. Check /tmp/etcd.log for more information"
    exit 1
  fi
done

log_success -e "etcd process is running with pid $etcd_pid"

log_callout -e "\\nPerforming benchmark $BENCHMARK_NAME with arguments: $ARGS"
read -r -a TESTER_OPTIONS <<< "$ARGS"
log_callout "Running: benchmark $BENCHMARK_NAME ${TESTER_OPTIONS[*]} $COMMON_BENCHMARK_FLAGS"
benchmark "$BENCHMARK_NAME" "${TESTER_OPTIONS[@]}" $COMMON_BENCHMARK_FLAGS
log_callout "Completed: benchmark $BENCHMARK_NAME ${TESTER_OPTIONS[*]} $COMMON_BENCHMARK_FLAGS"
log_callout "Flush the db files related to the benchmark"
rm -rf /tmp/member/*
