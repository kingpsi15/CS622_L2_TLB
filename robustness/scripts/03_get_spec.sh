#!/bin/bash
# Download the Drive archive and install SPEC in this lane's /tmp workspace.
# The full-system SPEC runner exposes that install to the guest with a data disk.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/env.sh"
D=$W/spec-dl
mkdir -p "$D"
export PATH="$HOME/.local/bin:/usr/sbin:/usr/bin:/bin"
FILEID=1aUvAcJW-gwFFgprrqoEHkgKDIxWJOHX1
export SPECTAR=$D/spec2017.tar.xz

if [ -x "$SPEC/bin/runcpu" ]; then
    log "SPEC already installed at $SPEC"
    exit 0
fi

if ! xz -t "$SPECTAR" >/dev/null 2>&1; then
    rm -f "$W/stamps/spec_download"
fi
rm -f "$W/stamps/spec_install"

dl() {
    cd "$D"
    if ! command -v gdown >/dev/null 2>&1; then
        /usr/bin/python3 -m pip install --user -q gdown
    fi
    command -v gdown >/dev/null 2>&1 || {
        echo "gdown is unavailable; cannot download the SPEC archive" >&2
        return 1
    }
    for i in $(seq 1 40); do
        xz -t "$SPECTAR" 2>/dev/null && return 0
        gdown --continue "$FILEID" -O "$SPECTAR" || { echo "retry $i"; sleep 60; }
    done
    ls -l "$SPECTAR"
    xz -t "$SPECTAR"
}
stage spec_download dl || exit 1
eval "$(sed -n '/^spec_install()/,/^}/p' "$SCRIPT_DIR/00_setup.sh")"
stage spec_install spec_install || exit 1
[ -x "$SPEC/bin/runcpu" ] || { echo "SPEC installation did not create $SPEC/bin/runcpu" >&2; exit 1; }
log "SPEC: archive=$SPECTAR bytes=$(stat -c %s "$SPECTAR"); installed=$SPEC"
