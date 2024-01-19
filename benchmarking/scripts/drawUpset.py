from datetime import datetime
import upsetplot
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import json
import sys


def make_grid_subfig(uplot, fig, figWidth):
    n_cats = len(uplot.totals)
    n_inters = len(uplot.intersections)

    if fig is None:
        fig = plt.gcf()

    # Determine text size to determine figure size / spacing
    text_kw = {"size": matplotlib.rcParams['xtick.labelsize']}
    # adding "x" ensures a margin
    t = fig.text(0, 0, '\n'.join(str(label) + "x"
                                    for label in uplot.totals.index.values),
                    **text_kw)
    window_extent_args = {}
    if upsetplot.plotting.RENDERER_IMPORTED:
        window_extent_args["renderer"] = upsetplot.plotting.get_renderer(fig)
    textw = t.get_window_extent(**window_extent_args).width
    t.remove()

    window_extent_args = {}
    if upsetplot.plotting.RENDERER_IMPORTED:
        window_extent_args["renderer"] = upsetplot.plotting.get_renderer(fig)
    figw = uplot._reorient(
        fig.get_window_extent(**window_extent_args)).width

    sizes = np.asarray([p['elements'] for p in uplot._subset_plots])
    fig = uplot._reorient(fig)

    non_text_nelems = len(uplot.intersections) + uplot._totals_plot_elements
    if uplot._element_size is None:
        colw = (figw - textw) / non_text_nelems
    else:
        render_ratio = figw / figWidth
        colw = uplot._element_size / 72 * render_ratio
        figw = colw * (non_text_nelems + np.ceil(textw / colw) + 1)

    text_nelems = int(np.ceil(figw / colw - non_text_nelems))
    print('textw', textw, 'figw', figw, 'colw', colw,
          'ncols', figw/colw, 'text_nelems', text_nelems)

    GS = uplot._reorient(matplotlib.gridspec.GridSpec)
    gridspec = GS(*uplot._swapaxes(n_cats + (sizes.sum() or 0),
                                    n_inters + text_nelems +
                                    uplot._totals_plot_elements),
                    hspace=1)
    if uplot._horizontal:
        out = {'matrix': gridspec[-n_cats:, -n_inters:],
                'shading': gridspec[-n_cats:, :],
                'totals': gridspec[-n_cats:, :uplot._totals_plot_elements],
                'gs': gridspec}
        cumsizes = np.cumsum(sizes[::-1])
        for start, stop, plot in zip(np.hstack([[0], cumsizes]), cumsizes,
                                        uplot._subset_plots[::-1]):
            out[plot['id']] = gridspec[start:stop, -n_inters:]
    else:
        out = {'matrix': gridspec[-n_inters:, :n_cats],
                'shading': gridspec[:, :n_cats],
                'totals': gridspec[:uplot._totals_plot_elements, :n_cats],
                'gs': gridspec}
        cumsizes = np.cumsum(sizes)
        for start, stop, plot in zip(np.hstack([[0], cumsizes]), cumsizes,
                                        uplot._subset_plots):
            out[plot['id']] = \
                gridspec[-n_inters:, start + n_cats:stop + n_cats]
    return out


