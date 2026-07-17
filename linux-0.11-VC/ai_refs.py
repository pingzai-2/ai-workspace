#!/usr/bin/env python3
import argparse
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote


DEFAULT_PORT = 8765
DEFAULT_SCHEME = "vscode"


DEMO_REFS = [
    ("启动与初始化入口", "init/main.c", 120, 178),
    ("进程与调度核心", "kernel/sched.c", 66, 83),
    ("调度函数", "kernel/sched.c", 130, 178),
    ("任务结构定义", "include/linux/sched.h", 136, 195),
    ("文件系统与缓冲区", "include/linux/fs.h", 95, 159),
    ("块缓冲核心", "fs/buffer.c", 39, 48),
    ("系统调用分发", "kernel/system_call.s", 125, 128),
]


def repo_root() -> Path:
    return Path(__file__).resolve().parent


def parse_ref(text: str):
    if "#L" in text:
        path_text, lines = text.split("#L", 1)
        if "-L" in lines:
            start, end = lines.split("-L", 1)
        elif "-" in lines:
            start, end = lines.split("-", 1)
        else:
            start, end = lines, lines
    else:
        parts = text.rsplit(":", 1)
        if len(parts) != 2 or not parts[1].isdigit():
            raise ValueError(f"bad ref: {text}")
        path_text, start = parts
        end = start

    return path_text, int(start), int(end)


def http_link(path: Path, line: int, port: int, scheme: str) -> str:
    target = f"{path}:{line}:1"
    query = f"target={quote(target, safe='')}&scheme={quote(scheme, safe='')}"
    return f"http://127.0.0.1:{port}/open?{query}"


def editor_url(path: Path, line: int, scheme: str) -> str:
    return f"{scheme}://file{path}:{line}:1"


def open_url(url: str):
    if sys.platform == "darwin":
        subprocess.run(["open", url], check=True)
    elif sys.platform.startswith("linux"):
        subprocess.run(["xdg-open", url], check=True)
    else:
        subprocess.run(["cmd", "/c", "start", "", url], check=True)


def osc8(label: str, url: str) -> str:
    return f"\033]8;;{url}\033\\{label}\033]8;;\033\\"


def short_label(path_text: str, start: int, end: int) -> str:
    name = Path(path_text).name
    if start == end:
        return f"{name}:{start}"
    return f"{name}:{start}-{end}"


def render_item(index, title, path_text, start, end, args):
    path = (repo_root() / path_text).resolve()
    url = http_link(path, start, args.port, args.scheme)
    label = short_label(path_text, start, end)
    visible = label if args.plain else osc8(label, url)

    if args.plain:
        return f"{index:>2}. {title:<18} {label:<22} {url}"
    return f"{index:>2}. {title:<18} {visible}"


def render_menu_item(index, title, path_text, start, end):
    return f"{index:>2}. {short_label(path_text, start, end):<22} {title}"


def open_demo_ref(index: int, scheme: str):
    if index < 1 or index > len(DEMO_REFS):
        raise SystemExit(f"编号超出范围: {index}")
    _, path_text, start, _ = DEMO_REFS[index - 1]
    path = (repo_root() / path_text).resolve()
    open_url(editor_url(path, start, scheme))
    print(f"opened {short_label(path_text, start, start)}")


def cmd_demo(args):
    print("Linux 0.11 代码定位")
    print()
    for i, item in enumerate(DEMO_REFS, 1):
        print(render_item(i, *item, args))
    print()
    if args.plain:
        print("plain: 明文 HTTP 链接，终端识别最稳。")
    else:
        print("osc8: 显示干净；若终端点不开，改用 --plain。")


def cmd_menu(args):
    print("Linux 0.11 代码定位")
    print()
    for i, item in enumerate(DEMO_REFS, 1):
        print(render_menu_item(i, *item))
    print()

    if args.index:
        open_demo_ref(args.index, args.scheme)
        return

    try:
        choice = input("跳转编号> ").strip()
    except EOFError:
        print()
        return
    if not choice:
        return
    if not choice.isdigit():
        raise SystemExit(f"不是编号: {choice}")
    open_demo_ref(int(choice), args.scheme)


def cmd_one(args):
    path_text, start, end = parse_ref(args.ref)
    title = args.title or "代码位置"
    print(render_item(1, title, path_text, start, end, args))


def build_parser():
    parser = argparse.ArgumentParser(description="Clean code-reference shell for terminal click jumps.")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--scheme", default=DEFAULT_SCHEME)
    parser.add_argument("--plain", action="store_true", help="show bare HTTP links instead of OSC8 labels")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("demo", help="show a compact Linux 0.11 reference list")

    menu = sub.add_parser("menu", help="show a clean numbered menu and open the selected ref")
    menu.add_argument("index", nargs="?", type=int)

    one = sub.add_parser("one", help="render one ref such as kernel/sched.c#L66-L83")
    one.add_argument("ref")
    one.add_argument("--title")
    return parser


def main():
    args = build_parser().parse_args()
    if args.cmd == "demo":
        cmd_demo(args)
    elif args.cmd == "menu":
        cmd_menu(args)
    elif args.cmd == "one":
        cmd_one(args)


if __name__ == "__main__":
    main()
