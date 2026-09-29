#import "Pk2NativeBridge.h"

#include <algorithm>
#include <cctype>
#include <memory>
#include <string>

#include "pk2cmd/stdafx.h"
#include "pk2cmd/ImportExportHex.h"
#include "pk2cmd/PICkitFunctions.h"

namespace {

NSString *const Pk2NativeErrorDomain = @"pickit2_flutter.native";

void SetError(NSError **error, NSInteger code, NSString *message) {
  if (error != nullptr) {
    *error = [NSError errorWithDomain:Pk2NativeErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey: message}];
  }
}

std::string Uppercase(NSString *value) {
  std::string result([value UTF8String]);
  std::transform(result.begin(), result.end(), result.begin(), [](unsigned char character) {
    return static_cast<char>(std::toupper(character));
  });
  return result;
}

NSArray<NSNumber *> *WordsToBytes(const unsigned int *words, NSUInteger count, NSUInteger bytesPerWord) {
  NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:count * bytesPerWord];
  for (NSUInteger index = 0; index < count; index++) {
    for (NSUInteger byteIndex = 0; byteIndex < bytesPerWord; byteIndex++) {
      [result addObject:@((words[index] >> (byteIndex * 8)) & 0xFF)];
    }
  }
  return result;
}

NSString *ReadErrorMessage(CPICkitFunctions &functions, NSString *operation) {
  NSString *memory = [NSString stringWithUTF8String:functions.ReadError.memoryType] ?: @"Device";
  return [NSString stringWithFormat:@"%@ failed in %@ memory at 0x%X (expected 0x%X, read 0x%X)",
                                    operation,
                                    memory,
                                    functions.ReadError.address,
                                    functions.ReadError.expected,
                                    functions.ReadError.read];
}

}  // namespace

@interface Pk2NativeBridge () {
  std::unique_ptr<CPICkitFunctions> _functions;
  std::unique_ptr<CImportExportHex> _hex;
  BOOL _connected;
  BOOL _partSelected;
}
@end

@implementation Pk2NativeBridge

- (nullable instancetype)initWithDeviceFilePath:(NSString *)path error:(NSError **)error {
  self = [super init];
  if (self == nil) {
    return nil;
  }

  _functions = std::make_unique<CPICkitFunctions>();
  _hex = std::make_unique<CImportExportHex>();
  std::string deviceFilePath([path fileSystemRepresentation]);
  if (!_functions->ReadDeviceFile(deviceFilePath.data())) {
    SetError(error, 1, [NSString stringWithFormat:@"Unable to load device database at %@", path]);
    return nil;
  }
  _functions->SetProgrammingSpeedDefault(0);
  return self;
}

- (void)dealloc {
  [self disconnect];
}

- (nullable NSDictionary<NSString *, id> *)connect:(NSError **)error {
  if (!_connected && !_functions->DetectPICkit2Device(0, true)) {
    SetError(error, 2, @"PICkit 2 was not found or did not respond");
    return nil;
  }
  _connected = YES;

  const char *unitID = _functions->GetUnitID();
  NSString *serial = unitID == nullptr ? @"" : [NSString stringWithUTF8String:unitID];
  NSString *firmware = [NSString stringWithFormat:@"%u.%02u.%02u",
                                                   _functions->FirmwareVersion.major,
                                                   _functions->FirmwareVersion.minor,
                                                   _functions->FirmwareVersion.dot];
  return @{
    @"serialNumber": serial ?: @"",
    @"firmwareVersion": firmware,
    @"programmer": [NSString stringWithUTF8String:_functions->PicKitModelname[_functions->type()]],
  };
}

- (void)disconnect {
  if (_functions != nullptr && _connected) {
    _functions->VddOff();
    _functions->SetMCLR(false);
    _functions->USBClose();
  }
  _connected = NO;
  _partSelected = NO;
}

