#include <IOKit/IOKitLib.h>

// AppleSMC user-client layout; the kernel expects exactly 80 bytes.
typedef struct {
    UInt8 major;
    UInt8 minor;
    UInt8 build;
    UInt8 reserved;
    UInt16 release;
} SMCVersion;

typedef struct {
    UInt16 version;
    UInt16 length;
    UInt32 cpuPLimit;
    UInt32 gpuPLimit;
    UInt32 memPLimit;
} SMCPLimitData;

typedef struct {
    UInt32 dataSize;
    UInt32 dataType;
    UInt8 dataAttributes;
} SMCKeyInfo;

typedef struct {
    UInt32 key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfo keyInfo;
    UInt8 result;
    UInt8 status;
    UInt8 data8;
    UInt32 data32;
    UInt8 bytes[32];
} SMCParamStruct;
