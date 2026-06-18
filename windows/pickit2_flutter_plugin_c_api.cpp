#include "include/pickit2_flutter/pickit2_flutter_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "pickit2_flutter_plugin.h"

void Pickit2FlutterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  pickit2_flutter::Pickit2FlutterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
