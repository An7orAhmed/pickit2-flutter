#include "pk2_usb_android.h"

#include <android/log.h>
#include <cerrno>
#include <cstring>
#include <fcntl.h>
#include <linux/usbdevice_fs.h>
#include <mutex>
#include <sys/ioctl.h>
#include <unistd.h>

#include "pk2usb.h"

namespace {

constexpr unsigned char kEndpointIn = 0x81;
constexpr unsigned char kEndpointOut = 0x01;
constexpr unsigned int kTimeoutMs = 2000;

std::mutex gUsbMutex;
int gUsbFileDescriptor = -1;
std::string gSerialNumber;

int Transfer(unsigned char endpoint, unsigned char *buffer, int length) {
  std::lock_guard<std::mutex> lock(gUsbMutex);
  if (gUsbFileDescriptor < 0) {
    return 0;
  }

  usbdevfs_bulktransfer transfer{};
  transfer.ep = endpoint;
  transfer.len = static_cast<unsigned int>(length);
  transfer.timeout = kTimeoutMs;
  transfer.data = buffer;
  const int result = ioctl(gUsbFileDescriptor, USBDEVFS_BULK, &transfer);
  if (result != length) {
    __android_log_print(
      ANDROID_LOG_ERROR,
      "PICkit2Native",
      "USB transfer failed on endpoint 0x%02X: result=%d errno=%d (%s)",
      endpoint,
      result,
      errno,
      strerror(errno)
    );
    return 0;
  }
  return 1;
}

}  // namespace

pickit_dev *deviceHandle = nullptr;
PickitType_t deviceType = Pickit2;
PickitWriteStatus_t writeStatus = notWritten;

bool ConfigureAndroidUsb(int fileDescriptor, const std::string &serialNumber) {
  std::lock_guard<std::mutex> lock(gUsbMutex);
  if (gUsbFileDescriptor >= 0) {
    close(gUsbFileDescriptor);
  }
  gUsbFileDescriptor = dup(fileDescriptor);
  gSerialNumber = serialNumber;
  deviceType = Pickit2;
  writeStatus = notWritten;
  return gUsbFileDescriptor >= 0;
}

void CloseAndroidUsb() {
  std::lock_guard<std::mutex> lock(gUsbMutex);
  if (gUsbFileDescriptor >= 0) {
    close(gUsbFileDescriptor);
    gUsbFileDescriptor = -1;
  }
  gSerialNumber.clear();
  deviceHandle = nullptr;
}

pickit_dev *usbPickitOpen(int unitIndex, char *id) {
  std::lock_guard<std::mutex> lock(gUsbMutex);
  if (unitIndex != 0 || gUsbFileDescriptor < 0) {
    return nullptr;
  }
  if (id != nullptr) {
    std::strncpy(id, gSerialNumber.c_str(), 31);
    id[31] = '\0';
  }
  return reinterpret_cast<pickit_dev *>(1);
}

void releaseUSB(pickit_dev *) {
  CloseAndroidUsb();
}

int sendUSB(pickit_dev *, byte *source, int) {
  return Transfer(kEndpointOut, source, reqLen);
}

int recvUSB(pickit_dev *, int length, byte *destination) {
  return Transfer(kEndpointIn, destination, length);
}
