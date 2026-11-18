# Convert an official Gherkin .ast.ndjson file into the canonical text that
# the dream_test conformance test renders from a parsed Feature.
import json, sys

def q(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'

out = []
def emit(depth, text):
    out.append('  ' * depth + text)

def tags(depth, node):
    t = [x['name'][1:] for x in node.get('tags', [])]
    if t:
        emit(depth, 'tags ' + ' '.join(q(x) for x in t))

def desc(depth, node):
    d = node.get('description', '')
    if d:
        emit(depth, 'description ' + q(d))

def rows(depth, label, rs):
    for r in rs:
        emit(depth, label + ' ' + ' '.join(q(c['value']) for c in r['cells']))

def steps(depth, node):
    for s in node['steps']:
        emit(depth, 'step ' + q(s['keyword'].strip()) + ' ' + q(s['text']))
        if 'docString' in s:
            d = s['docString']
            media = q(d['mediaType']) if d.get('mediaType') else 'none'
            emit(depth + 1, 'docstring ' + media + ' ' + q(d['content']))
        if 'dataTable' in s:
            emit(depth + 1, 'table')
            rows(depth + 2, 'row', s['dataTable']['rows'])

def background(depth, b):
    emit(depth, 'background ' + q(b['name']))
    desc(depth + 1, b)
    steps(depth + 1, b)

def scenario(depth, s):
    emit(depth, 'scenario ' + q(s['keyword']) + ' ' + q(s['name']))
    tags(depth + 1, s)
    desc(depth + 1, s)
    steps(depth + 1, s)
    for e in s['examples']:
        emit(depth + 1, 'examples ' + q(e['name']))
        tags(depth + 2, e)
        desc(depth + 2, e)
        if 'tableHeader' in e:
            rows(depth + 2, 'header', [e['tableHeader']])
            rows(depth + 2, 'row', e.get('tableBody', []))

def children(depth, cs):
    for c in cs:
        if 'background' in c: background(depth, c['background'])
        elif 'scenario' in c: scenario(depth, c['scenario'])
        elif 'rule' in c:
            r = c['rule']
            emit(depth, 'rule ' + q(r['name']))
            tags(depth + 1, r)
            desc(depth + 1, r)
            children(depth + 1, r['children'])

doc = json.loads(open(sys.argv[1], encoding='utf-8').readline())['gherkinDocument']
f = doc['feature']
emit(0, 'feature ' + q(f['name']))
tags(1, f)
desc(1, f)
children(1, f['children'])
sys.stdout.write('\n'.join(out) + '\n')
