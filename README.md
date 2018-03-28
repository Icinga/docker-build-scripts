Scripts for package builds in Docker
====================================

This scripts slowly replace all embedded scripts in [Puppet module icinga_build](https://github.com/Icinga/puppet-icinga_build).

Please note:
* This is for an internal build environment
* Image names are not best practice

## Usage

```
cp icinga-build-docker ~/bin/

cd ~/devel/icinga/rpm-icinga2

ICINGA_BUILD_TYPE=release icinga-build-docker centos-7-x86_64
# or snapshot
icinga-build-docker centos-7-x86_64
```

In development mode (not using scripts inside a container):

```
PATH=~/devel/icinga/icinga-build-scripts:"$PATH"
ICINGA_DOCKER_PULL=0 ICINGA_SCRIPT_DEVEL=1 icinga-build-docker centos-7-x86_64
```

## License

Icinga, all tools and documentation are licensed under the terms of the GNU
General Public License Version 2, you will find a copy of this license in the
COPYING file included in the source package.
