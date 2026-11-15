"""Independent integer specifications for the six effects from 256.md."""

NAMES = ("XORTUN", "PLASMA", "CAFLAME", "VOXFLOOR", "KALEIDO", "RAYMARCH")
STATEFUL = {"CAFLAME"}


def u16(value):
    return value & 0xFFFF


def signed8(value):
    value &= 0xFF
    return value - 256 if value & 0x80 else value


def triangle(value):
    return (2 * abs(signed8(value))) & 0xFF


def rol8(value, count=1):
    value &= 0xFF
    return ((value << count) | (value >> (8 - count))) & 0xFF


def ror8(value, count=1):
    value &= 0xFF
    return ((value >> count) | (value << (8 - count))) & 0xFF


def pixel(name, x, y, tick, previous=None, offset=0):
    """Return the exact palette index emitted by the selected assembly kernel."""
    t = u16(2 * tick)
    if name == "XORTUN":
        radius = u16(x * x + y * y) >> 6
        return (radius & 0xFF) ^ ((x - y + t) & 0xFF)
    if name == "PLASMA":
        return (triangle(x + t) + triangle(y - t)
                + triangle(x + y + (t >> 1))) & 0xFF
    if name == "CAFLAME":
        if y >= 92:
            seed = u16(x * 1973) ^ t ^ u16(y * 257)
            return (seed ^ (seed >> 8)) & 0xFF
        previous = previous or bytes(65536)
        neighbours = rol8(previous[offset + 2559] ^ previous[offset + 2561])
        return ror8(neighbours + previous[offset + 2560])
    if name == "VOXFLOOR":
        shift = (y + 100) >> 5
        value = u16((u16(x * x) >> shift) + u16(y << 3) + t)
        return (value ^ (value >> 8)) & 0xFF
    if name == "KALEIDO":
        cross = u16(2 * abs(x) * abs(y))
        radius = u16(x * x + y * y) >> 5
        return u16((radius ^ cross) + t) & 0xFF
    if name == "RAYMARCH":
        depth = t & 63
        for remaining in range(8, 0, -1):
            shift = signed8(triangle(depth + t)) >> 3
            distance = u16((x + shift) * (x + shift) + y * y)
            if distance < 1600:
                return (remaining * 32 + depth) & 0xFF
            depth = u16(depth + 8)
        return 0
    raise ValueError(name)


def frame(name, tick, previous=None):
    old = bytearray(65536)
    if previous:
        old[:len(previous)] = previous
    image = bytearray(64000)
    for offset in range(64000):
        image[offset] = pixel(
            name, offset % 320 - 160, offset // 320 - 100,
            tick, old, offset,
        )
    return bytes(image)
