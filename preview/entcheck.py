#!/usr/bin/env python3
"""解析 Mach-O 内嵌代码签名的 entitlements。

签名是由 Apple 的 embedded signature superblob 结构承载的：
  CS_SuperBlob: magic(0xFADE0CC0 BE) + length + count，随后是索引表，
  每条索引 8 字节 (type, offset)；真正要在 offset 处再读 Blob 头 (type, length)。
之前把索引项误当成 Blob 头去读长度，所以越界。
"""
import struct
import sys

CPU = {0x0100000C: "arm64", 0x0100000D | 0x02000000: "arm64e", 0x01000007: "x86_64"}


def slices(data):
    magic = struct.unpack(">I", data[:4])[0]
    if magic in (0xCAFEBABE, 0xCAFEBABF):
        n = struct.unpack(">I", data[4:8])[0]
        out = []
        for i in range(n):
            off = 8 + i * 20
            cputype, _, offset, size, _ = struct.unpack(">IIIII", data[off:off + 20])
            out.append((cputype, data[offset:offset + size]))
        return out
    return [(0, data)]


def find_signature(blob):
    if len(blob) < 32 or struct.unpack("<I", blob[:4])[0] != 0xFEEDFACF:
        return None
    ncmds = struct.unpack("<I", blob[16:20])[0]
    off = 32
    for _ in range(ncmds):
        if off + 8 > len(blob):
            return None
        cmd, size = struct.unpack("<II", blob[off:off + 8])
        if cmd == 0x1D:
            dataoff, datasize = struct.unpack("<II", blob[off + 8:off + 16])
            return blob[dataoff:dataoff + datasize]
        off += max(size, 8)
    return None


def entitlements(sig):
    if not sig or len(sig) < 12:
        return None
    magic, length, count = struct.unpack(">III", sig[:12])
    if magic != 0xFADE0CC0:
        return None
    for i in range(count):
        idx = 12 + i * 8
        slot, offset = struct.unpack(">II", sig[idx:idx + 8])
        # 索引里存的是 slot 编号（CSSLOT_ENTITLEMENTS = 5），
        # blob 真正的魔数 0xFADE7171 在 offset 处的 blob 头里。
        if slot != 5 or offset + 8 > len(sig):
            continue
        blob_magic, blen = struct.unpack(">II", sig[offset:offset + 8])
        if blob_magic != 0xFADE7171:
            continue
        body = sig[offset + 8:offset + blen]
        start = body.find(b"<?xml")
        return body[start:].decode("utf-8", "replace") if start >= 0 else None
    return None


for path in sys.argv[1:]:
    blob = open(path, "rb").read()
    print("=" * 70)
    print(path)
    for cputype, sl in slices(blob):
        ent = entitlements(find_signature(sl))
        print(f"  slice {CPU.get(cputype, hex(cputype))} ({len(sl)} B)")
        print("  " + (ent.strip().replace("\n", "\n  ") if ent else "<no entitlements>"))
