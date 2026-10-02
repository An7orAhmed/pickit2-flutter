#include <jni.h>

#include <algorithm>
#include <cctype>
#include <memory>
#include <sstream>
#include <string>

#include "stdafx.h"
#include "ImportExportHex.h"
#include "PICkitFunctions.h"
#include "pk2_usb_android.h"

namespace {

std::string JStringToString(JNIEnv *env, jstring value) {
  if (value == nullptr) {
    return {};
  }
  const char *characters = env->GetStringUTFChars(value, nullptr);
  std::string result(characters == nullptr ? "" : characters);
  if (characters != nullptr) {
    env->ReleaseStringUTFChars(value, characters);
  }
  return result;
}

jstring StringToJString(JNIEnv *env, const std::string &value) {
  return env->NewStringUTF(value.c_str());
}

std::string JsonEscape(const char *value) {
  std::ostringstream output;
  for (const unsigned char character : std::string(value == nullptr ? "" : value)) {
    switch (character) {
      case '\\': output << "\\\\"; break;
      case '"': output << "\\\""; break;
      case '\b': output << "\\b"; break;
      case '\f': output << "\\f"; break;
      case '\n': output << "\\n"; break;
      case '\r': output << "\\r"; break;
      case '\t': output << "\\t"; break;
      default:
        if (character < 0x20) {
          output << "?";
        } else {
          output << character;
        }
    }
  }
  return output.str();
}

void ThrowStateError(JNIEnv *env, const std::string &message) {
  jclass exceptionClass = env->FindClass("java/lang/IllegalStateException");
  if (exceptionClass != nullptr) {
    env->ThrowNew(exceptionClass, message.c_str());
  }
}

std::string Uppercase(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(), [](unsigned char character) {
    return static_cast<char>(std::toupper(character));
  });
  return value;
}

class NativeEngine {
 public:
  NativeEngine(JNIEnv *env, jobject callback, const std::string &deviceFilePath)
      : functions_(std::make_unique<CPICkitFunctions>()),
        hex_(std::make_unique<CImportExportHex>()),
        callback_(env->NewGlobalRef(callback)) {
    std::string path = deviceFilePath;
    if (!functions_->ReadDeviceFile(path.data())) {
      throw std::runtime_error("Unable to load PK2DeviceFile.dat");
    }
    functions_->SetProgrammingSpeedDefault(0);
  }

  void Release(JNIEnv *env) {
    Disconnect();
    if (callback_ != nullptr) {
      env->DeleteGlobalRef(callback_);
      callback_ = nullptr;
    }
  }

  bool AttachUsb(int fileDescriptor, const std::string &serialNumber) {
    return ConfigureAndroidUsb(fileDescriptor, serialNumber);
  }

  std::string Connect() {
    if (!connected_ && !functions_->DetectPICkit2Device(0, true)) {
      throw std::runtime_error("PICkit 2 was not found or did not respond");
    }
    connected_ = true;
    const char *serial = functions_->GetUnitID();
    std::ostringstream output;
    output << "{\"serialNumber\":\"" << JsonEscape(serial) << "\","
           << "\"firmwareVersion\":\""
           << static_cast<unsigned int>(functions_->FirmwareVersion.major) << ".";
    output.width(2);
    output.fill('0');
    output << static_cast<unsigned int>(functions_->FirmwareVersion.minor) << ".";
    output.width(2);
    output << static_cast<unsigned int>(functions_->FirmwareVersion.dot) << "\","
           << "\"programmer\":\""
           << JsonEscape(functions_->PicKitModelname[functions_->type()]) << "\"}";
    return output.str();
  }

  void Disconnect() {
    if (connected_) {
      functions_->VddOff();
      functions_->SetMCLR(false);
      functions_->USBClose();
    } else {
      CloseAndroidUsb();
    }
    connected_ = false;
    partSelected_ = false;
  }

