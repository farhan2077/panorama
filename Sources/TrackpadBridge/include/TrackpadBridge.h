#pragma once
#include <stdbool.h>
/// Reports only contact count and centroid; raw touch data never leaves this adapter.
typedef void (*WSContactHandler)(int count, double x, double y);
bool WSStartTrackpad(WSContactHandler handler);
void WSStopTrackpad(void);
