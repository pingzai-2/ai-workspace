#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
4CP 设备 RTC 写入独立测试 (1016H-101FH, 功能码 0x10)
=====================================================
绕开 C++ 采集线程/锁/缓存，用最小依赖(pyserial)直接 Modbus RTU 验证：
  1) 从站地址扫描 (--scan)         —— 诊断 "Response not from requested slave"
  2) 基础通信 (读 1000H)            —— 设备是否活着
  3) RTC 读 (读 1016H x10)
  4) RTC 写 (写 1016H x10, FC 0x10)
  5) 读回校验
  6) 多轮统计成功率

用法:
  python3 tools/rtc_write_test.py --scan                 # 先扫描真实从站地址
  python3 tools/rtc_write_test.py                        # 默认 /dev/ttyUSB0 @0xD1(209) 测 RTC
  python3 tools/rtc_write_test.py --slave 1 --rounds 3   # 指定地址、3 轮统计

依赖: pip install pyserial
"""
import argparse
import struct
import sys
import time

try:
    import serial
except ImportError:
    print("[错误] 需要 pyserial，请安装: pip install pyserial")
    sys.exit(1)


# ========== Modbus RTU CRC16 (多项式 0xA001, 低字节在前) ==========
def crc16(buf):
    crc = 0xFFFF
    for b in buf:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc & 1) else (crc >> 1)
    return crc


def mkframe(buf):
    c = crc16(buf)
    return bytes(buf) + bytes([c & 0xFF, (c >> 8) & 0xFF])


EXC = {1: "非法功能码", 2: "非法数据地址", 3: "非法数据值",
       4: "从站设备故障", 5: "确认(长操作)", 6: "从站忙", 8: "存储奇偶差错"}


class Modbus:
    def __init__(self, port, slave, baud, timeout):
        self.slave = slave
        self.ser = serial.Serial(port, baudrate=baud, bytesize=8, parity='N',
                                 stopbits=1, timeout=timeout, xonxoff=False, rtscts=False)
        self.ser.reset_input_buffer()
        self.ser.reset_output_buffer()

    def read_holding(self, addr, qty):
        req = mkframe([self.slave, 0x03, (addr >> 8) & 0xFF, addr & 0xFF,
                       (qty >> 8) & 0xFF, qty & 0xFF])
        resp, dt = self._xact(req, 3 + qty * 2 + 2)
        return req, resp, dt

    def write_multi(self, addr, values):
        qty = len(values)
        data = []
        for v in values:
            data += [(v >> 8) & 0xFF, v & 0xFF]
        req = mkframe([self.slave, 0x10, (addr >> 8) & 0xFF, addr & 0xFF,
                       (qty >> 8) & 0xFF, qty & 0xFF, qty * 2] + data)
        resp, dt = self._xact(req, 8)
        return req, resp, dt

    def _xact(self, req, resp_len):
        self.ser.reset_input_buffer()
        time.sleep(0.005)  # RTU 帧间静默
        self.ser.write(req)
        t0 = time.time()
        resp = self.ser.read(resp_len)
        return resp, (time.time() - t0) * 1000.0

    def parse(self, resp, dt, req):
        """返回 (data_bytes, error)。data_bytes 为去掉 CRC 后的有效载荷(含 slave/FC)。"""
        if not resp:
            return None, f"超时无响应({dt:.0f}ms) — 设备未上电/地址错/线路断 [发:{req.hex()}]"
        if len(resp) < 5:
            return None, f"响应过短({len(resp)}B): {resp.hex()} [发:{req.hex()}]"
        body, crcb = resp[:-2], resp[-2:]
        c = crc16(body)
        if [(c >> 8) & 0xFF, c & 0xFF] != list(crcb):
            return None, f"CRC校验失败 收:{crcb.hex()} 全帧:{resp.hex()}"
        if resp[0] != self.slave:
            return None, f"从站不匹配 收:{resp[0]}(0x{resp[0]:02x}) 期望:{self.slave}"
        if resp[1] & 0x80:
            code = resp[2] if len(resp) >= 3 else -1
            return None, f"Modbus异常 FC=0x{resp[1]:02x} 码={code}({EXC.get(code, '未知')})"
        return body, None

    def close(self):
        self.ser.close()


def scan_slaves(port, baud):
    """扫描 1..247 找有响应的从站。"""
    print(f"=== 扫描从站地址 ({port} @ {baud}) ===")
    print("逐个尝试读 1000H(1个) ... 找到有合法响应的地址\n")
    found = []
    ser = serial.Serial(port, baudrate=baud, bytesize=8, parity='N',
                        stopbits=1, timeout=0.25)
    ser.reset_input_buffer()
    for slave in range(1, 248):
        req = mkframe([slave, 0x03, 0x10, 0x00, 0x00, 0x01])
        ser.reset_input_buffer()
        time.sleep(0.005)
        ser.write(req)
        resp = ser.read(5)  # slave,03,bytecount(=2),data(2) 共7字节; 异常5字节
        if not resp:
            continue
        # 读 1 个寄存器正常响应 = 7 字节，读不够可能是异常(5B)或部分帧
        # 重新读全
        if len(resp) >= 5:
            # 尝试读满 7 字节
            resp += ser.read(2)
        body = resp[:-2] if len(resp) >= 5 else resp
        if len(resp) >= 5:
            c = crc16(resp[:-2])
            if [(c >> 8) & 0xFF, c & 0xFF] == list(resp[-2:]):
                fc = resp[1]
                if fc & 0x80:
                    code = resp[2] if len(resp) >= 3 else -1
                    print(f"  [0x{slave:02X}={slave:3d}] 响应异常码 {code}({EXC.get(code,'未知')}) — 地址存在但拒绝读1000H")
                    found.append(slave)
                elif fc == 0x03 and len(resp) >= 7:
                    val = struct.unpack(">H", resp[3:5])[0]
                    print(f"  [0x{slave:02X}={slave:3d}] ✓ 正常响应! 1000H=0x{val:04X}({val})")
                    found.append(slave)
        sys.stdout.flush()
    ser.close()
    print(f"\n扫描结束。有响应的从站: {found if found else '无(设备未上电/线路断/非Modbus RTU)'}")
    if found:
        print(f"建议: python3 tools/rtc_write_test.py --slave {found[0]}")


def test_rtc(port, slave, baud, timeout, rounds):
    print("=== 4CP RTC 写入测试 ===")
    print(f"串口:{port} | 波特:{baud} 8N1 | 从站:{slave}(0x{slave:02X}) | 超时:{timeout}s | 轮数:{rounds}")
    try:
        m = Modbus(port, slave, baud, timeout)
    except Exception as e:
        print(f"[打开串口失败] {e}")
        print(f"  检查: ls -l {port} ; id ; 确认设备已插入")
        return 2

    rtc = [2026, 8, 6, 14, 30, 0, 4, 0, 0, 0]  # 年月日时分秒 周 format res res
    print(f"待写 RTC(1016H-101FH): {rtc}  => 2026-08-06 14:30:00 周四\n")

    stat = {k: [0, 0] for k in ("comm", "read", "write", "verify")}

    for r in range(1, rounds + 1):
        if rounds > 1:
            print(f"----- 第 {r}/{rounds} 轮 -----")

        # 1) 基础通信: 读 1000H
        req, resp, dt = m.read_holding(0x1000, 1)
        body, err = m.parse(resp, dt, req)
        stat["comm"][1] += 1
        if err is None:
            stat["comm"][0] += 1
            val = struct.unpack(">H", body[3:5])[0]
            print(f"[1] 读 1000H 开关  : OK({dt:.0f}ms) 值=0x{val:04X}({val})")
        else:
            print(f"[1] 读 1000H 开关  : 失败 — {err}")

        # 2) 读当前 RTC
        req, resp, dt = m.read_holding(0x1016, 10)
        body, err = m.parse(resp, dt, req)
        stat["read"][1] += 1
        if err is None:
            stat["read"][0] += 1
            vals = list(struct.unpack(">10H", body[3:23]))
            print(f"[2] 读 1016H 当前  : OK({dt:.0f}ms) {vals}")
        else:
            print(f"[2] 读 1016H 当前  : 失败 — {err}")

        # 3) 写 RTC (FC 0x10)
        req, resp, dt = m.write_multi(0x1016, rtc)
        body, err = m.parse(resp, dt, req)
        stat["write"][1] += 1
        if err is None:
            stat["write"][0] += 1
            print(f"[3] 写 1016H RTC   : OK({dt:.0f}ms)")
        else:
            print(f"[3] 写 1016H RTC   : 失败 — {err}")

        # 4) 读回校验
        time.sleep(0.15)
        req, resp, dt = m.read_holding(0x1016, 10)
        body, err = m.parse(resp, dt, req)
        stat["verify"][1] += 1
        if err is None:
            stat["verify"][0] += 1
            vals = list(struct.unpack(">10H", body[3:23]))
            match = vals[:7] == rtc[:7]
            tag = "✓ 写入生效" if match else "✗ 与写入不符"
            print(f"[4] 读回 1016H     : OK({dt:.0f}ms) {vals} {tag}")
        else:
            print(f"[4] 读回 1016H     : 失败 — {err}")

        if rounds > 1:
            time.sleep(0.8)

    print("\n=== 成功率(成功/总计) ===")
    for k, (s, t) in stat.items():
        print(f"  {k:7s}: {s}/{t}")

    m.close()

    print("\n=== 结论判读 ===")
    if stat["comm"][0] == 0:
        print("• 基础通信全失败 → 设备未上电/地址错/线路断/串口权限。先 --scan 找真实地址。")
    elif stat["write"][0] == 0 and stat["read"][0] > 0:
        print("• 读 OK 但写失败 → 设备不支持写 RTC(1016H) 或功能码 0x10；可尝试拆成单寄存器写(0x06)。")
    elif stat["write"][0] > 0 and stat["verify"][0] < stat["write"][0]:
        print("• 写入返回成功但读回不符 → 设备接收了请求但未真正写入(只读/被保护)。")
    elif stat["write"][0] == stat["write"][1]:
        print("• 写入全部成功 → 设备 RTC 写正常，C++ 端的问题在采集/锁/并发层。")
    return 0


def main():
    ap = argparse.ArgumentParser(description="4CP RTC 写入独立测试")
    ap.add_argument("--port", default="/dev/ttyUSB0")
    ap.add_argument("--slave", default="209", help="从站地址(十进制或0xHEX)，默认209=0xD1")
    ap.add_argument("--baud", type=int, default=9600)
    ap.add_argument("--timeout", type=float, default=1.0, help="单次响应超时(秒)")
    ap.add_argument("--rounds", type=int, default=1, help="重复轮数(统计成功率)")
    ap.add_argument("--scan", action="store_true", help="扫描 1-247 找真实从站地址")
    args = ap.parse_args()

    if args.scan:
        try:
            scan_slaves(args.port, args.baud)
        except Exception as e:
            print(f"[扫描失败] {e}")
            return 2
        return 0

    slave = int(args.slave, 0)
    return test_rtc(args.port, slave, args.baud, args.timeout, args.rounds)


if __name__ == "__main__":
    sys.exit(main())