  std::string SelectPart(const std::string &partName) {
    const std::string normalized = Uppercase(partName);
    if (!functions_->FindDevice(const_cast<char *>(normalized.c_str()))) {
      throw std::runtime_error("Unsupported target " + partName);
    }
    functions_->GetDefaultVdd();
    functions_->GetDefaultVpp();
    partSelected_ = true;
    return SelectedPartJson();
  }

  std::string AutoDetect() {
    RequireConnection();
    functions_->SetVddSetPoint(3.3F);
    for (int priority = 0; priority < functions_->DevFile.Info.NumberFamilies; priority++) {
      for (int family = 0; family < functions_->DevFile.Info.NumberFamilies; family++) {
        const auto &familyInfo = functions_->DevFile.Families[family];
        if (familyInfo.PartDetect && familyInfo.SearchPriority == priority && functions_->SearchDevice(family)) {
          const char *partName = functions_->DevFile.PartsList[functions_->ActivePart].PartName;
          SelectPart(partName);
          functions_->PrepPICkit2();
          const unsigned int deviceId = functions_->ReadDeviceID();
          std::string result = SelectedPartJson();
          result.pop_back();
          std::ostringstream output;
          output << result << ",\"deviceId\":\"0x" << std::hex << std::uppercase << deviceId
                 << "\",\"revision\":" << std::dec << functions_->GetDeviceRevision() << "}";
          return output.str();
        }
      }
    }
    throw std::runtime_error("No supported target was detected");
  }

  bool Erase() {
    Prepare();
    bool lowVoltageErase = false;
    if (functions_->FamilyIsEEPROM()) {
      if (!functions_->SerialEEPROMErase()) {
        throw std::runtime_error("EEPROM erase failed");
      }
    } else {
      functions_->EraseDevice(true, true, &lowVoltageErase);
    }
    CheckProgrammerStatus();
    return true;
  }

  std::string BlankCheck() {
    Prepare();
    const bool blank = functions_->ReadDevice(BLANK_CHECK, true, true, true, true);
    CheckProgrammerStatus();
    if (blank) {
      return "{\"success\":true,\"blank\":true,\"message\":\"Device is blank\"}";
    }
    std::ostringstream output;
    output << "{\"success\":true,\"blank\":false,\"message\":\""
           << JsonEscape(ReadErrorMessage("Blank check").c_str()) << "\","
           << "\"memoryType\":\"" << JsonEscape(functions_->ReadError.memoryType) << "\","
           << "\"address\":" << functions_->ReadError.address << ","
           << "\"expected\":" << functions_->ReadError.expected << ","
           << "\"actual\":" << functions_->ReadError.read << "}";
    return output.str();
  }

  std::string Read() {
    Prepare();
    if (!functions_->ReadDevice(READ_MEM, true, true, true, true)) {
      throw std::runtime_error(ReadErrorMessage("Read"));
    }
    CheckProgrammerStatus();

    const auto &part = functions_->DevFile.PartsList[functions_->ActivePart];
    const auto &family = functions_->DevFile.Families[functions_->ActiveFamily];
    std::ostringstream output;
    output << "{\"success\":true,\"programMemory\":";
    AppendWordsAsBytes(output, functions_->DeviceBuffers->ProgramMemory, part.ProgramMem, family.ProgMemHexBytes);
    output << ",\"programBaseAddress\":0,\"eepromMemory\":";
    AppendWordsAsBytes(output, functions_->DeviceBuffers->EEPromMemory, part.EEMem, family.EEMemBytesPerWord);
    output << ",\"eepromBaseAddress\":" << part.EEAddr << ",\"configMemory\":";
    AppendWordsAsBytes(output, functions_->DeviceBuffers->ConfigWords, part.ConfigWords, family.ProgMemHexBytes);
    output << ",\"configBaseAddress\":" << part.ConfigAddr << ",\"userIdMemory\":";
    AppendWordsAsBytes(output, functions_->DeviceBuffers->UserIDs, part.UserIDWords, family.UserIDHexBytes);
    output << ",\"userIdBaseAddress\":" << part.UserIDAddr << ",\"configWords\":";
    AppendConfigWords(output);
    output << "}";
    return output.str();
  }

