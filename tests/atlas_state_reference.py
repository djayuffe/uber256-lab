"""Independent integer specifications for the state/interpretation atlas batch."""
NAMES = ('HYSTER', 'RESIDUAL', 'SIGNED', 'RUNS', 'BYTEVM', 'REVERSO',
         'BIFURC', 'TERRACE', 'LOOM', 'RING', 'PREFIX', 'RANK', 'BALLOT',
         'TIMELENS', 'EMBOSS', 'SURGERY', 'BRACKET', 'ORBIT', 'CRITICAL')
STATEFUL = {'HYSTER', 'LOOM'}


def signed8(v):
    return ((v + 128) & 255) - 128


def triangle(v):
    return (2 * abs(signed8(v))) & 255


def rotate(v, n, bits):
    mask = (1 << bits) - 1
    v &= mask
    return ((v << n) | (v >> (bits-n))) & mask


def pixel(name, x, y, tick, previous=0):
    """Return one palette index; previous is the same pixel's prior-frame state."""
    t = (2 * tick) & 65535
    if name == 'HYSTER':
        signal = triangle(x+y+t)
        return 255 if signal >= 160 else 0 if signal <= 96 else previous
    if name == 'RESIDUAL':
        v = (((x*y) & 65535) >> 4) + t
        return (triangle(v)-2*triangle(v-8)+triangle(v-16)) & 255
    if name == 'SIGNED':
        a, b = (x+t) & 255, (y+128) & 255
        return ((a*b) >> 8) ^ (((signed8(a)*signed8(b)) >> 8) & 255)
    if name == 'RUNS':
        word = ((((x*321) & 65535) ^ (y & 65535)) + t) & 65535
        changes = sum(((word >> i) ^ (word >> (i+1))) & 1 for i in range(15))
        return ((changes+1)*16) & 255
    if name == 'BYTEVM':
        a = x & 65535
        tape = 0xB39C
        for _ in range(8):
            opcode = tape & 3
            if opcode == 0:
                a = (a+y) & 65535
            elif opcode == 1:
                a ^= t
            elif opcode == 2:
                a = rotate(a, 3, 16)
            else:
                a = (-a) & 65535
            tape >>= 2
        return (a ^ (a >> 8)) & 255
    if name == 'REVERSO':
        a = ((x*257) ^ y) & 65535
        n = (t >> 3) & 15
        for _ in range(min(n, 16-n)):
            a = rotate(a+1973, 5, 16) ^ 0xA53C
        return (a ^ (a >> 8)) & 255
    if name == 'BIFURC':
        parameter = ((x+160+((t >> 3) & 255)) % 320)//2+96
        a = y+128
        for _ in range(16):
            old = a
            a = ((a*(256-a)//256)*parameter)//64
        return (a-old) & 255
    if name == 'TERRACE':
        return max(triangle(x+t), triangle(y-t), triangle(x+y)) & 240
    if name == 'LOOM':
        a = previous
        if (x+t) & 16:
            a = (a+17) & 255
        if (y-t) & 16:
            a = rotate(a, 1, 8)
        return a
    if name == 'RING':
        a = (((x >> 4)*1973) ^ 0x35A7) & 65535
        for _ in range(((t >> 3)+y) & 15):
            # Explicit periodic neighbours, independent of rotate instructions.
            cells = [(a >> i) & 1 for i in range(16)]
            a = sum((cells[(i-1) % 16] ^ cells[(i+1) % 16]) << i
                    for i in range(16))
        return 255 if a & (1 << (x & 15)) else 0
    if name == 'PREFIX':
        return (sum((triangle(y+t+13*k) >> 4)-8
                    for k in range((x & 15)+1)) + y) & 255
    if name == 'RANK':
        values = [((37*k) ^ (y+t)) & 255 for k in range(8)]
        return sorted(values).index(values[x & 7])*32
    if name == 'BALLOT':
        votes = [triangle((x & ~15)+y+t+13*k) >= 128 for k in range(16)]
        mask = sum(vote << (15-k) for k, vote in enumerate(votes))
        n = x & 15
        return rotate(mask, n, 16) & 255
    if name == 'TIMELENS':
        local = t-(((x*y) & 65535) >> 7)
        return triangle(x+(y >> 3)+local) ^ triangle(y+(x >> 3)+local-32)
    if name == 'EMBOSS':
        def change(a):
            v = (((a*y) & 65535) >> 4)+t
            return triangle(v)-triangle(v-8)
        return (96+8*(change(x+1)-change(x))) & 255
    if name == 'SURGERY':
        distance = triangle(t-(y >> 2)) >> 2
        nearest = min((x+distance)**2+y*y, (x-distance)**2+y*y)
        return (255-(nearest >> 3)) if nearest <= 1024 else 0
    if name == 'BRACKET':
        a, b = x+y, y
        stage = (t >> 4) & 3
        if stage >= 1:
            b += a
        if stage >= 2:
            a -= b
        if stage >= 3:
            b -= a
        return triangle(a+t) ^ triangle(b)
    if name == 'ORBIT':
        mask, initial = ((x >> 2)+t) & 255, ((y >> 1)+128) & 255
        state = initial
        for period in range(1, 17):
            state = rotate(state, 1, 8) ^ mask
            if state == initial:
                return period*15
        raise AssertionError('finite byte permutation did not return within 16 steps')
    if name == 'CRITICAL':
        parameter = (x+160)//2+96
        a = (y+t+128) & 255
        b = a ^ 1
        for _ in range(16):
            a = (a*(256-a)//256)*parameter//64
            b = (b*(256-b)//256)*parameter//64
        distance = abs(a-b)
        return 2*distance if 8 <= distance < 96 else 0
    raise ValueError(name)
