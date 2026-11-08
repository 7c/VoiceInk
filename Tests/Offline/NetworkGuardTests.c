#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>
#include <stdio.h>
#include <unistd.h>
int main(void) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0 && errno == EPERM) { puts("PASS: IPv4 sockets denied"); return 0; }
    struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET, .sin_port = htons(9), .sin_addr.s_addr = htonl(INADDR_LOOPBACK) };
    int result = connect(fd, (struct sockaddr *)&address, sizeof(address));
    int connection_errno = errno;
    close(fd);
    if (result != -1 || connection_errno != EPERM) { fprintf(stderr, "FAIL: connect result %d errno %d\n", result, connection_errno); return 1; }
    puts("PASS: loopback TCP connect denied by kernel (EPERM)");
    fd = socket(AF_INET6, SOCK_STREAM, 0);
    if (fd < 0 && errno == EPERM) { puts("PASS: IPv6 sockets denied"); return 0; }
    struct sockaddr_in6 address6 = { .sin6_len = sizeof(address6), .sin6_family = AF_INET6 };
    result = bind(fd, (struct sockaddr *)&address6, sizeof(address6));
    int bind_errno = errno;
    close(fd);
    if (result != -1 || bind_errno != EPERM) { fprintf(stderr, "FAIL: bind result %d errno %d\n", result, bind_errno); return 1; }
    puts("PASS: IPv6 bind denied by kernel (EPERM)");
    return 0;
}
