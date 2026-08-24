/* impl/impl-win32/trm_platform_c.c —— trm_platform.dll C 冒烟（S10 平台桥）
 * 加载 tie 编译的 trm_platform.dll，调用导出面 trm_platform$is_tty / $raw_mode。
 * 两者返回 tie bool（LLVM i1，C 侧按 int 收 0/1）。
 */
#include <windows.h>
#include <stdio.h>

typedef int (*FnTty)(void);       /* is_tty() -> bool */
typedef int (*FnRaw)(int);        /* raw_mode(bool) -> bool */

static int failures = 0;
static void report(int ok, const char *what) {
    if (ok) printf("PASS %s\n", what); else { printf("FAIL %s\n", what); failures++; }
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "用法: trm_platform_c.exe <trm_platform.dll>\n"); return 2; }
    HMODULE h = LoadLibraryA(argv[1]);
    if (!h) { fprintf(stderr, "LoadLibrary 失败: %lu\n", (unsigned long)GetLastError()); return 1; }
    printf("LoadLibrary OK: %s\n", argv[1]);

    FnTty is_tty = (FnTty)GetProcAddress(h, "trm_platform$is_tty");
    FnRaw raw = (FnRaw)GetProcAddress(h, "trm_platform$raw_mode");
    report(is_tty != NULL && raw != NULL, "导出面解析 is_tty/raw_mode");

    /* ABI 冒烟：调用不崩；is_tty 返回可真可假（环境相关），raw_mode 不返回非法值 */
    int t = is_tty ? is_tty() : -1;
    int on = raw ? raw(1) : -1;   /* raw_mode(true) */
    int off = raw ? raw(0) : -1;  /* raw_mode(false) */
    report(t == 0 || t == 1, "is_tty 返回合法 bool（0/1）");
    report((on == 0 || on == 1) && (off == 0 || off == 1), "raw_mode 返回合法 bool（0/1）");
    printf("  is_tty=%d raw_on=%d raw_off=%d\n", t, on, off);

    FreeLibrary(h);
    if (failures == 0) { printf("=== trm_platform.dll C 冒烟通过 ===\n"); return 0; }
    return 1;
}