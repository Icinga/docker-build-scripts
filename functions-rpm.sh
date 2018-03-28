#!/bin/bash

detect_project() {
  specs=($(ls *.spec))

  if [ "${#specs[@]}" -eq 0 ]; then
    echo "No Spec file found!" >&2
    exit 1
  elif [ "${#specs[@]}" -gt 1 ]; then
    echo "More than one spec file found!" >&2
    exit 1
  else
    echo "$(basename "${specs[0]}" .spec)"
  fi
}

detect_os() {
  os=$(awk -F"=" '/^ID=/ {print $2}' /etc/os-release | sed -e 's/^"//' -e 's/"$//')

  if [ -n "$os" ]; then
    echo "$os"
  else
    echo "Could not detect os (ID) from /etc/os-release" >&2
    exit 1
  fi
}

detect_dist() {
  # TODO: verify for SUSE
  dist=$(awk -F= '/^VERSION_ID=/ {print $2}' /etc/os-release | sed -e 's/^"//' -e 's/"$//')

  if [ -n "$dist" ]; then
    echo "$dist"
  else
    echo "Could not detect dist (VERSION_ID) from /etc/os-release" >&2
    exit 1
  fi
}

detect_arch() {
  # TODO: verify for SUSE
  arches=($(rpm -qa "*-release" --qf "%{arch}\n" | sort -u | grep -v noarch))

  if [ "${#arches[@]}" -eq 0 ]; then
    echo "No basearch found while looking for *-release packages!" >&2
    exit 1
  elif [ "${#arches[@]}" -gt 1 ]; then
    echo "More than one base arch found with *-release packages!" >&2
    exit 1
  else
    echo "${arches[0]}"
  fi
}

print_build_env() {
  echo "[ Icinga Build Environment ]"
  (set -o posix; set) | grep -E ^ICINGA
}

require_var() {
  err=0
  for var in "$@"; do
    if [ -z "${!var}" ]; then
      echo "Variable $var is not set!" >&2
      err+=1
    fi
  done
  [ "$err" -eq 0 ] || exit 1
  echo
}

get_rpmbuild() {
    local RPMBUILD dist setarch

    dist=`rpm -E '%{?dist}' | sed 's/\(\.centos\)\?$/.icinga/'`
    setarch=''
    # TODO: target_arch
    if [ -n "$target_arch" ]; then
      setarch="setarch ${target_arch}"
    fi
    RPMBUILD=(
        ${setarch} \
        /usr/bin/rpmbuild \
        --define "vendor Icinga.com" \
        --define "dist $dist" \
        --define "_topdir ${WORKDIR}/rpmbuild" \
        "$@"
    )
    declare -p RPMBUILD
}

rpmbuild() {
    local RPMBUILD
    eval "$(get_rpmbuild "$@")"
    "${RPMBUILD[@]}"
}

find_compilers() {
  local location=${1:-/usr/bin}
  cd "$location"
  ls {cc,cpp,[gc]++,gcc}{,-*} 2>/dev/null || true
}

# repair/prepare ccache (needed on some distros like CentOS 5 + 6, SUSE, OpenSUSE)
preconfigure_ccache() {
  CCACHE_LINKS=`rpm -E %_libdir`/ccache
  compilers=($(find_compilers))
  if [ -e /opt/rh/devtoolset-2/enable ]; then
    compilers+=($(find_compilers /opt/rh/devtoolset-2/root/usr/bin))
  fi

  sudo sh -ex <<CCACHEREPAIR
    test -d ${CCACHE_LINKS} || mkdir ${CCACHE_LINKS}
    cd ${CCACHE_LINKS}
    echo 'Preparing/Repairing ccache symlinks...'
    for comp in ${compilers[@]}; do
      [ ! -e \${comp} ] || continue
      ln -svf /usr/bin/ccache \${comp}
    done
CCACHEREPAIR

  if [ -e /opt/rh/devtoolset-2/enable ]; then
    echo "Patching devtoolset-2 to use ccache..."
    # This is the only good way to re-add ccache to top of PATH
    # scl enable (inside icinga2.spec) will set its own path first
    sudo sh -ex <<SUDOSCRIPT
      echo 'PATH="${CCACHE_LINKS}:\${PATH}" to /opt/rh/devtoolset-2/enable'
      echo 'PATH="${CCACHE_LINKS}:\${PATH}"' >> /opt/rh/devtoolset-2/enable
SUDOSCRIPT
  else
    # Enable ccache as a default wrapper for compilers
    PATH="${CCACHE_LINKS}:${PATH}"
  fi
}

: ${ICINGA_BUILD_PROJECT:=`detect_project`}
: ${ICINGA_BUILD_OS:=`detect_os`}
: ${ICINGA_BUILD_DIST:=`detect_dist`}
: ${ICINGA_BUILD_ARCH:=`detect_arch`}
: ${ICINGA_BUILD_TYPE:="release"}
: ${ICINGA_BUILD_UPSTREAM_BRANCH:="master"}
: ${ICINGA_BUILD_IGNORE_LINT:=1}

print_build_env

require_var ICINGA_BUILD_PROJECT ICINGA_BUILD_OS ICINGA_BUILD_DIST ICINGA_BUILD_ARCH ICINGA_BUILD_TYPE

export LANG=C
WORKDIR=`pwd`
BUILDDIR='rpmbuild'

# vi: ts=2 sw=2 expandtab
