#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-
#
# Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
#

"""Find source files from an Mach-O executable that are newer than the executable itself

"""

import sys
import os
import optparse
import re
import subprocess

REBUILD_CODE_FILENAME = "RLORebuildCode/RLORebuildCode.m"


re_rlo_starttime = re.compile("""RLOBundleUpdater load: (\d+\.\d+)""", re.MULTILINE)
re_rlo_nm_segment = re.compile("""^(?:00000000){1,2} - 00 0000\s+(SO|SOL|OSO) (.*)""", re.MULTILINE)

def last_program_start():
    latest_timestamp = None
    with open('/var/log/system.log', 'rb') as fp:
        data = fp.read()
        for m in re_rlo_starttime.finditer(data):
            timestamp = m.groups(1)[0]
            try:
                latest_timestamp = float(timestamp)
            except ValueError:
                continue
    return latest_timestamp

def cleaned_sonames(sonames):
    """Return all filenames where a filename exists in a directory.

    """
    directories = set()
    files = set()
    for name in sonames:
        if name.endswith('/'):
            directories.add(os.path.abspath(name))
        else:
            files.add(name)

    fullset = set()
    for d in directories:
        try:
            commonfiles = files.intersection(os.listdir(d))
            for f in commonfiles:
                fullset.add(os.path.join(d, f))
        except OSError:
            pass

    return fullset

def find_newerfiles(filename, projectdir):
    commandAndArgs = '/usr/bin/nm -aU %s' % (filename,)
    proc = subprocess.Popen(commandAndArgs, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    # latest_appstart is probably no longer needed.
    # When a source file has changed and was replaced, it is not necessary
    # to include the same source file again in the bundle when another file changes as well.
    latest_appstart = None

    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        print >>sys.stderr, stderr
        sys.exit(1)

    exetime = os.path.getmtime(filename)
    sourcenames = set()
    sonames = set()
    for m in re_rlo_nm_segment.finditer(stdout):
        segtype, sourcename = m.groups(1)
        if segtype == 'SOL':
            sourcename = os.path.abspath(sourcename)
            sourcenames.add(sourcename)
        elif segtype in ['SO', 'OSO']:
            sonames.add(sourcename)
    sourcenames.update(cleaned_sonames(sonames))
    sourcenames = sorted(list(sourcenames))

    importlines = []
    cppimportlines = []
    importlines.append("#ifdef RLO_ENABLED")
    cppimportlines.append("#ifdef RLO_ENABLED")
    rcname = rebuildcodefilename(projectdir)
    # Does a RLORebuildCode.mm exist beside RLORebuildCode.m ?
    if rcname:
        rcname_mm = rcname + 'm'
    else:
        rcname_mm = None
    cppfileexists = projectdir and rcname and os.path.exists(rcname_mm)
    cppexts = ".C .cc .cpp .CPP .c++ .cp .cxx .mm".split()
    cexts = ".c .m".split()
    for sourcename in sourcenames:
        ext = os.path.splitext(sourcename)[1]
        if ext not in cexts and ext not in cppexts:
            continue
        try:
            sourcetime = os.path.getmtime(sourcename)
        except OSError:
            continue
        if sourcetime > exetime or (latest_appstart is not None and sourcetime > latest_appstart):
            if cppfileexists and ext in cppexts:
                cppimportlines.append('#import "%s"' % sourcename)
            elif ext in cexts:
                importlines.append('#import "%s"' % sourcename)
    importlines.append("#endif")
    cppimportlines.append("#endif")
    importtext = "\n".join(importlines) + "\n"
    cppimporttext = "\n".join(cppimportlines) + "\n"

    if projectdir and rcname:
        overwrite_text(rcname, importtext)
        if cppfileexists:
            overwrite_text(rcname_mm, cppimporttext)

def overwrite_text(filename, text):
    olddata = None
    try:
        with open(filename, 'rb') as fp:
            olddata = fp.read()
    except IOError:
        pass
    if olddata != text:
        with open(filename, 'wb') as fp:
            fp.write(text)
            return True
    else:
        # Do not overwrite the data with the same content.
        # This preserves the timestamp and reduces build time.
        return True
    return False

def find_project():
    commandAndArgs = """osascript -e 'tell application "Xcode" to (path of document 1)'"""
    proc = subprocess.Popen(commandAndArgs, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        print >>sys.stderr, stderr
        sys.exit(1)

    projectdir = stdout.strip()
    projectdir = cleaned_projectdir(projectdir)
    return projectdir

def cleaned_projectdir(projectdir):
    if projectdir and projectdir.endswith('.xcworkspace'):
        projectdir = os.path.dirname(projectdir)
    if projectdir and projectdir.endswith('.xcodeproj'):
        projectdir = os.path.dirname(projectdir)
    return projectdir

def rebuildcodefilename(projectdir):
    if projectdir:
        rcname = os.path.join(projectdir, REBUILD_CODE_FILENAME)
        if not os.path.exists(rcname):
            rcname = None
    else:
        rcname = None
    return rcname

def main(argv, options, p):
    if options.projectdir:
        options.projectdir = cleaned_projectdir(options.projectdir)

    find_newerfiles(options.filename, projectdir=options.projectdir)

def _main(argv):
    p = optparse.OptionParser("usage: %prog [options] file ...")
    p.add_option("-p", "--projectdir", action="store", type="string", dest="projectdir")
    p.add_option("-f", "--filename", action="store", type="string", dest="filename")
    options, argv = p.parse_args(argv)

    main(argv, options, p)

if __name__ == '__main__':
    _main(sys.argv)
