#!/usr/bin/env python3
"""Add animated input guidance to a real recording, then make the README GIF."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def timestamp(seconds):
    ticks = round(seconds * 100)
    return f"{ticks // 360000}:{ticks // 6000 % 60:02}:{ticks // 100 % 60:02}.{ticks % 100:02}"


def safe(text):
    return text.replace('\\', '\\\\').replace('{', '').replace('}', '').replace('\n', r'\N')


def render(raw, events_path, output, gif, offset):
    events = [json.loads(line) for line in events_path.read_text().splitlines()]
    duration = events[-1]['time'] + offset
    keys = [('W', 40, 58), ('A', 110, 58), ('S', 180, 58), ('D', 250, 58),
            ('ENTER', 330, 106), ('0', 448, 58), ('SPACE', 518, 114), ('1', 644, 58)]
    header = """[Script Info]
ScriptType: v4.00+
PlayResX: 1440
PlayResY: 1080
WrapStyle: 2
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Title,DejaVu Sans,28,&H006BC5F1,&H006BC5F1,&H00101927,&H00000000,-1,0,0,0,100,100,1,0,1,0,0,7,40,40,0,1
Style: Body,DejaVu Sans,23,&H00D7C5B7,&H00D7C5B7,&H00101927,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,40,40,0,1
Style: Key,DejaVu Sans,22,&H00DCEDF5,&H00DCEDF5,&H00101927,&H00000000,-1,0,0,0,100,100,0,0,1,0,0,5,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    lines = [header]

    def event(start, end, style, text, layer=1):
        lines.append(f'Dialogue: {layer},{timestamp(start)},{timestamp(end)},{style},,0,0,0,,{text}\n')

    def rect(start, end, x, y, w, h, colour, layer=0, fade=False):
        tags = f'\\an7\\pos({x},{y})\\p1\\1c&H{colour}&'
        if fade:
            tags += '\\fad(70,180)'
        event(start, end, 'Key', '{' + tags + f'}}m 0 0 l {w} 0 l {w} {h} l 0 {h}', layer)

    rect(0, duration, 0, 900, 1440, 3, '6BC5F1')
    for key, x, width in keys:
        rect(0, duration, x, 1016, width, 44, '45352B')
        event(0, duration, 'Key', f'{{\\pos({x + width / 2},1038)}}{key}')
    event(0, duration, 'Body', r'{\pos(822,1026)\fs20}PREVIEW   >   CONFIRM   >   RESOLVE')
    for i, item in enumerate(events[:-1]):
        start = 0 if i == 0 else item['time'] + offset
        end = events[i + 1]['time'] + offset
        event(start, end, 'Title', r'{\pos(40,919)\fad(100,80)}' + safe(item['title']))
        event(start, end, 'Body', r'{\pos(40,965)\fad(100,80)}' + safe(item['detail']))
        for key, x, width in keys:
            if item['key'] == key:
                stop = min(end, start + 1.3)
                rect(start, stop, x, 1016, width, 44, '6BC5F1', 2, True)
                event(start, stop, 'Key', f'{{\\pos({x + width / 2},1038)\\1c&H271910&\\fad(70,180)\\fscx115\\fscy115\\t(0,180,\\fscx100\\fscy100)}}{key}', 3)
    inset_start = next(item['time'] + offset for item in events if item['title'] == '01 / PREVIEW A MOVE')
    event(inset_start, duration, 'Body', r'{\pos(40,287)\fs18\1c&H006BC5F1&}MOVEMENT DETAIL')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='premove-edit-') as temp:
        ass = Path(temp) / 'guidance.ass'
        ass.write_text(''.join(lines))
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'warning', '-i', str(raw),
                        '-t', str(duration), '-filter_complex',
                        '[0:v]split[base][detail];'
                        '[base]pad=1440:1080:0:0:color=0x271910[canvas];'
                        '[detail]crop=132:180:418:390,scale=264:360:flags=neighbor,'
                        'pad=268:364:2:2:color=0xf1c56b[inset];'
                        f"[canvas][inset]overlay=30:320:enable='gte(t,{inset_start})'[zoomed];"
                        f'[zoomed]ass={ass}[guided]', '-map', '[guided]', '-map', '0:a?',
                        '-c:v', 'libx264', '-preset', 'fast', '-crf', '21', '-pix_fmt', 'yuv420p',
                        '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', str(output)], check=True)
        by_title = {item['title']: item['time'] + offset for item in events}
        spans = [(by_title['01 / PREVIEW A MOVE'], by_title['05 / ADD AN ATTACK']),
                 (by_title['07 / LOCK YOUR PLAN'], by_title['OPPONENT PLANS PRIVATELY']),
                 (by_title['08 / BOTH PLANS LOCKED'], by_title['PLAN. CONFIRM. RESOLVE.'])]
        filters = [f'[0:v]trim=start={a}:end={b},setpts=PTS-STARTPTS[v{i}]' for i, (a, b) in enumerate(spans)]
        inputs = ''.join(f'[v{i}]' for i in range(len(spans)))
        filters.append(inputs + f'concat=n={len(spans)}:v=1:a=0,fps=15,scale=960:-1:flags=lanczos,split[a][b]')
        filters.append('[a]palettegen=stats_mode=diff[p]')
        filters.append('[b][p]paletteuse=dither=bayer:bayer_scale=3[out]')
        subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'warning', '-i', str(output),
                        '-filter_complex', ';'.join(filters), '-map', '[out]', '-loop', '0', str(gif)], check=True)
    print(f'Video: {output} ({duration:.1f}s); GIF: {gif}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('raw', type=Path)
    parser.add_argument('events', type=Path)
    parser.add_argument('--offset', type=float, default=0.7, help='Capture lead-in before the input timeline, in seconds.')
    parser.add_argument('--output', type=Path, default=Path('assets/presentation/premove-demo.mp4'))
    parser.add_argument('--gif', type=Path, default=Path('docs/media/premove-gameplay.gif'))
    args = parser.parse_args()
    render(args.raw, args.events, args.output, args.gif, args.offset)
