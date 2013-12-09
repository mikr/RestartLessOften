#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""rloconfig.py for GLExample.

"""

import plistlib

def rloconfiguration():
    T = dict(
              rlo = dict(
                  log_http_requests = 1,
                  hostname_resolution = 0,
                  generate_urls = 4,  # 0: don't, 1: rlo://, 2: vemmi://, 3: http://hostname.local, 4: http://localhost
                  generate_urls_if_num_diffs_less_than = 10,
                  show_nondefault_vars = 1,   # 1: show diff once, 2: show diff every time
                  show_config_diffs = 1,
                  show_config_diffs_if_num_diffs_less_than = 10,
                  persistent_updates = 0,
                  serverfilecache = 1,
                  use_bundle_load = 0,
                  supress_warning = 0,
                  delete_screenshots = 1,
                  # Directories are either absolute or relative to this directory of this rloconfig.py file.
                  testdata_directories = [
                      "GLExample/Shaders"
                      ],
              ),

              # osc is for the mapping between OSC events (see e.g. http://hexler.net/software/touchosc )
              # and variables in the RLO dictionary.
              osc = dict(
                  log_unmapped_events = 1,
                  mapping = [
                  # ['/5/xy4', 'focuspoint_y', 'focuspoint_x'],
                  # ['/1/toggle13', 'sceneparts.scale_enabled'],
                  # ['/1/fader3', 'sceneparts.scale => exp[-4,4]'],
                  ]
              ),

              # The arrays watch_files, watch_xibfiles, and ignore_files are evaluated by rlo_server.py.
              # If files inside one of the rlo.testdata_directories matching watch_files
              # that don't appear in ignore_files, the file is sent the app which can react on the new content.
              watch_files = ['*.vsh', '*.fsh'],
              # watch_xibfiles = [],
              # ignore_files = [],

              # ---------------- Only app specific variables below this point ----

              backgroundcolor = "#A5A5A5FF",
              disable_glkitcube = 0,
              num_triangles = 36,
    )
    return T

def confAsPlist(overrides=None):
    T = rloconfiguration()
    if overrides is not None:
        T.update(overrides)
    return plistlib.writePlistToString(T)
