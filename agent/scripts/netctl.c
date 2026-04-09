#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: netctl {enable|disable|status}\n");
        return 1;
    }

    if (strcmp(argv[1], "enable") != 0 &&
        strcmp(argv[1], "disable") != 0 &&
        strcmp(argv[1], "status") != 0) {
        fprintf(stderr, "netctl: invalid command '%s'\n", argv[1]);
        return 1;
    }

    if (geteuid() == 0) {
        setgid(0);
        setuid(0);
    }

    execl("/bin/bash", "bash", "-p", "/home/agent/scripts/network-enable.sh", argv[1], NULL);
    perror("execl");
    return 127;
}