  std::string WriteHex(JNIEnv *env, const std::string &path) {
    ImportHex(path);
    Prepare();
    Progress(env, "erase", 5, "Erasing target");
    bool lowVoltageErase = false;
    bool success = true;

    if (functions_->FamilyIsEEPROM()) {
      success = functions_->EepromWrite(WRITE_EE);
    } else {
      functions_->EraseDevice(true, true, &lowVoltageErase);
      Progress(env, "write", 20, "Writing program memory, EEPROM, and user IDs");
      const bool configInProgramSpace = functions_->WriteDevice(true, true, true, false, lowVoltageErase);
      if (!configInProgramSpace) {
        Progress(env, "verify", 72, "Verifying programmed memory");
        success = functions_->ReadDevice(VERIFY_MEM_SHORT, true, true, true, false);
        if (success) {
          Progress(env, "config", 86, "Writing configuration words");
          const bool configNeedsNoEntry = functions_->WriteDevice(false, false, false, true, lowVoltageErase);
          success = functions_->ReadDevice(
            configNeedsNoEntry ? VERIFY_NOPRG_ENTRY : VERIFY_MEM_SHORT,
            false,
            false,
            false,
            true
          );
        }
      } else {
        Progress(env, "verify", 80, "Verifying target");
        success = functions_->ReadDevice(VERIFY_NOPRG_ENTRY, true, true, true, true);
      }
    }

    if (!success) {
      throw std::runtime_error(ReadErrorMessage("Program/verify"));
    }
    CheckProgrammerStatus();
    Progress(env, "done", 100, "Programming and verification complete");
    return "{\"success\":true,\"message\":\"Programming and verification complete\"}";
  }

  std::string VerifyHex(JNIEnv *env, const std::string &path) {
    ImportHex(path);
    Prepare();
    Progress(env, "verify", 10, "Verifying target against loaded image");
    if (!functions_->ReadDevice(VERIFY_MEM, true, true, true, true)) {
      throw std::runtime_error(ReadErrorMessage("Verify"));
    }
    CheckProgrammerStatus();
    Progress(env, "done", 100, "Verification succeeded");
    return "{\"success\":true,\"message\":\"Verification succeeded\"}";
  }

  bool ExportHex(const std::string &path) {
    if (!partSelected_) {
      throw std::runtime_error("Select or auto-detect a target first");
    }
    std::string mutablePath = path;
    if (!hex_->ExportHexFile(mutablePath.data(), functions_.get(), true)) {
      throw std::runtime_error("Unable to export the device image as Intel HEX");
    }
    return true;
  }

 private:
  void RequireConnection() const {
    if (!connected_) {
      throw std::runtime_error("Connect to PICkit 2 first");
    }
  }

  void Prepare() {
    RequireConnection();
    if (!partSelected_) {
      throw std::runtime_error("Select or auto-detect a target first");
    }
    functions_->PrepPICkit2();
    CheckProgrammerStatus();
  }

  void ImportHex(const std::string &path) {
    if (!partSelected_) {
      throw std::runtime_error("Select or auto-detect a target first");
    }
    std::string mutablePath = path;
    if (!hex_->ImportHexFile(mutablePath.data(), functions_.get())) {
      throw std::runtime_error("The loaded HEX file is invalid for the selected target");
    }
  }

  void CheckProgrammerStatus() {
    const int status = functions_->ReadPkStatus();
    if ((status & STATUS_VDD_ERROR) != 0) {
      throw std::runtime_error("PICkit 2 reported a VDD fault; check target power and wiring");
    }
    if ((status & STATUS_VPP_ERROR) != 0) {
      throw std::runtime_error("PICkit 2 reported a VPP fault; check MCLR/VPP wiring");
    }
  }

