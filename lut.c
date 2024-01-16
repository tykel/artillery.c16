#include <math.h>
#include <stdio.h>
#include <stdint.h>

void lut_sincos_deg(double radius, int start, int end, int step)
{
   printf("data.lut_sincos:\n");
   int printcount = 0;
   for (int d = start; d < end; d += step) {
      double rad = (double)d * M_PI / 180.0;
      double x = radius * cos(rad + M_PI);
      double y = radius * -sin(rad);
      int x_i = x * 256.0;
      uint32_t x_fxp = *(uint32_t *)&x_i;
      int y_i = y * 256.0;
      uint32_t y_fxp = *(uint32_t *)&y_i;
      if (printcount == 0) {
         printf("dw ");
      }
      printf("0x%04hx,0x%04hx,", x_fxp, y_fxp);
      if (printcount++ > 4) {
         printf("\n");
         printcount = 0;
      }
   }
}

int main(int argc, char **argv)
{
   lut_sincos_deg(16.0, 0, 180, 1);
   return 0;
}
