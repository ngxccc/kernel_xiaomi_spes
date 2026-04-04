/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __ASM_STACK_POINTER_H
#define __ASM_STACK_POINTER_H

/*
 * how to get the current stack pointer from C
 */

/* * [OLD CODE] Comment out or delete this line:
 * register unsigned long current_stack_pointer asm ("sp");
 */

/* * [RAIZO FIX] Modern Clang-compliant way to read the Stack Pointer.
 * Use inline assembly to safely move the 'sp' register value into a variable.
 */
#define current_stack_pointer ({ \
    unsigned long __sp; \
    asm volatile("mov %0, sp" : "=r" (__sp)); \
    __sp; \
})

#endif /* __ASM_STACK_POINTER_H */
