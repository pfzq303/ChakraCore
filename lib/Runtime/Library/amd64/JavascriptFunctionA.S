//-------------------------------------------------------------------------------------------------------
// Copyright (C) Microsoft. All rights reserved.
// Licensed under the MIT license. See LICENSE.txt file in the project root for full license information.
//-------------------------------------------------------------------------------------------------------

.intel_syntax noprefix
#include "unixasmmacros.inc"

.extern _ZN2Js18JavascriptFunction13DeferredParseEPPNS_14ScriptFunctionE

.global _ZN2Js18JavascriptFunction20DeferredParsingThunkEPNS_16RecyclableObjectENS_8CallInfoEz

#ifndef __APPLE__
.type _ZN2Js18JavascriptFunction20DeferredParsingThunkEPNS_16RecyclableObjectENS_8CallInfoEz, @function
#endif

//------------------------------------------------------------------------------
// Invoke
//
//      JavascriptMethod(RecyclableObject* function, CallInfo callInfo, ...)
//
// with a custom calling convention in order to support JavascriptStackWalker
// and RUNTIME_ARGUMENTS. JavascriptMethod entry stack layout:
//
//      [Return Address]
//      [function]              == RDI
//      [callInfo]              == RSI
//      [arg0]
//      [arg1]
//      ...
//------------------------------------------------------------------------------
NESTED_ENTRY amd64_CallFunction, _TEXT, NoHandler
        // Var amd64_CallFunction(
        //      RecyclableObject *function,             (rdi)
        //      JavascriptMethod entryPoint,            (rsi)
        //      CallInfo callInfo,                      (rdx)
        //      uint argc,                              (rcx)
        //      Var *argv);                             (r8)

        // push rbp and adjust CFA offset
        //   CFA refers to Canonical Frame Address.
        //   See section 6.4 of DWARF spec (http://dwarfstd.org/doc/DWARF4.pdf)
        push_nonvol_reg rbp
        mov rbp, rsp

        // Set to compute CFA as: rbp + 16
        //      (16 == sizeof: [rbp] [ReturnAddress])
        // Since rbp remains unchanged, we don't need to adjust CFA offset
        // in this function.
        set_cfa_register rbp, (2*8)

        // Not using other callee-save registers: rbx/r12-r15.
        //
        // The stack is now 16 byte aligned. It was 8-byte aligned when we
        // came into the function, and since then we pushed 8 bytes onto
        // the stack.

        // We need to call the target function with the following:
        //  rdi = function
        //  rsi = CallInfo
        //  function, callInfo, and all args on stack
        //
        // Lets store the entry point in r11 and set up its first two arguments.
        // Note that since rdi is already set up, it doesn't need to change.

        mov r11, rsi    // Store entry point in r11
        mov rsi, rdx    // Store CallInfo in rsi


        mov r10, rcx    // Store argc in r10
        add r10, 3      // function, callInfo, ..., + 1 for alignment
        and r10, -2     // Mask off the lower bit to 16 byte align the stack
        shl r10, 3      // Calculate space for remaining args (* sizeof(Var*))

        cmp r10, 1000h  // If the space is large, make sure the stack is committed
        jl  LOCAL_LABEL(allocate_stack)
        // xplat-todo: Figure out if we need to implement __chkstk
        // call __chkstk

LOCAL_LABEL(allocate_stack):
        sub rsp, r10    // Allocate the stack space
        mov qword ptr [rsp], rdi        // function
        mov qword ptr [rsp + 8h], rsi   // callInfo
        cmp rcx, 0
        je LOCAL_LABEL(args_setup_done)

        // Copy all args (r8) to rsp[2]. rcx has argc.
LOCAL_LABEL(copy_args_to_stack):
        lea rdi, [rsp + 10h]            // &rsp[2]
        mov rsi, r8                     // argv
        rep movsq
        mov rdi, qword ptr [rsp]        // restore rdi
        mov rsi, qword ptr [rsp + 8h]   // restore rsi

LOCAL_LABEL(args_setup_done):
        xor rax, rax    // Zero out rax in case r11 expects varags
        call r11

LOCAL_LABEL(function_done):
        lea rsp, [rbp]
        pop_nonvol_reg rbp
        ret
NESTED_END amd64_CallFunction, _TEXT


// extrn ?DeferredParse@JavascriptFunction@Js@@SAP6APEAXPEAVRecyclableObject@2@UCallInfo@2@ZZPEAPEAVScriptFunction@2@@Z : PROC
.align 16
_ZN2Js18JavascriptFunction20DeferredParsingThunkEPNS_16RecyclableObjectENS_8CallInfoEz:
        push rbp
        lea  rbp, [rsp]

        // save argument registers used by custom calling convention
        push rdi
        push rsi

        // Call
        //  JavascriptMethod JavascriptFunction::DeferredParse(ScriptFunction**)
        //
        lea rdi, [rbp + 10h]    // &function, setup by custom calling convention
        call _ZN2Js18JavascriptFunction13DeferredParseEPPNS_14ScriptFunctionE@plt

        pop rsi
        pop rdi
        pop rbp

        jmp rax
