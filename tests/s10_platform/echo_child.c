/* tests/s10_platform/echo_child.c —— 交互式回显子进程（S10d 验收用）
 * 逐行从 stdin 读取并回显到 stdout（前缀 "E:"），每行 fflush——
 * 模拟 REPL 类交互程序（stdin 未 EOF 即实时回显）；EOF 后退出。
 * Windows 控制台工具（cmd/findstr/sort 等）在 stdin 为匿名管道且未 EOF 时
 * 不做逐行 flush，故交互式验收用本子进程；编译：clang echo_child.c -o echo_child.exe
 */
#include <stdio.h>

int main(void) {
    char buf[4096];
    while (fgets(buf, sizeof buf, stdin) != NULL) {
        fputs("E:", stdout);
        fputs(buf, stdout);
        fflush(stdout);
    }
    return 0;
}