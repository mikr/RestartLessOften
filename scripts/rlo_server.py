#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-
#
# Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
#

"""Server for the configuration of tweakables during run-time.

The parameter filename in a request is examined for special cases.
_cachedfile_
    If filename begins with '_cachedfile_' it is only uploaded to the
    temporary in-memory cache. Likewise a file beginning with '_cachedfile_' is
    only downloaded from the cache and not from the usual directories from which files are served.

_cachedfile10_
    Same as _cachedfile_ but this one may be deleted from the cache after 10 minutes.
"""

import wsgiref.simple_server
import wsgiref.validate
from SocketServer import ThreadingMixIn
import urlparse
import os.path
import sys
import mimetypes
import time
import optparse
import tempfile
import subprocess
import plistlib
import urllib
import urllib2
import cStringIO
import gzip
import errno
import threading
import json
import decimal
import socket
import struct
import glob
import re
import math

try:
    from collections import Mapping
except ImportError:
    Mapping = dict

from pprint import pprint

try:
    import biplist
    have_biplist = True
    BinaryData = biplist.Data
except ImportError:
    have_biplist = False
    BinaryData = plistlib.Data

try:
    import OSC
    have_OSC = True
except ImportError:
    have_OSC = False


RLO_LISTENER_PORT = 8080
OSC_LISTENER_PORT = 8000
SAVE_DIRECTORY = os.path.expanduser('~/Downloads')
TESTCONF_NAME = "rloconfig.plist"
KEEP_ALIVE_INTERVAL = 30
TESTCONF_MODIFICATION_CHECK_INTERVAL = 0.1

SHORTLIVED_CACHE_SECONDS = 600

re_mappingfunc = re.compile("(lin|log|exp)?\[(.*),(.*)\]")

# If a request does not indicate to which project he belongs, we assume it belongs to
# the same project of the last request.
last_rloconf = None
log_http_requests = True
log_unmapped_osc_events = True
# Parameters that were modified via OSC or /update requests are normally reset after a client restarts or the configuration file changes.
persistent_updates = False
delete_screenshots = False
watch_files = []
watch_xibfiles = []
ignore_files = []

request_nr = 0

client_list = {}
updated_variables = {}
updated_variables_changed = False
updated_bundles = set()
mappings = {}
events = {}
rlodicts = {}
recent_configurations = set()
client_starttimes = set()
rloevents = {}

def rlodict_for_rloconf(rloconf):
    rlodict = rlodicts.get(rloconf)
    if rlodict is None:
        rlodict = rloconfigAsDict(rloconf)
        rlodicts[rloconf] = rlodict
    return rlodict

def clear_rlodict(rloconf):
    try:
        del rlodicts[rloconf]
    except KeyError: pass

def document_directories(rloconf):
    rlodict = rlodict_for_rloconf(rloconf)
    try:
        return rlodict['rlo']['testdata_directories']
    except KeyError: pass
    try:
        return [ rlodict['rlo']['testdata_directory'] ]
    except KeyError: pass
    return []

def abspath_for_docdir(docdir, rloconf):
    if isinstance(docdir, basestring):
        try:
            if not docdir.startswith('/'):
                docdir = os.path.join(os.path.dirname(rloconf), docdir)
            docdir = os.path.abspath(docdir)
            if os.path.isdir(docdir):
                return docdir
        except Exception, e:
            print e
    return None

def absdocdirs(rloconf):
    results = []
    for d in document_directories(rloconf):
        docdir = abspath_for_docdir(d, rloconf)
        if docdir:
            results.append(docdir)
    return results

def find_files(rloconf, globpattern):
    # We do not allow traversing into parent directories using ../.. or similar.
    basename = os.path.basename(globpattern)
    results = []
    for docdir in absdocdirs(rloconf):
        files = glob.glob(os.path.join(docdir, globpattern))
        for path in files:
            if os.path.isfile(path):
                results.append(path)
    return results

def find_file(rloconf, filename):
    # We do not allow traversing into parent directories using ../.. or similar.
    basename = os.path.basename(filename)
    for docdir in absdocdirs(rloconf):
        path = os.path.join(docdir, basename)
        if os.path.isfile(path):
            return path
    return None

