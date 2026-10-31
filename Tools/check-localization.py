#!/usr/bin/env python3
"""Localization lint for CleanMac Pro (no Swift toolchain needed).

Checks:
  1. Every user-facing SwiftUI/AppKit literal goes through L(...)/LK(...):
     Text("..."), Button("..."), Label("..."), Section("..."), Picker("..."),
     DatePicker("..."), TextField("..."), Toggle("..."), .help("..."), alert/panel texts.
  2. Every key used with L("...")/LK("...") exists in fr.lproj, and every
     language has a translation for every key (same format specifiers).
  3. Reports keys that are no longer used.

Usage: python3 Tools/check-localization.py   (exit code 1 on any error)
"""
import glob
import os
import plistlib
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
RES = os.path.join(ROOT, 'Sources/CleanCore/Resources')
LANGS = ['fr', 'en', 'es', 'de']
BS = chr(92)

# Literals that are intentionally not translated (brand names, symbols, verbatim values).
ALLOWED_LITERALS = {'CleanMac Pro', 'BOOM.', 'Macintosh HD', 'CPU', 'RAM', 'v 2.0.0'}
VERBATIM = re.compile(r'^[a-z0-9.-]+$')
UI_CALL = re.compile(r'\b(Text|Button|Label|Section|Picker|DatePicker|TextField|SecureField|Toggle|Link|Menu|GroupBox|navigationTitle|help)\(\s*$')
UI_PROPS = re.compile(r'(messageText|informativeText|addButton\(withTitle|\.prompt|\.title|\.body|\.message)\s*[=:]?\s*$')


def scan_literals(src):
    out = []
    i, n = 0, len(src)

    def parse_string(i):
        j = i + 1
        while j < n:
            c = src[j]
            if c == BS:
                if src[j + 1] == '(':
                    j += 2
                    depth = 1
                    while depth:
                        c2 = src[j]
                        if c2 == '(':
                            depth += 1
                            j += 1
                        elif c2 == ')':
                            depth -= 1
                            j += 1
                        elif c2 == '"':
                            j = parse_string(j)
                        else:
                            j += 1
                    continue
                j += 2
                continue
            if c == '"':
                return j + 1
            j += 1
        raise ValueError('unterminated literal')

    while i < n:
        if src.startswith('//', i):
            while i < n and src[i] != '\n':
                i += 1
        elif src.startswith('/*', i):
            i = src.index('*/', i) + 2
        elif src.startswith('"""', i):
            i = src.index('"""', i + 3) + 3
        elif src[i] == '"':
            e = parse_string(i)
            out.append((i, e, src[i + 1:e - 1]))
            i = e
        else:
            i += 1
    return out


def unescape(raw):
    res, i = [], 0
    while i < len(raw):
        if raw[i] == BS and raw[i + 1] == '(':
            j, depth = i + 2, 1
            while depth:
                depth += {'(': 1, ')': -1}.get(raw[j], 0)
                j += 1
            expr = raw[i + 2:j - 1].strip()
            is_int = re.search(r'(\.count$|^Int\(|\.width$|\.height$|^(selected|days|size|expected|code|start|d|done|total|films|n \+ 1)$|\.itemCount$|\.removedCount$)', expr)
            res.append('%lld' if is_int and not expr.startswith('String(') else '%@')
            i = j
        elif raw[i] == BS:
            res.append({'n': '\n', 't': '\t', '"': '"', BS: BS, "'": "'"}.get(raw[i + 1], raw[i + 1]))
            i += 2
        else:
            res.append(raw[i])
            i += 1
    return ''.join(res)