  std::string ReadErrorMessage(const char *operation) const {
    std::ostringstream output;
    output << operation << " failed in " << functions_->ReadError.memoryType
           << " memory at 0x" << std::hex << std::uppercase << functions_->ReadError.address
           << " (expected 0x" << functions_->ReadError.expected
           << ", read 0x" << functions_->ReadError.read << ")";
    return output.str();
  }

  std::string SelectedPartJson() {
    const auto &part = functions_->DevFile.PartsList[functions_->ActivePart];
    const auto &family = functions_->DevFile.Families[functions_->ActiveFamily];
    std::ostringstream output;
    output << "{\"found\":true,\"model\":\"" << JsonEscape(part.PartName) << "\","
           << "\"family\":\"" << JsonEscape(family.FamilyName) << "\","
           << "\"deviceId\":\"0x" << std::hex << std::uppercase << part.DeviceID << "\","
           << std::dec << "\"revision\":" << functions_->GetDeviceRevision() << ","
           << "\"programWords\":" << part.ProgramMem << ","
           << "\"flashBytes\":" << part.ProgramMem * family.ProgMemHexBytes << ","
           << "\"eepromSize\":" << part.EEMem * family.EEMemHexBytes << ","
           << "\"eepromAddress\":" << part.EEAddr << ","
           << "\"configWordCount\":" << static_cast<unsigned int>(part.ConfigWords) << ","
           << "\"configAddress\":" << part.ConfigAddr << ","
           << "\"bytesPerLocation\":" << static_cast<unsigned int>(family.BytesPerLocation) << ","
           << "\"programHexBytes\":" << static_cast<unsigned int>(family.ProgMemHexBytes) << ","
           << "\"vdd\":" << functions_->GetDefaultVdd() << ",\"configWords\":";
    AppendConfigWords(output);
    output << "}";
    return output.str();
  }

  void AppendConfigWords(std::ostringstream &output) {
    const auto &part = functions_->DevFile.PartsList[functions_->ActivePart];
    const auto &family = functions_->DevFile.Families[functions_->ActiveFamily];
    const unsigned int bytesPerWord = functions_->FamilyIsPIC32() ? 2 : family.ProgMemHexBytes;
    output << "[";
    for (unsigned int index = 0; index < part.ConfigWords; index++) {
      if (index > 0) output << ",";
      output << "{\"index\":" << index
             << ",\"address\":" << part.ConfigAddr + index * bytesPerWord
             << ",\"byteCount\":" << bytesPerWord
             << ",\"value\":" << functions_->DeviceBuffers->ConfigWords[index]
             << ",\"mask\":" << part.ConfigMasks[index]
             << ",\"blank\":" << part.ConfigBlank[index] << "}";
    }
    output << "]";
  }

  static void AppendWordsAsBytes(
    std::ostringstream &output,
    const unsigned int *words,
    unsigned int count,
    unsigned int bytesPerWord
  ) {
    output << "[";
    bool first = true;
    for (unsigned int index = 0; index < count; index++) {
      for (unsigned int byteIndex = 0; byteIndex < bytesPerWord; byteIndex++) {
        if (!first) output << ",";
        first = false;
        output << ((words[index] >> (byteIndex * 8)) & 0xFF);
      }
    }
    output << "]";
  }

  void Progress(JNIEnv *env, const char *phase, int percent, const char *message) const {
    if (callback_ == nullptr) return;
    jclass callbackClass = env->GetObjectClass(callback_);
    jmethodID method = env->GetMethodID(
      callbackClass,
      "onNativeProgress",
      "(Ljava/lang/String;ILjava/lang/String;)V"
    );
    if (method != nullptr) {
      jstring phaseValue = env->NewStringUTF(phase);
      jstring messageValue = env->NewStringUTF(message);
      env->CallVoidMethod(callback_, method, phaseValue, percent, messageValue);
      env->DeleteLocalRef(phaseValue);
      env->DeleteLocalRef(messageValue);
    }
    env->DeleteLocalRef(callbackClass);
  }