def nibdata_for_xibfile(rloconf, filename):
    _, tmpnibfile = tempfile.mkstemp()
    commandAndArgs = 'ibtool --compile %s %s' % (tmpnibfile, find_file(rloconf, filename))
    proc = subprocess.Popen(commandAndArgs, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    fp = open(tmpnibfile, 'rb')
    data = fp.read()
    fp.close()
    os.remove(tmpnibfile)
    return data

#=======================================================================
# From http://stackoverflow.com/questions/7204805/python-dictionaries-of-dictionaries-merge/8795331#8795331
#
def merge_dicts(*dicts):
    """
    Return a new dictionary that is the result of merging the arguments together.
    In case of conflicts, later arguments take precedence over earlier arguments.
    """
    updated = {}
    # grab all keys
    keys = set()
    for d in dicts:
        keys = keys.union(set(d))

    for key in keys:
        values = [d[key] for d in dicts if key in d]
        # which ones are mapping types? (aka dict)
        maps = [value for value in values if isinstance(value, Mapping)]
        if maps:
            # if we have any mapping types, call recursively to merge them
            updated[key] = merge_dicts(*maps)
        else:
            # otherwise, just grab the last value we have, since later arguments
            # take precedence over earlier arguments
            updated[key] = values[-1]
    return updated

#=======================================================================

def tcmodule(rloconf, files_to_watch=None):
    sys.path.insert(0, os.path.dirname(rloconf))
    try:
        import rloconfig
        reload(rloconfig)
    except Exception, e:
        print "Error parsing %s: %r" % (rloconf, e)
        try:
            os.system('growlnotify -a Xcode.app -n rlo_server.py -m "import error"')
        except: pass
        try:
            os.system('say "import error"')
        except: pass
    del sys.path[0]

    return rloconfig

def rloconfigAsXML(rloconf):
    root = rloconfigAsDict(rloconf)
    return plistlib.writePlistToString(root)

def rloconfigAsDict(rloconf):
    global log_http_requests
    global log_unmapped_osc_events
    global persistent_updates
    global delete_screenshots
    global watch_files
    global watch_xibfiles
    global ignore_files

    overrides = updated_variables.get(rloconf, None) or None
    root = tcmodule(rloconf).rloconfiguration()
    if overrides is not None:
        root = merge_dicts(root, overrides)

    # Extract some variables from the rloconfiguration for the RLO server
    try:
        log_http_requests = root['rlo']['log_http_requests']
    except KeyError: pass
    try:
        persistent_updates = root['rlo']['persistent_updates']
    except KeyError: pass
    try:
        delete_screenshots = root['rlo']['delete_screenshots']
    except KeyError: pass
    try:
        mappings[rloconf] = root['osc']['mapping']
    except KeyError: pass
    try:
        log_unmapped_osc_events = root['osc']['log_unmapped_events']
    except KeyError: pass
    try:
        watch_files = root['watch_files']
    except KeyError: pass
    try:
        watch_xibfiles = root['watch_xibfiles']
    except KeyError: pass
    try:
        ignore_files = root['ignore_files']
    except KeyError: pass

    return root

def data_from_file(rloconf, filename):
    data = None
    mimetype, encoding = mimetypes.guess_type(filename)
    if filename in watch_xibfiles:
        # Serve compiled xib
        data = nibdata_for_xibfile(rloconf, filename)
    else:
        if is_cache_operation(filename):
            data = get_file_from_cache(filename)
        else:
            path = find_file(rloconf, filename)
            if path is not None:
                try:
                    fp = open(path, 'rb')
                    data = fp.read()
                    fp.close()
                except IOError:
                    pass
    return data, mimetype, encoding

#=======================================================================

def qenv(env):
    qparams = urlparse.parse_qs(env)
    def q(paramname):
        if paramname in qparams:
            return qparams[paramname][0]
        return None
    return q

def rloconf_valid(rloconf):
    return rloconf and (os.path.basename(rloconf) == 'rloconfig.py') and os.path.isfile(rloconf)

def file_changed(client_starttime, watchfiles):
    changed_file = None
    for ff in watchfiles:
        f, absname = ff
        try:
            if absname is not None:
                mtime = os.path.getmtime(absname)
                oldmtime = client_list.get(client_starttime)
                if not oldmtime or (mtime > oldmtime):
                    client_list[client_starttime] = mtime
                    changed_file = f
                    break
        except OSError:
            # File does probably not exist
            pass
    return changed_file

def data_for_updated_bundles(rloconf):
    data = None
    mimetype = None
    filename = None
    extra_headers = []
    if updated_bundles:
        for bundle in updated_bundles:
            projid, bundlelocation, rlobuildstart, announce_time = bundle
            if projid == rloconf:
                data = serialize_bundle(bundlelocation)
                mimetype = 'application/x-bundle'
                filename = os.path.basename(bundlelocation)
                if rlobuildstart is not None:
                    extra_headers.append(('RLO-Buildstart', rlobuildstart))
                    extra_headers.append(('RLO-Announcetime', repr(announce_time)))
                    extra_headers.append(('RLO-Responsetime', repr(time.time())))
                break

        if data is not None:
            try:
                updated_bundles.remove(bundle)
            except KeyError: pass
    return data, mimetype, filename, extra_headers

def handle_cleanup(client_starttime):
    if client_starttime is not None and delete_screenshots:
        if not client_starttime in client_starttimes:
            client_starttimes.add(client_starttime)
            screenshots = glob.glob("%s/screenshot_*.png" % SAVE_DIRECTORY)
            for filename in screenshots:
                os.remove(filename)

def wait_for_change(rloconf, filename, q):
    """Returns data, mimetype, changed_file, extra_headers
    """
    global updated_variables_changed

    request_begin = time.time()
    blocking = q('blocking')
    client_starttime = q('starttime')

    handle_cleanup(client_starttime)

    all_files_to_watch = watch_files + watch_xibfiles
    watchfiles = []
    ignore = set()
    for f in ignore_files:
        for fn in find_files(rloconf, f):
            ignore.add(fn)
    for f in all_files_to_watch:
        for fn in find_files(rloconf, f):
            if fn not in ignore:
                watchfiles.append((os.path.basename(fn), fn))
    watchfiles.insert(0, (TESTCONF_NAME, rloconf))

    while blocking:
        evqueue = rloevents.get(rloconf)
        if evqueue:
            return None, None, filename, [], "rloevent"

        changed_file = file_changed(client_starttime, watchfiles)
        if changed_file:
            return None, None, changed_file, [], None

        if updated_variables_changed:
            updated_variables_changed = False
            return None, None, None, [], None

        data, mimetype, bundlefilename, extra_headers = data_for_updated_bundles(rloconf)
        if data is not None:
            return data, mimetype, bundlefilename, extra_headers, None

        if time.time() - request_begin >= KEEP_ALIVE_INTERVAL:
            return "disconnect\n", None, None, [], None

        event = events.get(rloconf)
        if event is None:
            event = threading.Event()
            events[rloconf] = event
        event.wait(TESTCONF_MODIFICATION_CHECK_INTERVAL)
        event.clear()

    return None, None, filename, [], None

def send_rloevent_response(rloconf, environ, start_response):
    evqueue = rloevents.get(rloconf)
    if evqueue:
        del rloevents[rloconf]

    q = qenv(environ['QUERY_STRING'])
    use_xml = q('xml')

    data = ''
    params = { 'events': tuple(evqueue) }
    if not use_xml and have_biplist:
        data = biplist.writePlistToString(params, binary=True)
    else:
        data = plistlib.writePlistToString(params)

    response_headers = [('RLOResponseType', 'RLOEvent'),
                        ('Content-type', 'text/html'),
                        ('Content-Length', str(len(data)))
                        ]
    start_response("200 OK", response_headers)
    return [data]

def send_file(environ, start_response, filename):
    global last_rloconf
    global updated_variables_changed

    q = qenv(environ['QUERY_STRING'])
    rloconf = q('rloconf')
    if not rloconf_valid(rloconf):
        start_response("404 NOT FOUND", [('Content-type', 'text/plain')])
        return ['Invalid rloconf parameter']
    last_rloconf = rloconf

    if not is_cache_operation(filename) and find_file(rloconf, filename) is None and filename != TESTCONF_NAME:
        start_response("404 NOT FOUND", [('Content-type', 'text/plain')])
        return ['What are you looking for?']
    clear_rlodict(rloconf)
    recent_configurations.add(rloconf)

    extra_headers = []
    if filename == TESTCONF_NAME:
        use_xml = q('xml')
        data, mimetype, changed_file, extra_headers, changetype = wait_for_change(rloconf, filename, q)
        if changetype == "rloevent":
            return send_rloevent_response(rloconf, environ, start_response)

        if changed_file is not None:
            if data is not None:
                # A new bundle is ready
                filename = changed_file
            else:
                if changed_file == TESTCONF_NAME:
                    # rloconfig has changed, clear updated variables
                    if not persistent_updates:
                        try:
                            del updated_variables[rloconf]
                        except KeyError: pass
                        updated_variables_changed = False
                else:
                    filename = changed_file
                    data, mimetype, encoding = data_from_file(rloconf, filename)

        if data is None:
            root = rloconfigAsDict(rloconf)
            if not use_xml and have_biplist:
                data = biplist.writePlistToString(root, binary=True)
            else:
                data = plistlib.writePlistToString(root)
    else:
        data, mimetype, encoding = data_from_file(rloconf, filename)

    response_headers = [
                        ('Filename', urllib.quote(filename.encode('utf-8'))),
                        ('Content-type', mimetype or 'text/plain')
                        ]
    response_headers.extend(extra_headers)

    # Compress data as gzip if this is requested and it reduces the amount of traffic
    if data and 'gzip' in environ.get('HTTP_ACCEPT_ENCODING', ''):
        zbuf = cStringIO.StringIO()
        zfile = gzip.GzipFile(mode='wb', compresslevel=6, fileobj=zbuf)
        zfile.write(data)
        zfile.close()
        cdata = zbuf.getvalue()
        gzip_header = ('Content-Encoding', 'gzip')
        gzip_header_length = len(': '.join(gzip_header))
        if len(cdata) + gzip_header_length < len(data):
            data = cdata
            response_headers.append(gzip_header)

    if data is None:
        start_response("404 NOT FOUND", [('Content-type', 'text/plain')])
        return ['What are you looking for?']

    response_headers.append(('Content-Length', str(len(data))))
    start_response("200 OK", response_headers)
    return [data]


def upload_file(environ, start_response, filename):
    # Save file
    filename = filename.replace('/', '-')
    filename = filename.replace(':', '-')

    try:
        length = int(environ.get('CONTENT_LENGTH', '0'))
    except ValueError:
        length = 0

    # Zero length files are handled like any other file
    data = ''
    if length:
        data = environ['wsgi.input'].read(length)

    if is_cache_operation(filename):
        store_file_in_cache(filename, data)
    else:
        targetfilename = os.path.join(SAVE_DIRECTORY, filename)
        with open(targetfilename, 'wb') as fp:
            if length:
                fp.write(data)

    start_response("200 OK", [('Content-type', 'text/plain')])
    return ['']

#=======================================================================

_transientCache = {}
_transientCacheFilenames = []
def shortlived_file(filename):
    return filename.startswith('_cachedfile10_')

def is_cache_operation(filename):
    return filename.startswith('_cachedfile_') or shortlived_file(filename)

def delete_old_cachefiles():
    while len(_transientCacheFilenames) > 0:
        oldfilename, oldfiletime = _transientCacheFilenames[0]
        if time.time() - oldfiletime < SHORTLIVED_CACHE_SECONDS:
            # Only files cached within the last 10 minutes remain
            break
        try:
            del _transientCache[oldfilename]
        except KeyError: pass
        del _transientCacheFilenames[0]

def store_file_in_cache(filename, data):
    _transientCache[filename] = data
    delete_old_cachefiles()
    if shortlived_file(filename):
        # Soon...
        _transientCacheFilenames.append((filename, time.time()))

def get_file_from_cache(filename):
    return _transientCache.get(filename)

#=======================================================================

def find_rloconf(requestpath):
    for rloconf in rlodicts:
        try:
            # The project_identifier can be anything that is unique in the path to the rloconfig.py
            # For example 'myproject' or 'myproject/MyApp'
            project_identifier = requestpath.split('/')[-1]
            if project_identifier in rloconf:
                return rloconf
        except Exception, e:
            print >>sys.stderr, e
    return last_rloconf

def get_update_variable(rloconf, key):
    # Transform a keypath of a.b.c into an access to root[a][b][c]
    currentdict = rlodict_for_rloconf(rloconf)
    keyfragments = key.split('.')
    while len(keyfragments) > 1:
        subdict, keyfragments = keyfragments[0], keyfragments[1:]
        if not subdict in currentdict:
            return None
        currentdict = currentdict[subdict]
    key = keyfragments[0]
    return currentdict.get(key)

def evaluate_interval_limit(rloconf, value):
    try:
        return float(value)
    except ValueError, e:
        v = get_update_variable(rloconf, value)
        return v

def func_eval(funcname, x, a, b):
    try:
        if funcname == 'exp':
            return math.pow(2.0, x)
        elif funcname == 'log':
            return math.log(x, 2.0)
    except ValueError, e:
        print "Error in func_eval (funcname=%s, x=%s, a=%s, b=%s): %r" % (funcname, x, a, b, e)
    # Linear mapping, return identity
    return x

def mapvalue(rloconf, key, value):
    # The input value is expected to be in [0..1] as this is standard in OSC.
    keyparts = key.split('=>')
    keyparts = [x.strip() for x in keyparts]
    funcname = None
    dstart = None
    dend = None
    if len(keyparts) > 1:
        m = re_mappingfunc.match(keyparts[1])
        if m:
            funcname, dstart, dend = m.groups()
            funcname = funcname or 'lin'

    if dstart is not None and dend is not None:
        dstart = evaluate_interval_limit(rloconf, dstart)
        dend = evaluate_interval_limit(rloconf, dend)
        value = (dend - dstart) * value + dstart
        value = func_eval(funcname, value, dstart, dend)
    return keyparts[0], value

def set_update_variable(rloconf, key, value, vartype):
    if vartype == 'int':
        value = int(value)
    elif vartype == 'float':
        value = float(value)
    elif vartype == 'auto':
        try:
            v = decimal.Decimal(value)
            if v == v.to_integral_value():
                value = int(v)
            else:
                value = float(v)
        except:
            pass

    # Map value to an interval, linear, exponential (base2) or logarithmic (base2).
    key, value = mapvalue(rloconf, key, value)

    # Transform a keypath of a.b.c into an access to updated_variables[rloconf][a][b][c]
    if not rloconf in updated_variables:
        updated_variables[rloconf] = {}
    currentdict = updated_variables[rloconf]
    keyfragments = key.split('.')
    while len(keyfragments) > 1:
        subdict, keyfragments = keyfragments[0], keyfragments[1:]
        if not subdict in currentdict:
            currentdict[subdict] = {}
        currentdict = currentdict[subdict]
    key = keyfragments[0]
    currentdict[key] = value

def update_variable(environ, start_response):
    global updated_variables
    global updated_variables_changed

    paramstring = ''
    if environ.get('REQUEST_METHOD') == 'POST':
        length = int(environ.get('CONTENT_LENGTH') or '0')
        data = environ['wsgi.input'].read(length)
        paramstring = data
    elif environ.get('REQUEST_METHOD') == 'GET':
        paramstring = environ.get('QUERY_STRING')

    paramlist = urlparse.parse_qsl(paramstring, keep_blank_values=True)

    # If we would ever need to restore the WSGI environ uncomment these two lines:
    # body = cStringIO.StringIO(data)
    # environ['wsgi.input'] = body

    rloconf = find_rloconf(environ['PATH_INFO'])
    if not rloconf in updated_variables:
        updated_variables[rloconf] = {}

    parameters = []
    vartype = 'auto'
    vartypes = ['int', 'float', 'str', 'auto']  # TODO: add delete to delete a key from the dictionary, needs new dict deleted_variables
    for key, value in paramlist:
        if key in vartypes:
            vartype = key
        else:
            parameters.append((key, value, vartype))
            vartype = 'auto'

    for key, value, vartype in parameters:
        set_update_variable(rloconf, key, value, vartype)

    updated_variables_changed = len(parameters) > 0
    data = ''
    response_headers = [('Content-type', 'text/html'),
                        ('Content-Length', str(len(data)))
                        ]
    start_response("200 OK", response_headers)
    return [data]

def process_event(environ, start_response):
    length = int(environ.get('CONTENT_LENGTH', '0'))
    data = environ['wsgi.input'].read(length)
    paramlist = urlparse.parse_qsl(data, keep_blank_values=True)

    rloconf = find_rloconf(environ['PATH_INFO'])
    if not rloconf:
        rloconf = last_rloconf

    params = {}
    for k, v in paramlist:
        params[k.decode('utf-8')] = v.decode('utf-8')

    evqueue = rloevents.get(rloconf)
    if evqueue is None:
        evqueue = []
        rloevents[rloconf] = evqueue
    evqueue.append(params)
    set_event(rloconf)

    data = ''
    response_headers = [('Content-type', 'text/html'),
                        ('Content-Length', str(len(data)))
                        ]
    start_response("200 OK", response_headers)
    return [data]


def is_project_directory(dirname):
    if not dirname:
        return False
    d = os.path.join(dirname, 'scripts/rloconfig.py')
    return os.path.exists(d)

def find_rloconf_from_filename(filename):
    projdir = os.path.abspath(filename)
    rloconf = None
    while True:
        if is_project_directory(projdir):
            rloconf = os.path.basename(projdir)
            break
        if not projdir or projdir == '/':
            break
        projdir = os.path.dirname(projdir)
    return rloconf

def announce_bundle(environ, start_response):
    body = ''
    try:
        content_length = int(environ.get('CONTENT_LENGTH', '0'))
    except ValueError:
        content_length = 0
    if content_length:
        body = environ['wsgi.input'].read(content_length)

    q = qenv(body)
    srcroot = q('srcroot')
    rloconf = find_rloconf(srcroot)
    if not rloconf_valid(rloconf):
        start_response("404 NOT FOUND", [('Content-type', 'text/plain')])
        return ['Invalid rloconf parameter']
    clear_rlodict(rloconf)
    recent_configurations.add(rloconf)

    bundlelocation = q('bundlelocation')
    rlobuildstart = q('rlobuildstart')
    announce_time = time.time()
    updated_bundles.add((rloconf, bundlelocation, rlobuildstart, announce_time))
    # Wake up the blocking response for this project
    set_event(rloconf)
    start_response("200 OK", [('Content-type', 'text/plain')])
    return ['']

def take_screenshot(environ, start_response):
    qparams = urlparse.parse_qs(environ['QUERY_STRING'])
    filename = qparams.get('filename')
    if filename:
        filename = filename[0]
    print "Taking screenshot, filename=" + repr(filename)
    take_simulator_screenshot()
    start_response("200 OK", [('Content-type', 'text/plain')])
    return ['']

def take_simulator_screenshot():
    commandAndArgs = """osascript -e 'tell application "iPhone Simulator" to activate
    tell application "System Events"
	tell process "iOS Simulator"
		click menu item "Save Screen Shot" of menu "File" of menu bar 1
	end tell
    end tell'"""
    proc = subprocess.Popen(commandAndArgs, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate()
    if proc.returncode != 0:
        print >>sys.stderr, stderr
        sys.exit(1)

def set_event(rloconf):
    event = events.get(rloconf)
    if event is not None:
        event.set()

def osc_message(environ, start_response):
    try:
        content_length = int(environ.get('CONTENT_LENGTH', '0'))
    except ValueError:
        content_length = 0
    body = ''
    if content_length:
        body = environ['wsgi.input'].read(content_length)

    params = json.loads(body)
    handle_osc(params)
    # Wake up the blocking response for this project
    set_event(last_rloconf)
    start_response("200 OK", [('Content-type', 'text/plain')])
    return ['']

def handle_osc(params):
    global updated_variables
    global updated_variables_changed
    rloconf = last_rloconf
    mapping = mappings.get(rloconf)
    if mapping is None:
        return
    changed = False
    for m in mapping:
        mpath, mtargets = m[0], m[1:]
        if mpath == params.get('path'):
            for vartype, varvalue, target in zip(params.get('tags', []), params.get('args', []), mtargets):
                set_update_variable(rloconf, target, varvalue, 'auto')
                changed = True
    if changed:
        updated_variables_changed = True
    else:
        # No mapping found, log this message
        if log_unmapped_osc_events:
            # print a message that can be copied into the mappings section of the configuration file
            varnames = ", ".join(["'varname%d'" % x for x in xrange(1, len(params.get('tags')) + 1)])
            print "OSC mapping: [%r, %s]," % (params.get('path'), varnames)

def my_app(environ, start_response):
    qparams = urlparse.parse_qs(environ['QUERY_STRING'])

    # OSC messages are plenty, we do not print these
    if environ['PATH_INFO'] == '/osc':
        return osc_message(environ, start_response)

    #print "======================================================================="
    #pprint(qparams)
    filename = qparams.get('filename')
    if filename:
        filename = filename[0]

    if environ['PATH_INFO'] == '/milliseconds':
        start_response("200 OK", [('Content-type', 'text/plain')])
        return [repr(time.time())]

    if environ['PATH_INFO'] == '/download':
        return send_file(environ, start_response, filename)

    if environ['PATH_INFO'] == '/upload':
        return upload_file(environ, start_response, filename)

    if environ['PATH_INFO'].startswith('/update'):
        return update_variable(environ, start_response)

    if environ['PATH_INFO'].startswith('/event'):
        return process_event(environ, start_response)

    if environ['PATH_INFO'] == '/announcebundle':
        return announce_bundle(environ, start_response)

    if environ['PATH_INFO'] == '/takescreenshot':
        return take_screenshot(environ, start_response)

    path = environ['PATH_INFO']
    if path == '/':
        path = '/index.html'

    while path.startswith('/'):
        path = path[1:]
    if path == 'index.html':
        return generate_index(environ, start_response)

    response_headers = [
                        ('Content-type', 'text/plain'),
                        ('Content-Length', '0')
                       ]
    start_response("200 OK", response_headers)
    return ['']

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>rlo_server.py</title>
</head>
<body>
<ul>
 %(body)s
</ul>
</body>
</html>
"""

def generate_index(environ, start_response):
    links = '\n'.join([('''<li><a href="view?rloconf=%(rloconf)s">%(rloconf)s</a></li>''' % {'rloconf': p}) for p in recent_configurations])
    data = HTML_TEMPLATE % {'body': links}
    response_headers = [
                        ('Content-type', 'text/html'),
                        ('Content-Length', str(len(data)))
                       ]
    start_response("200 OK", response_headers)
    return [data]

# =======================================================================
#
# A bit of code to supress the annoying "[Errno 32] Broken pipe" error.
#

class EPipeSuppressingHandler(wsgiref.simple_server.ServerHandler):

    def write(self, data):
        try:
            wsgiref.simple_server.ServerHandler.write(self, data)
        except IOError, e:
            if e.errno in (errno.EPIPE, errno.ECONNRESET):
                # suppress annoying error: [Errno 32] Broken pipe
                pass
            else:
                raise e

class EPipeSuppressingRequestHandler(wsgiref.simple_server.WSGIRequestHandler):

    def handle(self):
        self.request_starttime = time.time()
        self.raw_requestline = self.rfile.readline()
        if not self.parse_request():        # An error code has been sent, just exit
            return

        handler = EPipeSuppressingHandler(
            self.rfile, self.wfile, self.get_stderr(), self.get_environ()
        )
        handler.request_handler = self      # backpointer for logging
        handler.run(self.server.get_app())

    def finish(self):
        try:
            wsgiref.simple_server.WSGIRequestHandler.finish(self)
        except IOError, e:
            if e.errno in (errno.EPIPE, errno.ECONNRESET):
                # suppress annoying error: [Errno 32] Broken pipe
                pass
            else:
                raise e

    def log_message(self, format, *args):
        if log_http_requests:
            wsgiref.simple_server.WSGIRequestHandler.log_message(self, format, *args)

    def address_string(self):
        """Resolving hostnames with a high logging rate results in pauses of around a second every few seconds.
           We log just the IP address instead of the fully qualified hostname.
           Comment out this method for full hostname logging.
        """
        host, port = self.client_address[:2]
        return host

    def log_date_time_string(self):
        """Return the current time formatted for logging."""
        global request_nr

        now = time.time()
        year, month, day, hh, mm, ss, x, y, z = time.localtime(now)
        millis = int(1000 * (now - int(now)))
        s = "%02d/%3s/%04d %02d:%02d:%02d.%03d %.3fms %d" % (
                day, self.monthname[month], year, hh, mm, ss, millis, time.time() - self.request_starttime, request_nr)

        request_nr += 1
        return s

class ThreadingWSGIServer(ThreadingMixIn, wsgiref.simple_server.WSGIServer):
    pass

def make_server(host, port, app, server_class=ThreadingWSGIServer, handler_class=EPipeSuppressingRequestHandler):
    return wsgiref.simple_server.make_server(host, port, app, server_class, handler_class)

#=======================================================================

class Watcher:
    """
    http://code.activestate.com/recipes/496735/

    This class solves two problems with multithreaded
    programs in Python, (1) a signal might be delivered
    to any thread (which is just a malfeature) and (2) if
    the thread that gets the signal is waiting, the signal
    is ignored (which is a bug).

    The watcher is a concurrent process (not thread) that
    waits for a signal and the process that contains the
    threads.  See Appendix A of The Little Book of Semaphores.
    http://greenteapress.com/semaphores/

    I have only tested this on Linux.  I would expect it to
    work on the Macintosh and not work on Windows.
    """

    def __init__(self):
        """ Creates a child thread, which returns.  The parent
            thread waits for a KeyboardInterrupt and then kills
            the child thread.
        """
        self.child = os.fork()
        if self.child == 0:
            return
        else:
            self.watch()

    def watch(self):
        try:
            os.wait()
        except KeyboardInterrupt:
            self.kill()
        sys.exit()

    def kill(self):
        try:
            import signal
            os.kill(self.child, signal.SIGKILL)
        except OSError:
            pass

#=======================================================================

last_osc_post_time = 0
last_osc_post_timer = None

def default_osc_callback(path, tags, args, source):
    global last_osc_post_timer

    params = {
            'path': path,
            'tags': tags,
            'args': args,
            'source': source
            }

    # Check if we run in the same process as the HTTP listener
    if True:
        handle_osc(params)
        # Wake up the blocking response for this project
        set_event(last_rloconf)
        return

    # If the HTTP and OSC server would run in different processes
    # we could forward this event to the HTTP server.

    minimum_time_interval = 0.03
    # Create post request with pickled data
    postdata = json.dumps(params)

    def post_osc_msg():
        global last_osc_post_time
        url = 'http://localhost:%s/osc' % RLO_LISTENER_PORT
        req = urllib2.Request(url, postdata)
        req.add_header("Content-type", "application/json")
        last_osc_post_time = time.time()
        page = urllib2.urlopen(req).read()

    if last_osc_post_timer:
        last_osc_post_timer.cancel()
    wait_time = max(0, last_osc_post_time + minimum_time_interval - time.time())
    last_osc_post_timer = threading.Timer(wait_time, post_osc_msg)
    last_osc_post_timer.start()

def startOSCServerInBackground():
    # Let the HTTP server start first
    time.sleep(1)
    oscserver = OSC.OSCServer(('', OSC_LISTENER_PORT))
    # Close the socket if the process exits
    l_onoff = 1
    l_linger = 0
    oscserver.socket.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', l_onoff, l_linger))
    oscserver.timeout = 5
    oscserver.addMsgHandler('default', default_osc_callback)
    oscserver.serve_forever()

def startOSCServer():
    if not have_OSC:
        print >>sys.stderr, "Note: pyOSC not available"
        return

    t = threading.Thread(target=startOSCServerInBackground)
    t.setDaemon(True) # don't hang on exit
    t.start()

#=======================================================================

def main(argv, options, p):
    if not options.plist:
        if not have_biplist:
            print >>sys.stderr, "Note: biplist module not available therefore plists can only transferred in XML format."

        use_reloader = options.reloader
        if use_reloader:
            try:
                from werkzeug.serving import run_simple
            except ImportError:
                print >>sys.stderr, "Warning: Cannot use auto-reloading because the werkzeug module is not available"
                use_reloader = False

        # We start Watcher before any server so all servers run in the same process for shared access to the globals.
        if not use_reloader:
            Watcher()

        if not use_reloader or os.environ.get('WERKZEUG_RUN_MAIN') == 'true':
            print "Starting OSCServer on UDP port %s" % OSC_LISTENER_PORT
            startOSCServer()

        print "Starting RLOserver on TCP port %s" % RLO_LISTENER_PORT
        if not use_reloader:
            serv = make_server('', RLO_LISTENER_PORT, wsgiref.validate.validator(my_app))
            serv.serve_forever()
        else:
            run_simple('', RLO_LISTENER_PORT, my_app, use_reloader=True)
    else:
        if not options.project:
            p.error("please specify the project")
        data = rloconfigAsXML(options.project)
        print data,

def encode_directory(rootpath):
    for root, dirs, files in os.walk(rootpath):
        items = [encode_directory(os.path.join(root, d)) for d in dirs]
        for filename in files:
            path = os.path.join(root, filename)
            with open(path, 'rb') as fp:
                data = fp.read()
                data = BinaryData(data)
            filedict = {
                '_name': filename,
                'type': 'file',
                'data': data,
                'permissions': os.stat(path).st_mode,
            }
            items.append(filedict)
        break

    return {
        '_name': os.path.basename(rootpath),
        'type': 'directory',
        'permissions': os.stat(rootpath).st_mode,
        'items': items
    }

def serialize_bundle(bundle_path):
    if have_biplist:
        data = biplist.writePlistToString(encode_directory(bundle_path), binary=True)
    else:
        data = plistlib.writePlistToString(encode_directory(bundle_path))
    return data

def _main(argv):
    sys.dont_write_bytecode = True

    p = optparse.OptionParser("usage: %prog [options]")
    p.add_option("--plist", action="store_true", dest="plist")
    p.add_option("-p", "--project", action="store", type="string", dest="project")
    p.add_option("-r", "--reloader", action="store_true", dest="reloader")

    options, argv = p.parse_args(argv)
    main(argv, options, p)

if __name__ == '__main__':
    _main(sys.argv)
