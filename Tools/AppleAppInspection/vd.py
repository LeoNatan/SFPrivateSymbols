import json,sys,re
d=json.load(open(sys.argv[1]))
KEEP=re.compile(r'^(Text|Image|Label|Toggle|Picker|Button|Slider|TextField|Menu|LabeledContent|GroupBox|Section|Form|List|VStack|HStack|ZStack|LazyVStack|LazyHStack|Grid|GridRow|ScrollView|Divider|Spacer|ColorPicker|DisclosureGroup|OutlineGroup|ForEach|Canvas|RoundedRectangle|Rectangle|Circle|Capsule|_SegmentedControl|SystemSegmentedControl|ViewThatFits|NavigationLink|Stepper|ProgressView|ControlGroup|.*Inspector.*|.*Sidebar.*|.*Symbol.*|.*Header.*|.*Row.*|.*Cell.*|.*Section.*|.*Availability.*|.*Picker.*|.*Control.*|.*Popup.*|.*Swatch.*|.*Color.*|.*Animation.*|.*Rendering.*|_PaddingLayout|_FrameLayout|_FlexFrameLayout|_OverlayModifier|_BackgroundModifier|_TextStyleModifier|_EnvironmentKeyWritingModifier|PickerStyleWriter|.*StyleModifier|.*Font.*)$')
def leaves(a, out, path=''):
    for s in a.get('subattributes',[]) or []:
        nm=s.get('name',''); v=s.get('value'); t=s.get('readableType','')
        p=(path+'.'+nm) if path else nm
        if isinstance(v,(str,int,float,bool)) and v not in ('[]','nil','') and len(str(v))<90 and not t.startswith(('Array','Dictionary')):
            if t in ('String','LocalizedStringKey','Bool','Double','CGFloat','Int','Font','Color','Edge.Set','Alignment','HorizontalAlignment','VerticalAlignment','Optional<CGFloat>','Optional<String>','Optional<Double>') or 'Style' in t or t.endswith('Kind') or nm in ('key','verbatim','name','systemName','title'):
                out.append('%s=%s'%(p.split('.')[-1] if len(p)>30 else p, v))
        leaves(s,out,p)
def info(n):
    t=None; size=None; vals=[]
    for p in n.get('properties',[]):
        a=p.get('attribute',{}); i=p.get('id')
        if i==0: t=a.get('readableType')
        if i==4: size=a.get('value')
        if i==1: leaves(a,vals)
    return t,size,vals
def walk(n,l):
    t,size,vals=info(n)
    show = bool(t) and (KEEP.match(t.split('<')[0]) is not None)
    if show:
        sz='%gx%g'%tuple(size) if isinstance(size,list) and len(size)==2 else ''
        s=' '.join(dict.fromkeys(vals))[:220]
        print('  '*l + t.split('<')[0][:60], sz, ('· '+s) if s else '')
    for c in n.get('children',[]): walk(c, l+(1 if show else 0))
walk(d[0],0)
