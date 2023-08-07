

#include <stdio.h>
#include <stdlib.h>
#include "coremark.h"
#include "timer.h"
#include "usart.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
#define ITERATIONS 3000
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

#define NSECS_PER_SEC              CLOCKS_PER_SEC
#define CORETIMETYPE               clock_t
#define GETMYTIME(_t)              (*_t = clock())
#define MYTIMEDIFF(fin, ini)       ((fin) - (ini))
#define TIMER_RES_DIVIDER          1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC           (1000000)


static CORETIMETYPE start_time_val, stop_time_val;




long long timer_0, timer_1;

void
start_time(void) {
    //GETMYTIME(&start_time_val);
    timer_0 = timer_getms();
}


void
stop_time(void) {
    //GETMYTIME(&stop_time_val);
    timer_1 = timer_getms();
}



CORE_TICKS
get_time(void) {
    // CORE_TICKS elapsed
    //     = (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
    return timer_1 - timer_0;
}
/* Function : time_in_secs
        Convert the value returned by get_time to seconds.

        The <secs_ret> type is used to accomodate systems with no support for
   floating point. Default implementation implemented by the EE_TICKS_PER_SEC
   macro above.
*/
secs_ret
time_in_secs(CORE_TICKS ticks) {
    //secs_ret retval = ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
    return ((double)ticks) / 1000.0;
}

ee_u32 default_num_contexts = 1;

/* Function : portable_init
        Target specific initialization code
        Test for some common mistakes.
*/




void
portable_init(core_portable* p, int* argc, char* argv[]) {

    printf("start run!!\n");
    if (sizeof(ee_ptr_int) != sizeof(ee_u8*)) {
        ee_printf(
            "ERROR! Please define ee_ptr_int to a type that holds a "
            "pointer!\n");
    }
    if (sizeof(ee_u32) != 4) {
        ee_printf("ERROR! Please define ee_u32 to a 32b unsigned type!\n");
    }
    p->portable_id = 1;
}
/* Function : portable_fini
        Target specific final code
*/
void
portable_fini(core_portable* p) {
    p->portable_id = 0;
}
