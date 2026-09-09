#import <Foundation/Foundation.h>

// Keep the pinned SunPad snapshot byte-identical. Foundation is imported before
// this narrow substitution so only the downstream implementation's directory
// request changes for tvOS.
#define NSApplicationSupportDirectory NSCachesDirectory
#include "../third_party/sunpad/SunPadDiagnostics.mm"
