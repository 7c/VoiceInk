#include <sandbox.h>
#include <unistd.h>
#include <stdio.h>
// Keep Accessibility and local file workflows working, but deny all socket networking.
// Children inherit this restriction. Failure is fatal, never an online fallback.
__attribute__((constructor)) static void enforce_offline_mode(void) {
    char *error = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    int result = sandbox_init("(version 1)(allow default)(deny network*)", 0, &error);
    if (result != 0) {
        fprintf(stderr, "VoiceInk cannot enforce offline mode: %s\n", error ? error : "unknown error");
        if (error) sandbox_free_error(error);
        _exit(78);
    }
}

#pragma clang diagnostic pop
