/* core/backend/orcjit/orcjit.c —— orcjit LLVM MCJIT 驱动（真 JIT）。
 *
 * 定位：trm 路线 B 的可替换后端之一（LLVM JIT 探针）。与 interp/tiejit 共用同一
 * Backend 契约：对同一 tieir 纯函数给出一致结果，进入契约矩阵。
 *
 * 本驱动为一个独立进程：`orcjit.exe <op> <a> <b>`，其中 op = IR 二元算术操作码
 * （与 core/middle/ir.tie opcode 对齐：0=add 1=sub 2=mul 3=div）。它接收操作码与
 * 两个 i64 操作数，用 LLVM-C IRBuilder 现场构造 `i64 cf(i64%a,i64%b)` 模块，
 * 经 LLVM **MCJIT ExecutionEngine** JIT 编译并调用，结果以十进制打印到 stdout。
 *
 * 为什么独立进程：tiec 的 extern 仅解析 libc 这类自动链接符号、无「附加链接库」
 * 机制，且 tie 无原始函数指针调用，无法在进程内安全桥 LLVM。独立 JIT 进程 + 进程
 * 边界调用，是当前 toolchain 下接入真实 LLVM JIT 的稳妥路径（也契合「可替换后端/
 * 其他语言实现」的契约框架）。LLVM IR 从 tieir 的降级（IR 生成）留待 P3——本探针
 * 只证明「LLVM JIT 执行同契一致、可进入矩阵」。
 *
 * 构建（PowerShell）：见 build-orcjit.ps1（clang + D:\LLVM 的 LLVM-C.lib / LLVM-C.dll）。
 */
#include <llvm-c/Core.h>
#include <llvm-c/ExecutionEngine.h>
#include <llvm-c/TargetMachine.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* 解析十进制长整型；失败返回 -1。 */
static long parse_i64(const char *s, long *out) {
    if (!s || !*s)
        return -1;
    char *end = NULL;
    errno = 0;
    long v = strtoll(s, &end, 10);
    if (errno != 0 || (end && *end != '\0'))
        return -1;
    *out = v;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 4)
        return 2;
    long op, a, b;
    if (parse_i64(argv[1], &op) || op < 0 || op > 3)
        return 2;
    if (parse_i64(argv[2], &a) || parse_i64(argv[3], &b))
        return 2;

    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();

    LLVMContextRef ctx = LLVMContextCreate();
    LLVMModuleRef mod = LLVMModuleCreateWithNameInContext("orcjit", ctx);
    LLVMTypeRef i64t = LLVMInt64TypeInContext(ctx);
    LLVMTypeRef params[2] = {i64t, i64t};
    LLVMTypeRef fty = LLVMFunctionType(i64t, params, 2, 0);
    LLVMValueRef fn = LLVMAddFunction(mod, "cf", fty);
    LLVMValueRef aa = LLVMGetParam(fn, 0);
    LLVMValueRef bb = LLVMGetParam(fn, 1);

    LLVMBasicBlockRef body = LLVMAppendBasicBlockInContext(ctx, fn, "entry");
    LLVMBuilderRef bld = LLVMCreateBuilderInContext(ctx);
    LLVMPositionBuilderAtEnd(bld, body);

    LLVMValueRef r = NULL;
    switch (op) {
    case 0: r = LLVMBuildAdd(bld, aa, bb, "r"); break;
    case 1: r = LLVMBuildSub(bld, aa, bb, "r"); break;
    case 2: r = LLVMBuildMul(bld, aa, bb, "r"); break;
    default:r = LLVMBuildSDiv(bld, aa, bb, "r"); break;
    }
    LLVMBuildRet(bld, r);

    LLVMExecutionEngineRef ee = NULL;
    char *err = NULL;
    LLVMLinkInMCJIT();   /* 此 LLVM-C 版本该函数返回 void：仅确保 MCJIT 符号可用 */
    if (LLVMCreateExecutionEngineForModule(&ee, mod, &err) != 0) {
        fprintf(stderr, "CreateExecutionEngine: %s\n", err ? err : "unknown");
        return 3;
    }
    uint64_t addr = LLVMGetFunctionAddress(ee, "cf");
    if (!addr) {
        fprintf(stderr, "GetFunctionAddress failed\n");
        return 4;
    }
    long (*f)(long, long) = (long (*)(long, long))(intptr_t)addr;
    long out = f(a, b);
    /* 无换行输出，方便 tie 端整体按数字解析（避免 CRLF 干扰）。 */
    printf("%lld", (long long)out);
    return 0;
}