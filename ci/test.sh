#!/bin/sh

set -ex

SCRIPT=$0
SCRIPT_DIR=$(cd $(dirname "$SCRIPT") && pwd)
SRC_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
RABBIT_DIR=$(cd "$SRC_DIR/../rabbit" && pwd)
DEPS_DIR=$(cd "$SRC_DIR/.." && pwd)

case $(uname -s) in
FreeBSD) MAKE=gmake ;;
*)       MAKE=make ;;
esac

(
  cd "$RABBIT_DIR"
  $MAKE dep_ranch="cp /ranch" DEPS_DIR="$DEPS_DIR" run-broker PLUGINS="rabbitmq_management rabbitmq_federation" &
)

(
  cd "$SRC_DIR"
  MIX_ENV=test mix deps.get
  MIX_ENV=test mix deps.compile
  MIX_ENV=test mix test
)