def parse_strings(path):
    text = open(path, encoding='utf-8').read()
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    d = {}
    for m in re.finditer(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', text, flags=re.M):
        k, v = (re.sub(r'\\(.)', lambda x: {'n': '\n'}.get(x.group(1), x.group(1)), s) for s in m.groups())
        d[k] = v
    return d


def specs(s):
    pat = r'%(?:\d+\$)?[-+ 0#]*(?:\d+)?(?:\.\d+)?(?:ll|l|h|z)?[@dDiuUxXoOfeEgGcCsSp]'
    return sorted(re.sub(r'\d+\$', '', m) for m in re.findall(pat, s))


def flatten(entry, form):
    """Expand %#@var@ with the given plural form ('one' / 'other') of each variable."""
    fmt = entry['NSStringLocalizedFormatKey']
    def sub(m):
        var = entry.get(m.group(1))
        if not isinstance(var, dict) or form not in var:
            raise KeyError(m.group(1))
        return var[form]
    return re.sub(r'%#@(\w+)@', sub, fmt)


def parse_stringsdict(lang):
    path = os.path.join(RES, lang + '.lproj/Localizable.stringsdict')
    if not os.path.exists(path):
        errors.append(f'{lang}.lproj: Localizable.stringsdict missing')
        return {}
    with open(path, 'rb') as fh:
        raw = plistlib.load(fh)
    out = {}
    for key, entry in raw.items():
        try:
            for var, v in entry.items():
                if var == 'NSStringLocalizedFormatKey':
                    continue
                if v.get('NSStringFormatSpecTypeKey') != 'NSStringPluralRuleType':
                    errors.append(f'{lang}.stringsdict: "{key[:50]}" variable {var} is not a plural rule')
                for need in ('one', 'other'):
                    if not str(v.get(need, '')).strip():
                        errors.append(f'{lang}.stringsdict: "{key[:50]}" variable {var} lacks "{need}"')
            one, other = flatten(entry, 'one'), flatten(entry, 'other')
        except KeyError as e:
            errors.append(f'{lang}.stringsdict: "{key[:50]}" references undefined variable {e}')
            continue
        if specs(one) != specs(other):
            errors.append(f'{lang}.stringsdict: one/other format specifiers differ for "{key[:50]}"')
        out[key] = {'one': one, 'other': other}
    return out


errors, warnings = [], []
tables = {l: parse_strings(os.path.join(RES, l + '.lproj/Localizable.strings')) for l in LANGS}
dicts = {l: parse_stringsdict(l) for l in LANGS}
for l in LANGS:
    for k, forms in dicts[l].items():
        if k in tables[l]:
            errors.append(f'{l}: "{k[:60]}" is in both Localizable.strings and .stringsdict')
        tables[l][k] = forms['other']
        for f in forms.values():
            if '(s)' in f or '(e)' in f or '(es)' in f:
                errors.append(f'{l}.stringsdict: legacy plural marker in "{f[:60]}"')
    for k, v in tables[l].items():
        if '(s)' in v:
            errors.append(f'{l}.lproj: "(s)" left in the value of "{k[:60]}": use the stringsdict')
fr = tables['fr']
for l in LANGS:
    for k, forms in dicts[l].items():
        if k in dicts['fr'] and specs(forms['one']) != specs(dicts['fr'][k]['one']):
            errors.append(f'{l}.stringsdict: format specifiers differ from fr for "{k[:60]}"')

used = {}
for path in sorted(glob.glob(os.path.join(ROOT, 'Sources/**/*.swift'), recursive=True)):
    rel = os.path.relpath(path, ROOT)
    if rel.endswith('Localization.swift') or 'CleanMacProSmoke' in rel:
        continue
    src = open(path, encoding='utf-8').read()
    for (s, e, raw) in scan_literals(src):
        line = src.count('\n', 0, s) + 1
        before = src[max(0, s - 40):s]
        if before.endswith('L(') or before.endswith('LK('):
            used.setdefault(raw if before.endswith('LK(') else unescape(raw), []).append(f'{rel}:{line}')
            continue
        if raw in ALLOWED_LITERALS or VERBATIM.match(raw) or not re.search(r'[A-Za-zÀ-ÿ]', raw):
            continue
        line_start = src.rfind('\n', 0, s) + 1
        prefix = src[line_start:s]
        if UI_CALL.search(prefix) or UI_PROPS.search(prefix) or re.search(r'label:\s*$', prefix):
            errors.append(f'{rel}:{line}: literal not localized: "{raw[:60]}"')

for key, locs in sorted(used.items()):
    if key not in fr:
        errors.append(f'{locs[0]}: key missing from fr.lproj: "{key[:70]}"')
for lang in LANGS:
    t = tables[lang]
    for key in fr:
        if not t.get(key, '').strip():
            errors.append(f'{lang}.lproj: missing translation for "{key[:70]}"')
        elif specs(t[key]) != specs(fr[key]):
            errors.append(f'{lang}.lproj: format specifiers differ for "{key[:70]}"')
    for key in t:
        if key not in fr:
            errors.append(f'{lang}.lproj: key not in fr.lproj: "{key[:70]}"')
for key in fr:
    if key not in used:
        warnings.append(f'unused key: "{key[:70]}"')

total = len(fr)
for lang in LANGS:
    done = sum(1 for k in fr if tables[lang].get(k, '').strip())
    print(f'{lang}: {done}/{total} keys ({100 * done // max(total, 1)} %)')
for w in warnings:
    print('warning:', w)
for e in errors:
    print('error:', e)
print(f'{len(used)} keys used in code, {len(errors)} error(s), {len(warnings)} warning(s)')
sys.exit(1 if errors else 0)
