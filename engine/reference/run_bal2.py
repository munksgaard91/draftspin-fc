import sys
sys.argv=[sys.argv[0]]
exec(open("run_bal.py").read().split("rows=[")[0])
print("Sværhedsgrader. AI-ratings forskudt i alle AI-spilleres rating, draftede spillere fjernet fra AI. 'Bedste' = det bedste af spillerholdene.")
print("Spillere | draft | AI-skift | bedste vinder | bedste i top 4 | snit placering | point bedste/mester")
for nh in (1,4):
    for mode in ("fornuftig","best"):
        for sh in (0,-6,-8,-10,-12,-15):
            r=scenario(rule="fjern",mode=mode,aishift=sh,nh=nh,nd=100,sea=3)
            print(f"{nh} | {mode} | {sh} | {r['bestwin']:.0f}% | {r['bestTop4']:.0f}% | {r['avgrank']:.1f} | {r['bestpts']:.0f}/{r['champpts']:.0f}")
            sys.stdout.flush()
