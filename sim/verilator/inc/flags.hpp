#pragma once

#include <iostream>
#include <stdint.h>
#include <vector>
#include <map>

enum DebugFlag {
    BPU,

    FETCH,
    DECODE,

    RENAME,
    RENAME_ALLOC,

    EXECUTE,
    COMMIT,

    ROM,
    NUM_DEBUGFLAGS
};

extern std::map<std::string, DebugFlag> debugflag_name;
extern uint64_t curTick();

class DebugChecker {
    std::vector<bool> debug_flags;
    public:
    DebugChecker();

    // such as: FETCH,DECODE
    void enableFlags(std::string flags);
    void clearFlags();

    bool checkFlag(DebugFlag flag);
};

extern DebugChecker debugChecker;

#define DPRINTF(flag, args...) \
if (debugChecker.checkFlag(DebugFlag::flag)) { \
    printf("%lu " "DebugFlag-" #flag ": ", curTick());\
    printf(args); \
}
