#pragma once

#include <string>

bool ConfigureAndroidUsb(int fileDescriptor, const std::string &serialNumber);
void CloseAndroidUsb();
