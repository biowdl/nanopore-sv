from PIL import Image
import upsetplot
import matplotlib.pyplot as plt
import json
import sys

summaries = json.load(open(sys.argv[1], "r"))
inputData = [[],[],[],[],[]]
for file in summaries:
    fileName = file["left"]
    fileAdress = file["right"]
    fileNameSeperated = fileName.replace(".n.d.vcf.gz", "").replace(".vcf", "").split("-")
    summary = json.load(open(fileAdress))
    inputData[0].append(fileNameSeperated)
    inputData[1].append(summary["precision"])
    inputData[2].append(summary["recall"])
    inputData[3].append(summary["f1"])
    inputData[4].append(summary["comp cnt"])
    print(f"{fileNameSeperated} : {inputData}")


rowSet = set()
for combination in inputData[0]:
    for item in combination:
        rowSet.add(item)
amountOfRows = len(rowSet)


precision_plot = upsetplot.from_memberships(inputData[0], data=inputData[1])
upsetplot.plot(precision_plot, facecolor="blue",sort_by="input", sort_categories_by="input")
name = "1"
plt.ylabel("precision-score")
plt.savefig(name, dpi=300)


recall_plot = upsetplot.from_memberships(inputData[0], data=inputData[2])
upsetplot.plot(recall_plot, facecolor="red", sort_by="input", sort_categories_by="input")
name = "2"
plt.ylabel("recall-score")
plt.savefig(name, dpi=300)


f1_plot = upsetplot.from_memberships(inputData[0], data=inputData[3])
upsetplot.plot(f1_plot, sort_by="input", sort_categories_by="input")
name = "3"
plt.ylabel("f1-score")
plt.savefig(name, dpi=300)

images = [Image.open(x) for x in [f"1.png", f"2.png", f"3.png"]]

# Crop the graphs at the top and bottom, to remove the redundant upset-plot stuff from the upper graphs
# IMPORTANT: We're cropping the intersection graphs here. If the datapoints are not sorted by input...
# ...these bars might be in different orders and you won't even be able to tell. 
# '- (amountOfRows*140)' is pretty ugly: one row of the intersection graph is about 140 pixels high at 300dpi
# So we're calculating how much to crop from the height, but this only works at the current dpi. 
for i in range(len(images)):
    if i < len(images)-1:
        images[i] = images[i].crop((0,150,images[i].size[0], images[i].size[1] - (amountOfRows*140)))
    else:
        images[i] = images[i].crop((0,150,images[i].size[0], images[i].size[1]))

widths, heights = zip(*(i.size for i in images))

max_width = max(widths)
total_height = sum(heights)

new_im = Image.new(f'RGB', (max_width, total_height), color=(255,255,255))

y_offset = 0
for im in images:
    x_offset = max_width - im.size[0] 
    new_im.paste(im, (x_offset, y_offset))
    y_offset += im.size[1]

name = "upsetplot.png"
new_im.save(name)