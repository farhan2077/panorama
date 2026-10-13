#include "TrackpadBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <math.h>
#include <pthread.h>

// Undocumented Apple ABI, dynamically resolved and confined to this file.
// Failure leaves the global keyboard shortcut fully functional.
typedef struct { float x, y; } WSPoint;
typedef struct { WSPoint position, velocity; } Vector;
typedef struct {
    int frame; double timestamp;
    int identifier, state, fingerID, handID;
    Vector normalized;
    float size; int unused; float angle, major, minor;
    Vector absolute;
    int unused2, unused3; float density;
} Touch;
_Static_assert(sizeof(Touch) == 96, "Unexpected multitouch ABI");
typedef void (*FrameCallback)(void *, Touch *, int, double, int);
static void *library;
static CFArrayRef devices;
static void (*stopDevice)(void *);
static void (*unregisterCallback)(void *, FrameCallback);
static WSContactHandler handler;
static void *gestureDevice;
static pthread_mutex_t handlerLock = PTHREAD_MUTEX_INITIALIZER;

static void frame(void *device, Touch *touches, int count, double timestamp, int number) {
    (void)device; (void)timestamp; (void)number;
    if (count < 0 || count > 20 || (count && !touches)) return;
    int contacts = 0;
    double x = 0, y = 0;
    for (int i = 0; i < count; i++) {
        if (touches[i].state != 3 && touches[i].state != 4) continue;
        float px = touches[i].normalized.position.x, py = touches[i].normalized.position.y;
        if (!isfinite(px) || !isfinite(py) || px < 0 || px > 1 || py < 0 || py > 1) return;
        contacts++; x += px; y += py;
    }
    pthread_mutex_lock(&handlerLock);
    if (contacts == 4 && (!gestureDevice || gestureDevice == device)) {
        gestureDevice = device;
        if (handler) handler(contacts, x / contacts, y / contacts);
    } else if (gestureDevice == device) {
        gestureDevice = NULL;
        if (handler) handler(0, 0, 0);
    }
    pthread_mutex_unlock(&handlerLock);
}
void WSStopTrackpad(void) {
    pthread_mutex_lock(&handlerLock); handler = NULL; gestureDevice = NULL; pthread_mutex_unlock(&handlerLock);
    if (devices) {
        for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
            void *device = (void *)CFArrayGetValueAtIndex(devices, i);
            stopDevice(device); unregisterCallback(device, frame);
        }
        CFRelease(devices); devices = NULL;
    }
    // Keep the code image loaded: the framework may finish in-flight callbacks.
}
bool WSStartTrackpad(WSContactHandler callback) {
    WSStopTrackpad();
    if (!library) library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY | RTLD_LOCAL);
    if (!library) return false;
    CFArrayRef (*createList)(void) = dlsym(library, "MTDeviceCreateList");
    void (*registerCallback)(void *, FrameCallback) = dlsym(library, "MTRegisterContactFrameCallback");
    void (*startDevice)(void *, int) = dlsym(library, "MTDeviceStart");
    stopDevice = dlsym(library, "MTDeviceStop");
    unregisterCallback = dlsym(library, "MTUnregisterContactFrameCallback");
    if (!createList || !registerCallback || !startDevice || !stopDevice || !unregisterCallback) return false;
    devices = createList();
    if (!devices || CFArrayGetCount(devices) == 0) { if (devices) CFRelease(devices); devices = NULL; return false; }
    pthread_mutex_lock(&handlerLock); handler = callback; pthread_mutex_unlock(&handlerLock);
    for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
        void *device = (void *)CFArrayGetValueAtIndex(devices, i);
        registerCallback(device, frame); startDevice(device, 0);
    }
    return true;
}
