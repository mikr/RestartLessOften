//
// RLODefinitions.h
//
// Copyright (c) 2013 Michael Krause ( http://krause-software.com/ )
//

#ifndef RLODefinitions_h
#define RLODefinitions_h

#ifdef RLO_ENABLED

#import "RLOUtils.h"
#import "RLOBundleUpdater.h"

#else

#define RLO_WATCH_CODE_UPDATES
#define RLOaddObserver(observer, theSelector)
#define RLOremoveObserver(observer)
#define RLONotificationContainsClassname(aNotification, classnames) NO
#define RLONotificationHasKeyPress(aNotification, keycombo) NO
#define RLONotificationHasKeyCombo(aNotification, keycombo) NO
#define RLONotificationHasKeyUpCombo(aNotification, keycombo) NO
#define RLONotificationKeyStatus(aNotification, keycombo) 0

#define RLO_DOWNLOAD_DATA(name) nil
#define RLO_DOWNLOAD_UIIMAGE(name) nil
#define RLO_START_CONF_LOADER
#define RLO_INIT_CONFIGURATION(path, url)
#define RLO_LOAD_CONFIGURATION(x)
#define RLO_CHANGED_FILE(notification) nil
#define RLO_LOAD_OBJECT(name) nil
#define RLO_SAVE_OBJECT(obj, objname)

#define RLOGetInt(varname, default_value) (default_value)
#define RLOSetInt(varname, v)
#define RLOGetFloat(varname, default_value) (default_value)
#define RLOSetFloat(varname, v)
#define RLOGetObject(varname) nil
#define RLOGetObjectWithDefault(varname, default_value) (default_value)
#define RLOSetObject(varname, v)
#define RLOGetFilecontent(filename) nil
#define RLODeleteVar(varname)
#define RLOVarChanged(varnames) NO
#define RLOAddResponseHandler(handler)

#define RLOLogUIImage(img, ...)
#define RLOLogCGImage(img, ...)
#define RLOLogContext(context, ...)
#define RLOZoomFit(s) 1.0
#define RLOZoomFill(s) 1.0

#define RLOUploadData(data, filename_arg)
#define RLOUploadImage(image)
#define RLOUploadContext(context)
#if TARGET_OS_IPHONE
#define RLOUploadUIImage(image)
#else
#define RLOUploadNSImage(image)
#endif

#endif

#endif
