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

    MEMDEP,
    LDQUE,
    STQUE,

    PIPELINE,

    ROM,
    NUM_DEBUGFLAGS
};

extern std::map<std::string, DebugFlag> debugflag_name;
extern uint64_t curTick();

class DebugChecker {
    bool enable_flag = false;
    uint64_t debug_start = 0;
    uint64_t debug_end = UINT64_MAX;
    std::vector<bool> tmp_debug_flags;
    std::vector<bool> debug_flags;
    std::vector<std::stringstream> dprint_buf;
    public:
    std::stringstream dprinta_buf; // not controlled by debugflag
    char strBuf[1024];
    DebugChecker();
    void setTime(uint64_t start, uint64_t end)
    {
        debug_start = start;
        debug_end = end;
    }
    // such as: FETCH,DECODE
    void parseFlags(std::string flags);
    void enableFlags();
    void clearFlags();
    bool checkFlag(DebugFlag flag);

    void putin(DebugFlag flag, const char * str);
    void printAll(uint64_t tick);
};

extern DebugChecker debugChecker;

#define DPRINTF(flag, args...) \
if (debugChecker.checkFlag(DebugFlag::flag)) { \
    sprintf(debugChecker.strBuf, "%lu DebugFlag-" #flag ": ", curTick()); \
    debugChecker.putin(flag, debugChecker.strBuf); \
    sprintf(debugChecker.strBuf, args); \
    debugChecker.putin(flag, debugChecker.strBuf); \
}

#define DPRINTFD(flag, args...) \
if (debugChecker.checkFlag(DebugFlag::flag)) { \
    sprintf(debugChecker.strBuf, args); \
    debugChecker.putin(flag, debugChecker.strBuf); \
}

#define DPRINTFA(args...) \
    sprintf(debugChecker.strBuf, args); \
    debugChecker.dprinta_buf << debugChecker.strBuf; \


extern void mark_exit(bool failed);
extern uint32_t force_exit();