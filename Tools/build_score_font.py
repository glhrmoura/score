import sys
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

src, out = sys.argv[1], sys.argv[2]
font = TTFont(src)
print("axes", [(a.axisTag, a.minValue, a.defaultValue, a.maxValue) for a in font["fvar"].axes])

font = instancer.instantiateVariableFont(font, {"wdth": (82, 100), "wght": (400, 900)})

gsub = font["GSUB"].table
tnum = {}
for record in gsub.FeatureList.FeatureRecord:
    if record.FeatureTag != "tnum":
        continue
    for index in record.Feature.LookupListIndex:
        lookup = gsub.LookupList.Lookup[index]
        for sub in lookup.SubTable:
            if hasattr(sub, "ExtSubTable"):
                sub = sub.ExtSubTable
            if hasattr(sub, "mapping"):
                tnum.update(sub.mapping)
print("tnum mappings", len(tnum))
changed = 0
for table in font["cmap"].tables:
    for code, glyph in list(table.cmap.items()):
        if glyph in tnum and chr(code).isdigit():
            table.cmap[code] = tnum[glyph]
            changed += 1
print("digits remapped", changed)

name = font["name"]
family = "Score"
for record in list(name.names):
    if record.nameID in (1, 3, 4, 6, 16, 21, 25):
        text = record.toUnicode()
        text = text.replace("Archivo Roman", family).replace("ArchivoRoman", family).replace("Archivo", family)
        name.setName(text, record.nameID, record.platformID, record.platEncID, record.langID)
name.setName("Score is a modified version of Archivo, made for the Score app.", 10, 3, 1, 0x409)
for record in name.names:
    if record.nameID in (1, 4, 6, 16, 25):
        print(record.nameID, record.toUnicode())
font.save(out)
print("saved", out)
