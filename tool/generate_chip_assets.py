#!/usr/bin/env python3
"""Generate prebuilt chip assets from PK2DeviceFile.dat.

Outputs:
- android/src/main/assets/chip_catalog.csv
- android/src/main/assets/chip_detect.json
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import struct
import subprocess
from dataclasses import dataclass
from pathlib import Path


DEFAULT_PART_TRAILER_BYTES = 0
LEGACY_PART_TRAILER_BYTES = 8


class ParseError(Exception):
    pass


class Reader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.pos = 0

    def _take(self, n: int) -> bytes:
        end = self.pos + n
        if end > len(self.data):
            raise ParseError("Unexpected EOF")
        chunk = self.data[self.pos : end]
        self.pos = end
        return chunk

    def read_u8(self) -> int:
        return self._take(1)[0]

    def read_bool(self) -> bool:
        return self.read_u8() != 0

    def read_i16(self) -> int:
        return struct.unpack("<H", self._take(2))[0]

    def read_i32(self) -> int:
        return struct.unpack("<I", self._take(4))[0]

    def read_f32(self) -> float:
        return struct.unpack("<f", self._take(4))[0]

    def read_pk_string(self) -> str:
        file_byte = self.read_u8()
        length = file_byte & 0x7F
        if (file_byte & 0x80) != 0:
            length += self.read_u8() * 0x80
        if length <= 0:
            return ""
        return self._take(length).decode("latin-1", errors="replace")

    def skip(self, n: int) -> None:
        self._take(n)


@dataclass
class Family:
    family_id: int
    family_type: int
    search_priority: int
    family_name: str
    part_detect: bool
    prog_entry_script: int
    prog_entry_vpp_script: int
    prog_exit_script: int
    read_dev_id_script: int
    device_id_mask: int
    blank_value: int
    prog_mem_shift: int
    vpp: float
    bytes_per_location: int
    ee_mem_bytes_per_word: int


@dataclass
class Part:
    part_name: str
    family: int
    device_id: int
    program_mem: int
    ee_mem: int


@dataclass
class Script:
    script_number: int
    script: list[int]


@dataclass
class Parsed:
    families: list[Family]
    parts: list[Part]
    scripts: list[Script]


def is_sane_part_name(name: str) -> bool:
    if not name:
        return False
    if name == "UNSUPPORTED PART":
        return True
    if not (
        name.startswith("PIC")
        or name.startswith("DSPIC")
        or name.startswith("MCP")
        or name.startswith("AT")
    ):
        return False
    return all(32 <= ord(ch) <= 126 for ch in name)


def parse_binary(raw: bytes, part_trailer_bytes: int) -> Parsed:
    r = Reader(raw)

    _version_major = r.read_i32()
    _version_minor = r.read_i32()
    _version_dot = r.read_i32()
    _version_notes = r.read_pk_string()
    number_families = r.read_i32()
    number_parts = r.read_i32()
    number_scripts = r.read_i32()
    _compatibility = r.read_u8()
    r.read_u8()
    r.read_i16()
    r.read_i32()

    families: list[Family] = []
    for _ in range(number_families):
        family_id = r.read_i16()
        family_type = r.read_i16()
        search_priority = r.read_i16()
        family_name = r.read_pk_string()
        prog_entry_script = r.read_i16()
        prog_exit_script = r.read_i16()
        read_dev_id_script = r.read_i16()
        device_id_mask = r.read_i32()
        blank_value = r.read_i32()
        bytes_per_location = r.read_u8()
        _address_increment = r.read_u8()
        part_detect = r.read_bool()
        prog_entry_vpp_script = r.read_i16()
        r.read_i16()
        ee_mem_bytes_per_word = r.read_u8()
        _ee_mem_addr_increment = r.read_u8()
        _user_id_hex_bytes = r.read_u8()
        _user_id_bytes = r.read_u8()
        _prog_mem_hex_bytes = r.read_u8()
        _ee_mem_hex_bytes = r.read_u8()
        prog_mem_shift = r.read_u8()
        _test_memory_start = r.read_i32()
        _test_memory_length = r.read_i16()
        vpp = r.read_f32()

        families.append(
            Family(
                family_id=family_id,
                family_type=family_type,
                search_priority=search_priority,
                family_name=family_name,
                part_detect=part_detect,
                prog_entry_script=prog_entry_script,
                prog_entry_vpp_script=prog_entry_vpp_script,
                prog_exit_script=prog_exit_script,
                read_dev_id_script=read_dev_id_script,
                device_id_mask=device_id_mask,
                blank_value=blank_value,
                prog_mem_shift=prog_mem_shift,
                vpp=vpp,
                bytes_per_location=bytes_per_location,
                ee_mem_bytes_per_word=ee_mem_bytes_per_word,
            )
        )

    parts: list[Part] = []
    sane_count = 0
    for _ in range(number_parts):
        part_name = r.read_pk_string().strip().upper()
        family = r.read_i16()
        device_id = r.read_i32()
        program_mem = r.read_i32()
        ee_mem = r.read_i16()

        r.read_i32()  # eeAddr
        r.read_u8()  # configWords
        r.read_i32()  # configAddr
        r.read_u8()  # userIDWords
        r.read_i32()  # userIDAddr
        r.read_i32()  # bandGapMask
        for _ in range(8):
            r.read_i16()
        for _ in range(8):
            r.read_i16()
        r.read_i16()  # cpMask
        r.read_u8()  # cpConfig
        r.read_bool()  # osscalSave
        r.read_i32()  # ignoreAddress
        r.read_f32()  # vddMin
        r.read_f32()  # vddMax
        r.read_f32()  # vddErase
        r.read_u8()  # calibrationWords
        r.read_i16()  # chipEraseScript
        r.read_i16()  # progMemAddrSetScript
        r.read_u8()  # progMemAddrBytes
        r.read_i16()  # progMemRdScript
        r.read_i16()  # progMemRdWords
        r.read_i16()  # eeRdPrepScript
        r.read_i16()  # eeRdScript
        r.read_i16()  # eeRdLocations
        r.read_i16()  # userIDRdPrepScript
        r.read_i16()  # userIDRdScript
        r.read_i16()  # configRdPrepScript
        r.read_i16()  # configRdScript
        r.read_i16()  # progMemWrPrepScript
        r.read_i16()  # progMemWrScript
        r.read_i16()  # progMemWrWords
        r.read_u8()  # progMemPanelBufs
        r.read_i32()  # progMemPanelOffset
        r.read_i16()  # eeWrPrepScript
        r.read_i16()  # eeWrScript
        r.read_i16()  # eeWrLocations
        r.read_i16()  # userIDWrPrepScript
        r.read_i16()  # userIDWrScript
        r.read_i16()  # configWrPrepScript
        r.read_i16()  # configWrScript
        r.read_i16()  # oscCalRdScript
        r.read_i16()  # oscCalWrScript
        r.read_i16()  # dpMask
        r.read_bool()  # writeCfgOnErase
        r.read_bool()  # blankCheckSkipUsrIDs
        r.read_i16()  # ignoreBytes
        r.read_i16()  # chipErasePrepScript
        r.read_i32()  # bootFlash
        r.read_i16()  # config9Mask
        r.read_i16()  # config9Blank
        r.read_i16()  # progMemEraseScript
        r.read_i16()  # eeMemEraseScript
        r.read_i16()  # configMemEraseScript
        r.read_i16()  # reserved1EraseScript
        r.read_i16()  # reserved2EraseScript
        r.read_i16()  # testMemoryRdScript
        r.read_i16()  # testMemoryRdWords
        r.read_i16()  # eeRowEraseScript
        r.read_i16()  # eeRowEraseWords
        r.read_bool()  # exportToMplab

        for _ in range(15):
            r.read_i16()
        r.read_i16()  # lvpScript
        r.skip(part_trailer_bytes)

        parts.append(
            Part(
                part_name=part_name,
                family=family,
                device_id=device_id,
                program_mem=program_mem,
                ee_mem=ee_mem,
            )
        )
        if is_sane_part_name(part_name):
            sane_count += 1

    scripts: list[Script] = []
    for _ in range(number_scripts):
        script_number = r.read_i16()
        _script_name = r.read_pk_string()
        _script_version = r.read_i16()
        r.read_i32()  # unused
        script_length = r.read_i16()
        words: list[int] = []
        for _ in range(script_length):
            words.append(r.read_i16())
        _comment = r.read_pk_string()
        if script_number > 0 and script_length > 0:
            scripts.append(Script(script_number=script_number, script=[w & 0xFF for w in words]))

    parsed_parts = len(parts)
    if parsed_parts < min(200, number_parts // 2) or sane_count * 2 < parsed_parts:
        raise ParseError("Device file parsed with invalid part-name layout")

    return Parsed(families=families, parts=parts, scripts=scripts)


def parse_device_file(raw: bytes) -> Parsed:
    first_error: Exception | None = None
    for trailer in (DEFAULT_PART_TRAILER_BYTES, LEGACY_PART_TRAILER_BYTES):
        try:
            return parse_binary(raw, trailer)
        except Exception as exc:
            if first_error is None:
                first_error = exc
    raise ParseError(f"Failed to parse device file: {first_error}")


def reverse16_bits(value: int) -> int:
    result = 0
    current = value & 0xFFFF
    for _ in range(16):
        result = (result << 1) | (current & 1)
        current >>= 1
    return result & 0xFFFF


def normalize_device_id(raw_id: int, family: Family) -> int:
    device_id = raw_id
    for _ in range(max(0, family.prog_mem_shift)):
        device_id >>= 1

    device_id &= family.device_id_mask

    if family.family_name.startswith("EEPROMS") and family.device_id_mask == 0x00FFFFFF:
        device_id = ((device_id << 16) & 0x00FF0000) | (device_id & 0x0000FF00) | ((device_id >> 16) & 0x000000FF)

    if family.family_name.startswith("Midrange/1.8V Min MSB1st"):
        device_id = reverse16_bits(device_id)
        device_id >>= 2
    elif family.family_name.startswith("PIC18/PIC18F MSB1st"):
        device_id = reverse16_bits(device_id)

    return device_id & family.device_id_mask


def format_hex(value: int) -> str:
    return f"0x{value:X}"


def format_bytes(value: int) -> str:
    if value <= 0:
        return "0 B"
    if value >= 1024 * 1024:
        return f"{value / (1024 * 1024):.1f} MB"
    if value >= 1024:
        return f"{value / 1024:.1f} KB"
    return f"{value} B"


def format_ram_bytes(value: int) -> str:
    if value <= 0:
        return "Unknown"
    if value >= 1024:
        return f"{value / 1024:.1f} KB"
    return f"{value} B"


def _normalize_model_name(name: str) -> str:
    return name.strip().upper().replace("_", "")


def _resolve_gputils_lkr_dir(explicit_dir: Path | None = None) -> Path | None:
    if explicit_dir is not None:
        return explicit_dir if explicit_dir.exists() else None

    env_dir = os.environ.get("GPUTILS_LKR_DIR", "").strip()
    if env_dir:
        path = Path(env_dir)
        if path.exists():
            return path

    common_paths = [
        Path("/opt/homebrew/Cellar/gputils"),
        Path("/usr/local/Cellar/gputils"),
        Path("/opt/homebrew/share/gputils/lkr"),
        Path("/usr/local/share/gputils/lkr"),
    ]

    for base in common_paths:
        if not base.exists():
            continue
        if base.is_dir() and base.name == "lkr":
            return base
        versions = sorted((p for p in base.iterdir() if p.is_dir()), reverse=True)
        for version_dir in versions:
            lkr = version_dir / "share" / "gputils" / "lkr"
            if lkr.exists():
                return lkr

    try:
        brew_prefix = subprocess.check_output(["brew", "--prefix", "gputils"], text=True).strip()
        lkr = Path(brew_prefix) / "share" / "gputils" / "lkr"
        if lkr.exists():
            return lkr
    except Exception:
        pass

    return None


def _merge_intervals(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if not intervals:
        return []
    intervals = sorted(intervals)
    merged: list[tuple[int, int]] = [intervals[0]]
    for start, end in intervals[1:]:
        last_start, last_end = merged[-1]
        if start <= last_end + 1:
            merged[-1] = (last_start, max(last_end, end))
        else:
            merged.append((start, end))
    return merged


def load_ram_overrides(ram_overrides_csv: Path) -> dict[str, str]:
    ram_overrides: dict[str, str] = {}
    if not ram_overrides_csv.exists():
        return ram_overrides

    with ram_overrides_csv.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            model = _normalize_model_name(row.get("model") or "")
            ram_size = (row.get("ramSize") or "").strip()
            if model and ram_size:
                ram_overrides[model] = ram_size
    return ram_overrides


def load_gputils_ram_overrides(gputils_lkr_dir: Path | None) -> dict[str, str]:
    lkr_dir = _resolve_gputils_lkr_dir(gputils_lkr_dir)
    if lkr_dir is None:
        return {}

    bank_pattern = re.compile(
        r"^(DATABANK|ACCESSBANK|SHAREBANK)\s+NAME=([A-Za-z0-9_]+)\s+START=0x([0-9A-Fa-f]+)\s+END=0x([0-9A-Fa-f]+)(.*)$"
    )
    ram_overrides: dict[str, str] = {}

    for lkr in lkr_dir.glob("*_g.lkr"):
        base = lkr.stem
        if not base.endswith("_g"):
            continue
        chip_base = base[:-2]
        if not chip_base:
            continue

        intervals: list[tuple[int, int]] = []
        try:
            lines = lkr.read_text(encoding="utf-8", errors="ignore").splitlines()
        except Exception:
            continue

        for raw_line in lines:
            line = raw_line.strip()
            if not line or line.startswith("//"):
                continue
            match = bank_pattern.match(line)
            if not match:
                continue
            bank_type, name, start_hex, end_hex, tail = match.groups()
            if "PROTECTED" in tail.upper():
                continue
            if name.lower().startswith("sfr") or name.lower().endswith("sfr"):
                continue

            try:
                start = int(start_hex, 16)
                end = int(end_hex, 16)
            except ValueError:
                continue
            if end < start:
                continue
            intervals.append((start, end))

        merged = _merge_intervals(intervals)
        total = sum((end - start + 1) for start, end in merged)
        if total <= 0:
            continue

        model = _normalize_model_name(f"PIC{chip_base}")
        ram_overrides[model] = format_ram_bytes(total)

    return ram_overrides


def build_assets(parsed: Parsed, ram_overrides: dict[str, str] | None = None) -> tuple[list[list[str]], dict]:
    ram_overrides = ram_overrides or {}
    family_by_id = {f.family_id: f for f in parsed.families}

    csv_rows: list[list[str]] = [["family", "model", "deviceId", "flashSize", "ramSize", "eepromSize"]]
    seen_model_in_family: set[tuple[str, str]] = set()

    detect_families = []
    for f in parsed.families:
        detect_families.append(
            {
                "familyId": f.family_id,
                "familyType": f.family_type,
                "searchPriority": f.search_priority,
                "familyName": f.family_name,
                "partDetect": f.part_detect,
                "progEntryScript": f.prog_entry_script,
                "progEntryVppScript": f.prog_entry_vpp_script,
                "progExitScript": f.prog_exit_script,
                "readDevIdScript": f.read_dev_id_script,
                "deviceIdMask": f.device_id_mask,
                "blankValue": f.blank_value,
                "progMemShift": f.prog_mem_shift,
                "vpp": f.vpp,
                "bytesPerLocation": f.bytes_per_location,
                "eeMemBytesPerWord": f.ee_mem_bytes_per_word,
            }
        )

    detect_parts = []
    seen_detect_part: set[tuple[int, int, str]] = set()

    for p in parsed.parts:
        model = p.part_name.strip().upper()
        if not model or model == "UNSUPPORTED PART":
            continue

        family = family_by_id.get(p.family)
        if family is None:
            continue

        masked_id = normalize_device_id(p.device_id, family)
        if masked_id in (0, 0xFFFF):
            continue

        family_name = family.family_name or f"Family {p.family}"
        key = (family_name, model)
        if key not in seen_model_in_family:
            seen_model_in_family.add(key)
            flash_bytes = int(p.program_mem) * int(max(1, family.bytes_per_location))
            eeprom_bytes = int(p.ee_mem) * int(max(1, family.ee_mem_bytes_per_word))
            ram_size = ram_overrides.get(model)
            if not ram_size and model.startswith("PIC18LF"):
                ram_size = ram_overrides.get("PIC18F" + model[len("PIC18LF"):])
            if not ram_size and model.startswith("PIC16LF"):
                ram_size = ram_overrides.get("PIC16F" + model[len("PIC16LF"):])
            if not ram_size and model.startswith("PIC12LF"):
                ram_size = ram_overrides.get("PIC12F" + model[len("PIC12LF"):])
            if not ram_size and model.startswith("PIC10LF"):
                ram_size = ram_overrides.get("PIC10F" + model[len("PIC10LF"):])
            if not ram_size:
                ram_size = "Unknown"
            csv_rows.append(
                [
                    family_name,
                    model,
                    format_hex(masked_id),
                    format_bytes(flash_bytes),
                    ram_size,
                    format_bytes(eeprom_bytes),
                ]
            )

        detect_key = (p.family, masked_id, model)
        if detect_key not in seen_detect_part:
            seen_detect_part.add(detect_key)
            detect_parts.append({"model": model, "familyId": p.family, "deviceId": masked_id})

    detect_scripts = [{"scriptNumber": s.script_number, "script": s.script} for s in parsed.scripts if s.script_number > 0 and s.script]

    detect_json = {
        "families": detect_families,
        "parts": detect_parts,
        "scripts": detect_scripts,
    }

    return csv_rows, detect_json


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    default_in = Path("/Users/an7or/MyWork/pk2cmd/PK2DeviceFile.dat")
    default_catalog = repo_root / "android" / "src" / "main" / "assets" / "chip_catalog.csv"
    default_detect = repo_root / "android" / "src" / "main" / "assets" / "chip_detect.json"
    default_ram_overrides = repo_root / "tool" / "chip_ram_overrides.csv"
    default_gputils_lkr = None

    parser = argparse.ArgumentParser(description="Generate chip catalog assets from PK2DeviceFile.dat")
    parser.add_argument("--input", type=Path, default=default_in, help="Path to PK2DeviceFile.dat")
    parser.add_argument("--catalog-out", type=Path, default=default_catalog, help="Output CSV path")
    parser.add_argument("--detect-out", type=Path, default=default_detect, help="Output JSON path")
    parser.add_argument(
        "--ram-overrides",
        type=Path,
        default=default_ram_overrides,
        help="Optional CSV map: model,ramSize",
    )
    parser.add_argument(
        "--gputils-lkr-dir",
        type=Path,
        default=default_gputils_lkr,
        help="Optional gputils lkr directory for automatic RAM extraction",
    )
    args = parser.parse_args()

    raw = args.input.read_bytes()
    parsed = parse_device_file(raw)
    ram_overrides = load_gputils_ram_overrides(args.gputils_lkr_dir)
    ram_overrides.update(load_ram_overrides(args.ram_overrides))

    csv_rows, detect_json = build_assets(parsed, ram_overrides)

    args.catalog_out.parent.mkdir(parents=True, exist_ok=True)
    args.detect_out.parent.mkdir(parents=True, exist_ok=True)

    with args.catalog_out.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(csv_rows)

    with args.detect_out.open("w", encoding="utf-8") as f:
        json.dump(detect_json, f, indent=2)

    print(f"Generated {args.catalog_out} ({len(csv_rows) - 1} models)")
    print(f"Generated {args.detect_out} ({len(detect_json['families'])} families, {len(detect_json['parts'])} parts, {len(detect_json['scripts'])} scripts)")
    known_ram = sum(1 for row in csv_rows[1:] if row[4].strip().lower() not in ("unknown", "n/a", ""))
    print(f"RAM coverage: {known_ram}/{len(csv_rows) - 1} models")


if __name__ == "__main__":
    main()
