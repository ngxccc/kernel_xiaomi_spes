#ifndef __KSU_H_UID_OBSERVER
#define __KSU_H_UID_OBSERVER

#include "linux/types.h"
void ksu_throne_tracker_init(void);

void ksu_throne_tracker_exit(void);

void track_throne(bool prune_only);

#endif
