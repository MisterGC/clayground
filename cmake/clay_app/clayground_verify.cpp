// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Verifies that clayground_app_cfg.h is included when required

#include <clayground_app_cfg.h>

#ifdef CLAYPLUGIN_LINKING_STATIC
  #ifndef CLAYGROUND_APP_CFG_INCLUDED
    #error "Static linking (WASM/iOS/Android) requires: #include <clayground_app_cfg.h> in your main.cpp"
  #endif
#endif
