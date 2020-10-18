#!/usr/bin/env bash
set -Eeo pipefail

# Note: This works with the BSD version of sed (i.e. the one macOS ships with)
# To use the GNU verion, remove the '' after -i
sed -i '' 's/!this.popupUtilsService.inPopout(window)/false/' browser/src/popup/tabs.component.ts

pushd browser && npm run build

popd

rm -rf app/
cp -r browser/build/ app
cp browser/src/safari/safari/app/popup/index.html app/popup/index.html
touch app/.gitkeep
