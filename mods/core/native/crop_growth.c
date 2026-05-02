#include <stdint.h>

typedef struct VGroundCropTick {
	int32_t x;
	int32_t y;
	int32_t age;
	int32_t moisture;
} VGroundCropTick;

int32_t vground_crop_growth_tick(VGroundCropTick tick) {
	if (tick.moisture <= 0) {
		return tick.age;
	}
	return tick.age + 1;
}