- (nullable NSDictionary<NSString *, id> *)selectPart:(NSString *)partName error:(NSError **)error {
  std::string normalized = Uppercase(partName);
  BOOL found = NO;
  for (int index = 0; index < _functions->DevFile.Info.NumberParts; index++) {
    if (normalized == _functions->DevFile.PartsList[index].PartName) {
      found = YES;
      break;
    }
  }
  if (!found || !_functions->FindDevice(normalized.data())) {
    SetError(error, 3, [NSString stringWithFormat:@"Unsupported target %@", partName]);
    return nil;
  }

  _functions->GetDefaultVdd();
  _functions->GetDefaultVpp();
  _partSelected = YES;
  return [self selectedPartInfo];
}

- (nullable NSDictionary<NSString *, id> *)autoDetect:(NSError **)error {
  if (![self requireConnection:error]) {
    return nil;
  }

  _functions->SetVddSetPoint(3.3F);
  for (int priority = 0; priority < _functions->DevFile.Info.NumberFamilies; priority++) {
    for (int family = 0; family < _functions->DevFile.Info.NumberFamilies; family++) {
      const auto &familyInfo = _functions->DevFile.Families[family];
      if (familyInfo.PartDetect && familyInfo.SearchPriority == priority && _functions->SearchDevice(family)) {
        NSString *part = [NSString stringWithUTF8String:_functions->DevFile.PartsList[_functions->ActivePart].PartName];
        NSDictionary<NSString *, id> *selected = [self selectPart:part error:error];
        if (selected == nil) {
          return nil;
        }
        _functions->PrepPICkit2();
        unsigned int deviceID = _functions->ReadDeviceID();
        NSMutableDictionary<NSString *, id> *detected = [selected mutableCopy];
        detected[@"deviceId"] = [NSString stringWithFormat:@"0x%X", deviceID];
        detected[@"revision"] = @(_functions->GetDeviceRevision());
        return detected;
      }
    }
  }

  SetError(error, 4, @"No supported target was detected");
  return nil;
}

- (BOOL)erase:(NSError **)error {
  if (![self prepare:error]) {
    return NO;
  }

  bool lowVoltageErase = false;
  if (_functions->FamilyIsEEPROM()) {
    if (!_functions->SerialEEPROMErase()) {
      SetError(error, 5, @"EEPROM erase failed");
      return NO;
    }
  } else {
    _functions->EraseDevice(true, true, &lowVoltageErase);
  }
  return [self checkProgrammerStatus:error];
}

- (nullable NSDictionary<NSString *, id> *)blankCheck:(NSError **)error {
  if (![self prepare:error]) {
    return nil;
  }
  bool blank = _functions->ReadDevice(BLANK_CHECK, true, true, true, true);
  if (![self checkProgrammerStatus:error]) {
    return nil;
  }
  if (blank) {
    return @{@"success": @YES, @"blank": @YES, @"message": @"Device is blank"};
  }
  return @{
    @"success": @YES,
    @"blank": @NO,
    @"message": ReadErrorMessage(*_functions, @"Blank check"),
    @"memoryType": [NSString stringWithUTF8String:_functions->ReadError.memoryType] ?: @"",
    @"address": @(_functions->ReadError.address),
    @"expected": @(_functions->ReadError.expected),
    @"actual": @(_functions->ReadError.read),
  };
}

