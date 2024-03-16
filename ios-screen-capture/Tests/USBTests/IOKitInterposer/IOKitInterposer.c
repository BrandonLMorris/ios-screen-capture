#include "IOKitInterposer.h"

#include <IOKit/IOKitLib.h>
#include <CoreFoundation/CoreFoundation.h>

CFMutableDictionaryRef IOServiceMatching_(const char* name) {
  CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  return dict;
}
DYLD_INTERPOSE(IOServiceMatching_, IOServiceMatching)
