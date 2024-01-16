#pragma once

#include <iostream>
#include <stdint.h>
#include <vector>
#include <map>
#include <sstream>

enum DebugFlag {
    UBTB,
    FTB,
    BPU,
    BPU_GBH,
    FTQ,
    FTQCOMMIT,

    FETCH,
    DECODE,

    RENAME,
    RENAME_ALLOC,

    EXECUTE,
    COMMIT,

    PIPELINE,

    ROM,
    NUM_DEBUGFLAGS
};

extern std::map<std::string, DebugFlag> debugflag_name;
extern uint64_t curTick();

class DebugChecker {
    bool enable_flag = false;
    std::vector<bool> debug_flags;
    std::vector<std::stringstream> dprint_buf;
    public:
    char strBuf[1024];
    DebugChecker();

    // such as: FETCH,DECODE
    void enableFlags(std::string flags);
    void clearFlags();
    bool checkFlag(DebugFlag flag);

    void putin(DebugFlag flag, const char * str);
    void printAll();
};

extern DebugChecker debugChecker;

#define DPRINTF(flag, args...) \
if (debugChecker.checkFlag(DebugFlag::flag)) { \
    sprintf(debugChecker.strBuf, "%lu DebugFlag-" #flag ": ", curTick()); \
    debugChecker.putin(flag, debugChecker.strBuf); \
    sprintf(debugChecker.strBuf, args); \
    debugChecker.putin(flag, debugChecker.strBuf); \
}

#define DPRINTD(flag, args...) \
if (debugChecker.checkFlag(DebugFlag::flag)) { \
    sprintf(debugChecker.strBuf, args); \
    debugChecker.putin(flag, debugChecker.strBuf); \
}


extern void mark_exit(bool failed);
extern uint32_t force_exit();