- (nullable NSDictionary<NSString *, id> *)read:(NSError **)error {
  if (![self prepare:error]) {
    return nil;
  }
  if (!_functions->ReadDevice(READ_MEM, true, true, true, true)) {
    SetError(error, 6, ReadErrorMessage(*_functions, @"Read"));
    return nil;
  }
  if (![self checkProgrammerStatus:error]) {
    return nil;
  }

  const auto &part = _functions->DevFile.PartsList[_functions->ActivePart];
  const auto &family = _functions->DevFile.Families[_functions->ActiveFamily];
  NSArray<NSNumber *> *program = WordsToBytes(_functions->DeviceBuffers->ProgramMemory,
                                               part.ProgramMem,
                                               family.ProgMemHexBytes);
  NSArray<NSNumber *> *eeprom = WordsToBytes(_functions->DeviceBuffers->EEPromMemory,
                                              part.EEMem,
                                              family.EEMemBytesPerWord);
  NSArray<NSNumber *> *config = WordsToBytes(_functions->DeviceBuffers->ConfigWords,
                                              part.ConfigWords,
                                              family.ProgMemHexBytes);
  NSArray<NSNumber *> *userIDs = WordsToBytes(_functions->DeviceBuffers->UserIDs,
                                               part.UserIDWords,
                                               family.UserIDHexBytes);

  return @{
    @"success": @YES,
    @"programMemory": program,
    @"programBaseAddress": @0,
    @"eepromMemory": eeprom,
    @"eepromBaseAddress": @(part.EEAddr),
    @"configMemory": config,
    @"configBaseAddress": @(part.ConfigAddr),
    @"userIdMemory": userIDs,
    @"userIdBaseAddress": @(part.UserIDAddr),
    @"configWords": [self configWords],
  };
}

- (nullable NSDictionary<NSString *, id> *)writeHexAtPath:(NSString *)path
                                                  progress:(nullable Pk2ProgressHandler)progress
                                                     error:(NSError **)error {
  if (![self importHex:path error:error] || ![self prepare:error]) {
    return nil;
  }

  if (progress != nil) progress(@"erase", 5, @"Erasing target");
  bool lowVoltageErase = false;
  bool success = true;

  if (_functions->FamilyIsEEPROM()) {
    success = _functions->EepromWrite(WRITE_EE);
  } else {
    _functions->EraseDevice(true, true, &lowVoltageErase);
    if (progress != nil) progress(@"write", 20, @"Writing program memory, EEPROM, and user IDs");
    bool configInProgramSpace = _functions->WriteDevice(true, true, true, false, lowVoltageErase);

    if (!configInProgramSpace) {
      if (progress != nil) progress(@"verify", 72, @"Verifying programmed memory");
      success = _functions->ReadDevice(VERIFY_MEM_SHORT, true, true, true, false);
      if (success) {
        if (progress != nil) progress(@"config", 86, @"Writing configuration words");
        bool configNeedsNoEntry = _functions->WriteDevice(false, false, false, true, lowVoltageErase);
        success = _functions->ReadDevice(configNeedsNoEntry ? VERIFY_NOPRG_ENTRY : VERIFY_MEM_SHORT,
                                         false,
                                         false,
                                         false,
                                         true);
      }
    } else {
      if (progress != nil) progress(@"verify", 80, @"Verifying target");
      success = _functions->ReadDevice(VERIFY_NOPRG_ENTRY, true, true, true, true);
    }
  }

  if (!success) {
    SetError(error, 7, ReadErrorMessage(*_functions, @"Program/verify"));
    return nil;
  }
  if (![self checkProgrammerStatus:error]) {
    return nil;
  }
  if (progress != nil) progress(@"done", 100, @"Programming and verification complete");
  return @{@"success": @YES, @"message": @"Programming and verification complete"};
}

- (BOOL)exportHexAtPath:(NSString *)path error:(NSError **)error {
  if (!_partSelected) {
    SetError(error, 10, @"Select or auto-detect a target first");
    return NO;
  }
  std::string filePath([path fileSystemRepresentation]);
  if (!_hex->ExportHexFile(filePath.data(), _functions.get(), true)) {
    SetError(error, 14, @"Unable to export the device image as Intel HEX");
    return NO;
  }
  return YES;
}

- (nullable NSDictionary<NSString *, id> *)verifyHexAtPath:(NSString *)path
                                                   progress:(nullable Pk2ProgressHandler)progress
                                                      error:(NSError **)error {
  if (![self importHex:path error:error] || ![self prepare:error]) {
    return nil;
  }
  if (progress != nil) progress(@"verify", 10, @"Verifying target against loaded image");
  bool success = _functions->ReadDevice(VERIFY_MEM, true, true, true, true);
  if (!success) {
    SetError(error, 8, ReadErrorMessage(*_functions, @"Verify"));
    return nil;
  }
  if (![self checkProgrammerStatus:error]) {
    return nil;
  }
  if (progress != nil) progress(@"done", 100, @"Verification succeeded");
  return @{@"success": @YES, @"message": @"Verification succeeded"};
}

