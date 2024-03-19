#!/usr/bin/env bash
set -eu -o pipefail

source .build_config

function prepare_repos {
  declare -a arr=("depot_tools" "src" ".cipd")
  for dname in "${arr[@]}"
  do
    if [[ -d "$dname" ]]
    then
      echo "Removing $dname"
      rm -rf "$dname"
    fi
  done

  ## Clone chromium repo
  git clone --depth 1 --no-tags git@github.com:chromium/chromium.git  src -b ${chromium_version} || return $?

  ## Fetch depot-tools
  depot_tools_commit=$(grep 'depot_tools.git' src/DEPS | cut -d\' -f8)
  mkdir -p depot_tools
  pushd depot_tools
  git init
  git remote add origin https://chromium.googlesource.com/chromium/tools/depot_tools.git
  git fetch --depth 1 --no-tags origin "${depot_tools_commit}" || return $?
  git reset --hard FETCH_HEAD
  popd
  
  export PATH="$(pwd -P)/depot_tools:$PATH"

  ## Sync files
  gclient.py sync --no-history --shallow --revision=${chromium_version} || return $?
}

# Run preparation
prepare_repos

# Apply patches
python3 utils/patches.py apply src src_patches

## Configure output folder
pushd src
output_folder="out/Default"
mkdir -p "${output_folder}"
cat ../build_flags.gn > "${output_folder}"/args.gn
gn gen "${output_folder}" --fail-on-unused-args
popd

## Build
pushd src
ninja -C out/Default chrome_public_apk
popd
