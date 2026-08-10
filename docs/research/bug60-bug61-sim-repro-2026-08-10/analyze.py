import re, datetime, sys, collections
pat=re.compile(r"title row=(\S+) margin=(-?\d+) slide=(-?\d+) net=(-?\d+)")
ts=re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d+)")
BUDGET=8
def go(log,label):
    s=[]
    for line in open(log, errors="ignore"):
        m=pat.search(line); t=ts.match(line)
        if m and t:
            s.append((datetime.datetime.strptime(t.group(1),"%Y-%m-%d %H:%M:%S.%f"),
                      m.group(1), int(m.group(3)), int(m.group(4))))
    by=collections.defaultdict(list)
    for tt,k,sl,n in s: by[k].append((tt,sl,n))
    settled=[]; transient=[]
    for k,v in by.items():
        for i,(tt,sl,n) in enumerate(v):
            onscreen = -6 <= n <= 60
            gap = (v[i+1][0]-tt).total_seconds() if i+1<len(v) else 99
            if not onscreen: continue
            (settled if gap>1.0 else transient).append((k,sl,n))
    ms = max([x[1] for x in settled], default=0)
    mt = max([x[1] for x in transient], default=0)
    positions = sorted(set(x[1] for x in settled+transient))
    print("%-8s samples=%-5d rows=%-3d | SETTLED max slide=%-3d -> overlap %2d pt | TRANSIENT max slide=%-3d -> overlap %2d pt"
          % (label, len(s), len(by), ms, max(0,ms-BUDGET), mt, max(0,mt-BUDGET)))
    print("         distinct on-screen title positions during the walk: %s" % positions)
    bad=[x for x in settled if x[1]>BUDGET]
    if bad:
        print("         *** %d SETTLED states with the title ON the artwork:" % len(bad))
        for k,sl,n in sorted(bad,key=lambda x:-x[1])[:5]:
            print("             slide=%-3d net=%-4d overlap=%2dpt  %s"%(sl,n,sl-BUDGET,k[-44:]))
    else:
        print("         no settled state puts the title on the artwork")
for lg,lb in [("sweep_small.log","SMALL"),("sweep_medium.log","MEDIUM"),("sweep_large.log","LARGE")]:
    try: go(lg,lb)
    except FileNotFoundError: print(lb,"(pending)")
    print()