- (BOOL)requireConnection:(NSError **)error {
  if (!_connected) {
    SetError(error, 9, @"Connect to PICkit 2 first");
    return NO;
  }
  return YES;
}

- (BOOL)prepare:(NSError **)error {
  if (![self requireConnection:error]) {
    return NO;
  }
  if (!_partSelected) {
    SetError(error, 10, @"Select or auto-detect a target first");
    return NO;
  }
  _functions->PrepPICkit2();
  return [self checkProgrammerStatus:error];
}

- (BOOL)importHex:(NSString *)path error:(NSError **)error {
  if (!_partSelected) {
    SetError(error, 10, @"Select or auto-detect a target first");
    return NO;
  }
  std::string filePath([path fileSystemRepresentation]);
  if (!_hex->ImportHexFile(filePath.data(), _functions.get())) {
    SetError(error, 11, @"The loaded HEX file is invalid for the selected target");
    return NO;
  }
  return YES;
}

- (BOOL)checkProgrammerStatus:(NSError **)error {
  int status = _functions->ReadPkStatus();
  if ((status & STATUS_VDD_ERROR) != 0) {
    SetError(error, 12, @"PICkit 2 reported a VDD fault; check target power and wiring");
    return NO;
  }
  if ((status & STATUS_VPP_ERROR) != 0) {
    SetError(error, 13, @"PICkit 2 reported a VPP fault; check MCLR/VPP wiring");
    return NO;
  }
  return YES;
}

- (NSDictionary<NSString *, id> *)selectedPartInfo {
  const auto &part = _functions->DevFile.PartsList[_functions->ActivePart];
  const auto &family = _functions->DevFile.Families[_functions->ActiveFamily];
  return @{
    @"found": @YES,
    @"model": [NSString stringWithUTF8String:part.PartName],
    @"family": [NSString stringWithUTF8String:family.FamilyName],
    @"deviceId": [NSString stringWithFormat:@"0x%X", part.DeviceID],
    @"revision": @(_functions->GetDeviceRevision()),
    @"programWords": @(part.ProgramMem),
    @"flashBytes": @(part.ProgramMem * family.ProgMemHexBytes),
    @"eepromSize": @(part.EEMem * family.EEMemHexBytes),
    @"eepromAddress": @(part.EEAddr),
    @"configWordCount": @(part.ConfigWords),
    @"configAddress": @(part.ConfigAddr),
    @"bytesPerLocation": @(family.BytesPerLocation),
    @"programHexBytes": @(family.ProgMemHexBytes),
    @"vdd": @(_functions->GetDefaultVdd()),
    @"configWords": [self configWords],
  };
}

- (NSArray<NSDictionary<NSString *, NSNumber *> *> *)configWords {
  const auto &part = _functions->DevFile.PartsList[_functions->ActivePart];
  const auto &family = _functions->DevFile.Families[_functions->ActiveFamily];
  const NSUInteger bytesPerWord = _functions->FamilyIsPIC32() ? 2 : family.ProgMemHexBytes;
  NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *words = [NSMutableArray arrayWithCapacity:part.ConfigWords];
  for (NSUInteger index = 0; index < part.ConfigWords; index++) {
    [words addObject:@{
      @"index": @(index),
      @"address": @(part.ConfigAddr + index * bytesPerWord),
      @"byteCount": @(bytesPerWord),
      @"value": @(_functions->DeviceBuffers->ConfigWords[index]),
      @"mask": @(part.ConfigMasks[index]),
      @"blank": @(part.ConfigBlank[index]),
    }];
  }
  return words;
}

@end
