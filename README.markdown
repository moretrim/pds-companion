The Victoria 2 Modder’s Companion
=================================

Build status:
[![travis-master][travis-master-image]](https://travis-ci.com/moretrim/pds-companion/branches)

[travis-master-image]: https://travis-ci.com/moretrim/pds-companion.svg?branch=master

A suite of static analysis tools for Victoria 2 modding.

Installation
------------

You can download from [master][], or obtain the [release][] of your choice. You can also install the following optional
dependency:

- [Terminal::ANSIColor] for coloured output

[master]: https://github.com/moretrim/pds-companion/archive/master.zip
[RELEASE]: https://github.com/moretrim/pds-companion/releases
[Terminal::ANSIColor]: https://github.com/tadzik/Terminal-ANSIColor

This is a traditional Raku module distribution and can be installed through the usual means, though it is not available
on <https://modules.raku.org>. If you’re not too sure, try the following after downloading:

```shell-session
$ unzip master.zip # or whichever release you got
$ zef --install ./pds-companion-master
```

Getting Started
---------------

The `vic2-companion` executable is able to coordinate static analysis of your Victoria 2 files, one mod at a time. In
general you should point it at the base of your mod files, and specify what you want to be checked. E.g. to perform
analysis of event and decision files:

```shell-session
$ vic2-companion --base=path/to/mod events decisions
```

(The base of your mod files is where everything is for a given mod, such as events, decisions, flag graphics. It’s the
same location that's pointed to by the `path` entry in the corresponding `.mod` file.)

You can specify any number of directories or individual files. If you want to check everything (but see the `--help`
regarding file extensions):

```shell-session
$ vic2-companion --base=path/to/mod .
```

Results are displayed on standard output. A successful exit code is returned unless a problem was encountered during
processing or unless some result was unexpected.

Without the `--base` parameter or if your mod files follow an unconventional structure, analysis can still be performed
but it will be mainly syntactical. See `vic2-companion --help` for detailed information regarding parameters and
features such as whitelists.

License
-------

Copyright © 2019–2021 moretrim. “2019–2021” and other similar notices indicate that all individual years in the range,
inclusive, are covered.

Available under the terms of the GNU General Public License version 3. See the accompanying
[`LICENSE.markdown`][license] file for more information.

[license]: ./LICENSE.markdown

Release history
---------------

### 0.2.0-dev (in development)

- introduced the `vic2-companion` executable

### 0.1.0-alpha

An alpha release. Not suitable for general consumption.
