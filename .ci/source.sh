#!/bin/bash -ex

GITDATE="`git show -s --date=short --format='%ad' | sed 's/-//g'`"
git remote add upstream https://github.com/AzaharPlus/AzaharPlus.git
git fetch upstream --no-recurse-submodules
GITREV=$(git rev-parse --short=7 upstream/AzaharPlus)
GITCOUNT=$(git rev-list --count upstream/AzaharPlus)
REV_NAME="azaharplus-unified-source-${GITDATE}-${GITCOUNT}-${GITREV}"

if [ "$GITHUB_REF_TYPE" = "tag" ]; then
    REV_NAME="azahar-unified-source-$GITHUB_REF_NAME"
fi

COMPAT_LIST='dist/compatibility_list/compatibility_list.json'

mkdir artifacts

pip3 install git-archive-all
touch "${COMPAT_LIST}"
git describe --abbrev=0 --always HEAD > GIT-COMMIT
git describe --tags HEAD > GIT-TAG || echo 'unknown' > GIT-TAG
git archive-all --include "${COMPAT_LIST}" --include GIT-COMMIT --include GIT-TAG --force-submodules artifacts/"${REV_NAME}.tar"

cd artifacts/
xz -T0 -9 "${REV_NAME}.tar"
sha256sum "${REV_NAME}.tar.xz" > "${REV_NAME}.tar.xz.sha256sum"
cd ..
