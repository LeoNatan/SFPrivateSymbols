import sys,re
lines=open(sys.argv[1]).read().split('\n')
KEEP=re.compile(r'^(GroupBox|Section|Form|LabeledContent|Toggle|Picker|Slider|TextField|Button|Menu|Text|Image|Divider|Spacer|HStack|VStack|_PaddingLayout|_FrameLayout|_FlexFrameLayout|ColorPicker|Grid|GridRow|ScrollView|RoundedRectangle|Canvas|SystemSegmentedControl|[A-Z][A-Za-z]*(Row|Picker|Control|Field|Slider|Swatch|Toggle|Button|Popup|View))\b')
out=[]; stack=[]
for ln in lines:
    if not ln.strip(): continue
    raw=(len(ln)-len(ln.lstrip(' ')))//2
    body=ln.strip(); name=body.split(' ')[0]; base=re.split(r'[<\s]',name)[0]
    while stack and stack[-1][0]>=raw: stack.pop()
    lvl=stack[-1][1] if stack else -1
    if KEEP.match(base) and not base.startswith(('Tree','PlatformView','ViewLeaf')):
        vals=body.split(' · ')[1:]
        if base=='Text': vals=[v for v in vals if v.startswith(('verbatim','key'))][:1]
        elif base=='Image': vals=[v for v in vals if v.startswith(('name','systemSymbol'))][:1]
        elif base in ('HStack','VStack'): vals=[v for v in vals if v.startswith(('spacing','alignment'))][:2]
        elif base.startswith('_Padding'): vals=[v for v in vals if v[0] in 'tlbr'][:4]
        elif 'Frame' in base: vals=[v for v in vals if v.startswith(('width','height','min','max'))][:4]
        else: vals=[v for v in vals if not v.startswith(('top','leading','bottom','trailing','rawValue','width=0','height=0'))][:4]
        if base in ('HStack','VStack') and not vals: 
            stack.append((raw,lvl)); continue
        lvl+=1
        out.append('  '*lvl+base+(' '+' '.join(vals) if vals else ''))
    stack.append((raw,lvl))
# collapse consecutive duplicate lines
res=[]
for l in out:
    if res and res[-1]==l: continue
    res.append(l)
print('\n'.join(res))
