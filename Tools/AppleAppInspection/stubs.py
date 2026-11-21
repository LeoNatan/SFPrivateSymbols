import lldb, re
def run(debugger, command, result, internal_dict):
    t = debugger.GetSelectedTarget()
    out = []
    for ins in t.ReadInstructions(t.FindFunctions(command)[0].GetSymbol().GetStartAddress(), 120):
        m, o, c = ins.GetMnemonic(t), ins.GetOperands(t), ins.GetComment(t)
        line = "%s %s %s" % (m, o, c)
        if m == 'bl':
            addr = int(o, 16)
            sa = t.ResolveLoadAddress(addr)
            ins2 = t.ReadInstructions(sa, 3)
            ops = [i.GetOperands(t) for i in ins2]
            mm = [i.GetMnemonic(t) for i in ins2]
            if mm[0] == 'adrp' and mm[2] == 'b':
                page = int(ops[0].split('#')[1].strip()) if '#' in ops[0] else int(ops[0].split(',')[1].strip())
                off = int(ops[1].split('#')[1], 16)
                sel = ((addr >> 12) + page << 12) + off
                err = lldb.SBError()
                s = t.GetProcess().ReadCStringFromMemory(sel, 200, err)
                line += "  -> [%s]" % s
        out.append(line)
        if m in ('retab', 'ret'): break
    print("\n".join(out))