  std::unique_ptr<CPICkitFunctions> functions_;
  std::unique_ptr<CImportExportHex> hex_;
  jobject callback_ = nullptr;
  bool connected_ = false;
  bool partSelected_ = false;
};

NativeEngine *Engine(jlong handle) {
  return reinterpret_cast<NativeEngine *>(handle);
}

template <typename Operation>
jstring RunJson(JNIEnv *env, Operation operation) {
  try {
    return StringToJString(env, operation());
  } catch (const std::exception &error) {
    ThrowStateError(env, error.what());
    return nullptr;
  }
}

template <typename Operation>
jboolean RunBoolean(JNIEnv *env, Operation operation) {
  try {
    return operation() ? JNI_TRUE : JNI_FALSE;
  } catch (const std::exception &error) {
    ThrowStateError(env, error.what());
    return JNI_FALSE;
  }
}

}  // namespace

extern "C" JNIEXPORT jlong JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeCreate(
  JNIEnv *env,
  jobject instance,
  jstring deviceFilePath
) {
  try {
    return reinterpret_cast<jlong>(new NativeEngine(env, instance, JStringToString(env, deviceFilePath)));
  } catch (const std::exception &error) {
    ThrowStateError(env, error.what());
    return 0;
  }
}

extern "C" JNIEXPORT void JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeDestroy(JNIEnv *env, jobject, jlong handle) {
  NativeEngine *engine = Engine(handle);
  if (engine != nullptr) {
    engine->Release(env);
    delete engine;
  }
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeAttachUsb(
  JNIEnv *env,
  jobject,
  jlong handle,
  jint fileDescriptor,
  jstring serialNumber
) {
  return RunBoolean(env, [&] {
    return Engine(handle)->AttachUsb(fileDescriptor, JStringToString(env, serialNumber));
  });
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeConnect(JNIEnv *env, jobject, jlong handle) {
  return RunJson(env, [&] { return Engine(handle)->Connect(); });
}

extern "C" JNIEXPORT void JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeDisconnect(JNIEnv *, jobject, jlong handle) {
  Engine(handle)->Disconnect();
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeSelectPart(
  JNIEnv *env,
  jobject,
  jlong handle,
  jstring partName
) {
  return RunJson(env, [&] { return Engine(handle)->SelectPart(JStringToString(env, partName)); });
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeAutoDetect(JNIEnv *env, jobject, jlong handle) {
  return RunJson(env, [&] { return Engine(handle)->AutoDetect(); });
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeErase(JNIEnv *env, jobject, jlong handle) {
  return RunBoolean(env, [&] { return Engine(handle)->Erase(); });
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeBlankCheck(JNIEnv *env, jobject, jlong handle) {
  return RunJson(env, [&] { return Engine(handle)->BlankCheck(); });
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeRead(JNIEnv *env, jobject, jlong handle) {
  return RunJson(env, [&] { return Engine(handle)->Read(); });
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeWriteHex(
  JNIEnv *env,
  jobject,
  jlong handle,
  jstring path
) {
  return RunJson(env, [&] { return Engine(handle)->WriteHex(env, JStringToString(env, path)); });
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeVerifyHex(
  JNIEnv *env,
  jobject,
  jlong handle,
  jstring path
) {
  return RunJson(env, [&] { return Engine(handle)->VerifyHex(env, JStringToString(env, path)); });
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_an7or_pickit2_1flutter_NativePk2Engine_nativeExportHex(
  JNIEnv *env,
  jobject,
  jlong handle,
  jstring path
) {
  return RunBoolean(env, [&] { return Engine(handle)->ExportHex(JStringToString(env, path)); });
}
