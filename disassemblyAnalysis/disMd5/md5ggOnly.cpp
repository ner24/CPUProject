#include <cstdint>
#include <iostream>

//in proof of concept, the l0 cache has a in addr 0, b in addr 1, c in addr 2, etc..
//word width set to 16 bits (8 bit gave output of 0 which will make it harder to spot issues in simulation)
uint16_t gg(uint16_t a, uint16_t b, uint16_t c, uint16_t d, uint16_t x, uint16_t s, uint16_t t) {
  return (a + ((b & d) | (c & ~d)) + x + t) << s | (a + ((b & d) | (c & ~d)) + x + t) >> (16 - s);
}

uint16_t gg_no_shift(uint16_t a, uint16_t b, uint16_t c, uint16_t d, uint16_t x, uint16_t s, uint16_t t) {
  return (a + ((b & d) | (c & ~d)) + x + t);
}

int main() {
  //NOTE: the gg arg data must match with the allocator model l0 cache
  std::cout << (int) gg_no_shift(1, 2, 3, 4, 5, 6, 7) << std::endl;
  std::cout << (int) gg(1, 2, 3, 4, 5, 6, 7) << std::endl;
  //Outputs:
  // 8 bit word: 0
  //16 bit word: 1024
  //32 bit word: 1024
}
