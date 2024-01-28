#include "flags.hpp"

#include <string.h>
#include <err.h>

std::map<std::string, DebugFlag> debugflag_name = {
    {"UBTB", DebugFlag::UBTB},
    {"FTB", DebugFlag::FTB},
    {"BPU" , DebugFlag::BPU},
    {"BPU_GBH", DebugFlag::BPU_GBH},
    {"FTQ", DebugFlag::FTQ},
    {"FTQCOMMIT", DebugFlag::FTQCOMMIT},
    {"FETCH" , DebugFlag::FETCH},
    {"DECODE" , DebugFlag::DECODE},

    {"RENAME" , DebugFlag::RENAME},
    {"RENAME_ALLOC" , DebugFlag::RENAME_ALLOC},

    {"EXECUTE" , DebugFlag::EXECUTE},
    {"COMMIT" , DebugFlag::COMMIT},
    {"PIPELINE", DebugFlag::PIPELINE},
    {"ROM" , DebugFlag::ROM}
};

DebugChecker debugChecker;

DebugChecker::DebugChecker()
{
    debug_flags.resize(DebugFlag::NUM_DEBUGFLAGS, false);
    dprint_buf.resize(DebugFlag::NUM_DEBUGFLAGS);
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
                printf("can not find flag: %s!\n", flag);
                exit(1);
            }
        }
        else {
            flag[pos++] = flags[i];
        }
    }
    enable_flag = true;
}

void DebugChecker::clearFlags()
{
    for (auto it = debug_flags.begin(); it!= debug_flags.end(); it++) {
        (*it) = false;
    }
    enable_flag = false;
}

bool DebugChecker::checkFlag(DebugFlag flag)
{
    return debug_flags[flag];
}

void DebugChecker::putin(DebugFlag flag, const char * str)
{
    dprint_buf[flag] << str;
}

void DebugChecker::printAll()
{
    if (enable_flag) {
        for (auto& it : dprint_buf) {
            if (it.rdbuf()->in_avail()) {
                std::cout << it.str();
                it.str("");
                it.clear();
            }
        }
    }
    if (dprinta_buf.rdbuf()->in_avail()) {
        std::cout << dprinta_buf.str();
        dprinta_buf.str("");
        dprinta_buf.clear();
    }
}


bool forceExit = false;
bool runningfail = false;

void mark_exit(bool failed) {
    runningfail = failed;
    forceExit = true;
}

uint32_t force_exit() {
    uint32_t type = 
    runningfail ? 1 : 2;
    return forceExit ? type : 0;
}