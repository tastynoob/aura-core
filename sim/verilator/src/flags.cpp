#include "flags.hpp"

#include <string.h>
#include <err.h>

std::map<std::string, DebugFlag> debugflag_name = {
    {"BPU" , DebugFlag::BPU},
    {"FETCH" , DebugFlag::FETCH},
    {"DECODE" , DebugFlag::DECODE},

    {"RENAME" , DebugFlag::RENAME},
    {"RENAME_ALLOC" , DebugFlag::RENAME_ALLOC},

    {"EXECUTE" , DebugFlag::EXECUTE},
    {"COMMIT" , DebugFlag::COMMIT},
    {"ROM" , DebugFlag::ROM}
};

DebugChecker debugChecker;

DebugChecker::DebugChecker()
{
    debug_flags.resize(DebugFlag::NUM_DEBUGFLAGS, false);
}

void DebugChecker::enableFlags(std::string flags)
{
    char flag[20];
    int pos = 0;
    for (int i=0; i<flags.size() + 1;i++) {
        if (flags[i] == ',' || flags[i] == 0) {
            flag[pos] = 0;
            pos = 0;
            auto flag_name = debugflag_name.find(std::string(flag));
            if (flag_name != debugflag_name.end()) {
                printf("enable flag: %s\n", flag);
                debug_flags[flag_name->second] = true;
            }
            else {
                warn("can not find flag: %s!\n", flag);
                exit(1);
            }
        }
        else {
            flag[pos++] = flags[i];
        }
    }
}

void DebugChecker::clearFlags()
{
    for (auto it = debug_flags.begin(); it!= debug_flags.end(); it++) {
        (*it) = false;
    }
}

bool DebugChecker::checkFlag(DebugFlag flag)
{
    return debug_flags[flag];
}



