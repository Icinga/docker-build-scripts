#!/bin/bash

detect_project() {
  dists=($(grep -E ^Source: */debian/control | awk '{print $2}' | sort -u))

  if [ "${#dists[@]}" -eq 0 ]; then
    echo "No Debian control files found!" >&2
    exit 1
  elif [ "${#dists[@]}" -gt 1 ]; then
    echo "More than one Source names found in Debian control files!" >&2
    exit 1
  else
    echo "${dists[0]}"
  fi
}

detect_os() {
  os=$(awk -F"=" '/^ID=/ {print $2}' /etc/os-release)

  if [ -n "$os" ]; then
    echo "$os"
  else
    echo "Could not detect os (ID) from /etc/os-release" >&2
    exit 1
  fi
}

detect_dist() {
  dist=$(awk -F"[)(]+" '/^VERSION=/ {print $2}' /etc/os-release)

  if [ -n "$dist" ]; then
    echo "$dist"
  else
    echo "Could not detect dist (VERSION name) from /etc/os-release" >&2
    exit 1
  fi
}

detect_arch() {
  arch=$(dpkg --print-architecture)

  if [ -n "$arch" ]; then
    echo "$arch"
  else
    echo "Could not detect arch from dpkg" >&2
    exit 1
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

: ${ICINGA_BUILD_PROJECT:=`detect_project`}
: ${ICINGA_BUILD_OS:=`detect_os`}
: ${ICINGA_BUILD_DIST:=`detect_dist`}
: ${ICINGA_BUILD_ARCH:=`detect_arch`}
: ${ICINGA_BUILD_DEB_FLAVOR:="$ICINGA_BUILD_DIST"}
: ${ICINGA_BUILD_TYPE:="release"}
: ${ICINGA_BUILD_UPSTREAM_BRANCH:="master"}

print_build_env

require_var ICINGA_BUILD_PROJECT ICINGA_BUILD_OS ICINGA_BUILD_DIST ICINGA_BUILD_ARCH ICINGA_BUILD_DEB_FLAVOR ICINGA_BUILD_TYPE

export LANG=C
WORKDIR=`pwd`
BUILDDIR='build'

# vi: ts=2 sw=2 expandtab