def subfig_plotting(uplot, fig, figWidth, ylabel="intersection_size", log_y_axis = False):
    """
    Plots upsetPlots as subfig 

    UpsetPlots are made up of 3 components: an intersection-graph, a matrix, and a totals-graph
    All of these are plotted in a subfigure so that multiple upsetplots can be included in a single figure.

    Parameters
        uplot:
        fig: 
        figWidth:
        ylabel:
        log_y_axis:

    Returns
        out: matplotlib-axis for subfig 
    """
    if fig is None:
        fig = plt.figure(figsize=uplot._default_figsize)
    specs = make_grid_subfig(uplot, fig, figWidth)
    shading_ax = fig.add_subplot(specs['shading'])
    uplot.plot_shading(shading_ax)
    matrix_ax = uplot._reorient(fig.add_subplot)(specs['matrix'],
                                                sharey=shading_ax)
    uplot.plot_matrix(matrix_ax)
    totals_ax = uplot._reorient(fig.add_subplot)(specs['totals'],
                                                sharey=matrix_ax)
    uplot.plot_totals(totals_ax)

    out = {'matrix': matrix_ax,
            'shading': shading_ax,
            'totals': totals_ax}

    inters = uplot.totals.to_list()

    # Plots text for 'totals' part of graph (horizontal bars to the left of the matrix)
    for i in range(0, len(inters)):
        if inters[i] > 1000:
            bar_label = f"{inters[i]:.2e}"
        else:
            bar_label = f"{inters[i]:.2f}"
        plt.text(inters[i], i, bar_label, ha="right", va="center")

    for plot in uplot._subset_plots:
        ax = uplot._reorient(fig.add_subplot)(specs[plot['id']],
                                                sharex=matrix_ax)
        if plot['type'] == 'default':
            uplot.plot_intersections(ax)

            # Plots text for 'intersections' part of graph (vertical bars)
            inters = uplot.intersections.to_list()
            plt.rcParams.update({'font.size': 5})
            for i in range(0, len(inters)):
                if inters[i] > 1:
                    bar_label = f"{inters[i]:.2e}"
                else:
                    bar_label = f"{inters[i]:.2f}"
                plt.text(i, inters[i], bar_label, ha="center", va="bottom")

            plt.rcParams.update({'font.size': 10})
            ax.set_ylabel(ylabel)
            if log_y_axis:
                ax.set_yscale("log")
        elif plot['type'] in uplot.PLOT_TYPES:
            kw = plot.copy()
            del kw['type']
            del kw['elements']
            del kw['id']
            uplot.PLOT_TYPES[plot['type']](uplot, ax, **kw)
        else:
            raise ValueError('Unknown subset plot type: %r' % plot['type'])
        out[plot['id']] = ax
    return out


def check_input(possible_input: int or None) -> int:
    if possible_input is None:
        return -1
    else:
        return possible_input
    

summaries = json.load(open(sys.argv[1], "r"))
inputData = [[],[],[],[],[]]
for file in summaries:
    fileName = file["left"]
    fileAdress = file["right"]
    fileNameSeperated = fileName.replace(".n.d.vcf.gz", "").replace(".vcf", "").split("-")
    summary = json.load(open(fileAdress))
    inputData[0].append(fileNameSeperated)
    inputData[1].append(check_input(summary["precision"]))
    inputData[2].append(check_input(summary["recall"]))
    inputData[3].append(check_input(summary["f1"]))
    inputData[4].append(summary["comp cnt"])


rowSet = set()
for combination in inputData[0]:
    for item in combination:
        rowSet.add(item)
amountOfRows = len(rowSet)

figWidth = 10
fig = plt.figure(layout="constrained", figsize=(figWidth,figWidth * 1.3))
subfigs = fig.subfigures(4,1)

variant_number_plot = upsetplot.from_memberships(inputData[0], data=inputData[4])
variant_number_upset = upsetplot.UpSet(data=variant_number_plot, facecolor="green", sort_by="input", sort_categories_by="input")
precision_plot = upsetplot.from_memberships(inputData[0], data=inputData[1])
precision_upset = upsetplot.UpSet(data= precision_plot, facecolor="blue",sort_by="input", sort_categories_by="input")
recall_plot = upsetplot.from_memberships(inputData[0], data=inputData[2])
recall_upset = upsetplot.UpSet(data=recall_plot, facecolor="red", sort_by="input", sort_categories_by="input")
f1_plot = upsetplot.from_memberships(inputData[0], data=inputData[3])
f1_upset = upsetplot.UpSet(data = f1_plot, sort_by="input", sort_categories_by="input")

subfig_plotting(variant_number_upset, subfigs[0], figWidth, ylabel="variant number", log_y_axis=True)
subfig_plotting(precision_upset, subfigs[1], figWidth, ylabel="precision")
subfig_plotting(recall_upset, subfigs[2], figWidth, ylabel="recall")
subfig_plotting(f1_upset, subfigs[3], figWidth, ylabel="f1")

name = "upsetplot.png"
plt.savefig(name, dpi=300)
