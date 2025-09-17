#!/usr/bin/env bash
set -euo pipefail

OUTDIR=src/root/static/dist
mkdir -p $OUTDIR

# esbuild needs paths relative to the current directory
# The script will be run from the root of the project.
ESBUILD_CMD="esbuild --bundle --minify"

# CSS
$ESBUILD_CMD \
  src/root/static/fontawesome/css/all.css \
  src/root/static/bootstrap/css/bootstrap.min.css \
  src/root/static/css/hydra.css \
  src/root/static/css/rotated-th.css \
  src/root/static/css/tree.css \
  --outfile=$OUTDIR/app.bundle.css \
  --loader:.eot=file \
  --loader:.woff=file \
  --loader:.woff2=file \
  --loader:.ttf=file \
  --loader:.svg=file \
  --asset-names=[name] \
  --public-path=/static/dist

# JavaScript
$ESBUILD_CMD \
  src/root/static/js/jquery/jquery-3.4.1.min.js \
  src/root/static/js/jquery/jquery-ui-1.10.4.min.js \
  src/root/static/js/moment/moment-2.24.0.min.js \
  src/root/static/js/popper.min.js \
  src/root/static/bootstrap/js/bootstrap.min.js \
  src/root/static/js/bootbox.min.js \
  src/root/static/js/common.js \
  --outfile=$OUTDIR/app.bundle.js

echo "Frontend assets built successfully."

