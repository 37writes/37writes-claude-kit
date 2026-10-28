"""두 색의 WCAG 대비를 계산한다. /kit:design이 글자색·배경색을 정할 때 사용.

사용:
  contrast.py <글자색> <배경색> [<글자색> <배경색> ...]
  - 색은 #rgb, #rrggbb (# 생략 가능)
  - 본문 4.5:1, 큰 글자(24px 이상, 굵은 19px 이상)·아이콘·입력창 테두리 3:1 이상이 기준
  - 종료 코드: 모두 4.5:1 이상이면 0, 하나라도 못 미치면 1 (3:1 기준인 쌍은 출력의 등급을 본다)
"""
import sys

import kitlib  # noqa: F401  (윈도우 콘솔 utf-8 출력 설정)


def parse(color):
    h = color.strip().lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    try:
        if len(h) != 6:
            raise ValueError
        return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    except ValueError:
        raise ValueError(f"색 형식이 아닙니다: {color}") from None


def luminance(rgb):
    def channel(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(fg, bg):
    a, b = sorted((luminance(parse(fg)), luminance(parse(bg))), reverse=True)
    return (a + 0.05) / (b + 0.05)


def main(args):
    if not args or len(args) % 2:
        print(__doc__.strip())
        return 2
    failed = False
    for fg, bg in zip(args[::2], args[1::2]):
        try:
            r = ratio(fg, bg)
        except ValueError as e:
            print(e)
            return 2
        grade = "본문 OK" if r >= 4.5 else "큰 글자만" if r >= 3 else "부족"
        failed |= r < 4.5
        print(f"{fg} on {bg}: {r:.2f}:1  {grade}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
