//MD5 implementation by ChatGPT
#include <cstring>
#include <cstdint>

class MD5 {
public:
    MD5() { reset(); }

    void update(const char* input, size_t length) {
        size_t index = (_bitCount / 8) % 64;
        _bitCount += length * 8;

        if (_bitCount < length * 8) {
            _bitCount = 0; // Overflow
        }

        size_t partLen = 64 - index;

        if (length >= partLen) {
            memcpy(&_buffer[index], input, partLen);
            transform(_buffer);

            for (size_t i = partLen; i + 63 < length; i += 64) {
                transform(reinterpret_cast<const uint8_t*>(input) + i);
            }
            index = 0;
        }

        memcpy(&_buffer[index], input + (length - partLen), length - partLen);
    }

    void final(char output[33]) { // 32 hex digits + null terminator
        uint8_t bits[8];
        for (size_t i = 0; i < 8; ++i) {
            bits[i] = (_bitCount >> (8 * i)) & 0xFF;
        }

        update("\x80", 1); // Append '1' bit

        while ((_bitCount / 8 + 8) % 64 != 0) {
            update("\x00", 1); // Pad with '0' bits
        }

        update(reinterpret_cast<char*>(bits), 8); // Append length

        for (size_t i = 0; i < 4; ++i) {
            toHex(_state[i], output + i * 8);
        }
        output[32] = '\0'; // Null terminate the output
    }

private:
    uint32_t _state[4];
    uint8_t _buffer[64];
    uint64_t _bitCount = 0;

    void reset() {
        _state[0] = 0x67452301;
        _state[1] = 0xefcdab89;
        _state[2] = 0x98badcfe;
        _state[3] = 0x10325476;
        _bitCount = 0;
    }

    void transform(const uint8_t* block) {
        uint32_t a = _state[0], b = _state[1], c = _state[2], d = _state[3];
        uint32_t x[16];

        for (size_t i = 0; i < 16; ++i) {
            x[i] = (block[i * 4]) | (block[i * 4 + 1] << 8) | (block[i * 4 + 2] << 16) | (block[i * 4 + 3] << 24);
        }

        // Round 1
        a = ff(a, b, c, d, x[0], 7, 0xd76aa478);
        d = ff(d, a, b, c, x[1], 12, 0xe8c7b756);
        c = ff(c, d, a, b, x[2], 17, 0x242070db);
        b = ff(b, c, d, a, x[3], 22, 0xc1bdceee);
        a = ff(a, b, c, d, x[4], 7, 0xf57c0faf);
        d = ff(d, a, b, c, x[5], 12, 0x4787c62a);
        c = ff(c, d, a, b, x[6], 17, 0xa8304613);
        b = ff(b, c, d, a, x[7], 22, 0xb00327c8);
        a = ff(a, b, c, d, x[8], 7, 0xbf597fc7);
        d = ff(d, a, b, c, x[9], 12, 0x1bcdc9ee);
        c = ff(c, d, a, b, x[10], 17, 0x3d9e8cfe);
        b = ff(b, c, d, a, x[11], 22, 0x4e0811a1);
        a = ff(a, b, c, d, x[12], 7, 0xf57c0faf);
        d = ff(d, a, b, c, x[13], 12, 0x4787c62a);
        c = ff(c, d, a, b, x[14], 17, 0xa8304613);
        b = ff(b, c, d, a, x[15], 22, 0xb00327c8);

        // Round 2
        a = gg(a, b, c, d, x[1], 5, 0x698098d8);
        d = gg(d, a, b, c, x[6], 9, 0x8b44f7af);
        c = gg(c, d, a, b, x[11], 14, 0xffff5bb1);
        b = gg(b, c, d, a, x[0], 20, 0x895cd7be);
        a = gg(a, b, c, d, x[5], 5, 0x6ca6351);
        d = gg(d, a, b, c, x[10], 9, 0x14292967);
        c = gg(c, d, a, b, x[15], 14, 0x4e0811a1);
        b = gg(b, c, d, a, x[4], 20, 0x8b44f7af);
        a = gg(a, b, c, d, x[9], 5, 0x242070db);
        d = gg(d, a, b, c, x[14], 9, 0xc1bdceee);
        c = gg(c, d, a, b, x[3], 14, 0x4787c62a);
        b = gg(b, c, d, a, x[8], 20, 0x698098d8);
        a = gg(a, b, c, d, x[13], 5, 0x8b44f7af);
        d = gg(d, a, b, c, x[2], 9, 0xffff5bb1);
        c = gg(c, d, a, b, x[7], 14, 0x895cd7be);
        b = gg(b, c, d, a, x[12], 20, 0x6ca6351);

        // Round 3
        a = hh(a, b, c, d, x[5], 4, 0xfffa3942);
        d = hh(d, a, b, c, x[8], 11, 0x8771f681);
        c = hh(c, d, a, b, x[11], 16, 0x6ca6351);
        b = hh(b, c, d, a, x[14], 23, 0x8b44f7af);
        a = hh(a, b, c, d, x[1], 4, 0x242070db);
        d = hh(d, a, b, c, x[4], 11, 0xc1bdceee);
        c = hh(c, d, a, b, x[7], 16, 0x4787c62a);
        b = hh(b, c, d, a, x[10], 23, 0x698098d8);
        a = hh(a, b, c, d, x[13], 4, 0x8b44f7af);
        d = hh(d, a, b, c, x[0], 11, 0xffff5bb1);
        c = hh(c, d, a, b, x[3], 16, 0x895cd7be);
        b = hh(b, c, d, a, x[6], 23, 0x6ca6351);
        a = hh(a, b, c, d, x[9], 4, 0x8b44f7af);
        d = hh(d, a, b, c, x[12], 11, 0x242070db);
        
        // Update state
        _state[0] += a;
        _state[1] += b;
        _state[2] += c;
        _state[3] += d;
    }

    static uint32_t ff(uint32_t a, uint32_t b, uint32_t c, uint32_t d, uint32_t x, uint32_t s, uint32_t t) {
        return (a + ((b & c) | (~b & d)) + x + t) << s | (a + ((b & c) | (~b & d)) + x + t) >> (32 - s);
    }
		
		//in proof of concept, the l0 cache has a in addr 0, b in addr 1, c in addr 2, etc..
    static uint32_t gg(uint32_t a, uint32_t b, uint32_t c, uint32_t d, uint32_t x, uint32_t s, uint32_t t) {
        return (a + ((b & d) | (c & ~d)) + x + t) << s | (a + ((b & d) | (c & ~d)) + x + t) >> (32 - s);
    }

    static uint32_t hh(uint32_t a, uint32_t b, uint32_t c, uint32_t d, uint32_t x, uint32_t s, uint32_t t) {
        return (a + (b ^ c ^ d) + x + t) << s | (a + (b ^ c ^ d) + x + t) >> (32 - s);
    }

    void toHex(uint32_t value, char* output) {
        const char* hexDigits = "0123456789abcdef";
        for (int i = 0; i < 8; ++i) {
            output[i] = hexDigits[(value >> (i * 4 + 4)) & 0x0F];
            output[i + 1] = hexDigits[(value >> (i * 4)) & 0x0F];
        }
        output[8] = '\0'; // Null terminate the hex string
    }
};

// Example usage
extern "C" {
    void computeMD5(const char* input, size_t length, char output[33]) {
        MD5 md5;
        md5.update(input, length);
        md5.final(output);
    }
}
