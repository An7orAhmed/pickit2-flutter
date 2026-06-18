#ifndef FLUTTER_PLUGIN_PICKIT2_FLUTTER_PLUGIN_H_
#define FLUTTER_PLUGIN_PICKIT2_FLUTTER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace pickit2_flutter {

class Pickit2FlutterPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  Pickit2FlutterPlugin();

  virtual ~Pickit2FlutterPlugin();

  // Disallow copy and assign.
  Pickit2FlutterPlugin(const Pickit2FlutterPlugin&) = delete;
  Pickit2FlutterPlugin& operator=(const Pickit2FlutterPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace pickit2_flutter

#endif  // FLUTTER_PLUGIN_PICKIT2_FLUTTER_PLUGIN_H_
