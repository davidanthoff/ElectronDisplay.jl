module ElectronDisplay

export electrondisplay

using Electron, Base64, Markdown

import IteratorInterfaceExtensions, TableTraits, TableShowUtils

struct ElectronDisplayType <: Base.AbstractDisplay end

electron_showable(m, x) =
    m ∉ ("application/vnd.dataresource+json", "text/html", "text/markdown") &&
    showable(m, x)

mutable struct ElectronDisplayConfig
    showable
    single_window::Bool
    focus::Bool
end

"""
    ElectronDisplay.CONFIG

Configuration for ElectronDisplay.

* `showable`: A callable with signature `showable(mime::String,
  x::Any) :: Bool`.  This determines if object `x` is displayed by
  `ElectronDisplay`.  Default is to return `false` if `mime` is
  `"text/html"` or `"text/markdown"` and otherwise fallbacks to
  `Base.showable(mime, x)`.

* `single_window::Bool = false`: If `true`, reuse existing window for
  displaying a new content.  If `false` (default), create a new window
  for each display.

* `focus::Bool = true`: Focus the Electron window on `display` if `true`
  (default).
"""
const CONFIG = ElectronDisplayConfig(electron_showable, false, true)

const _window = Ref{Window}()

function _getglobalwindow()
    if !(isdefined(_window, 1) && _window[].exists)
        _window[] = Electron.Window(
            URI("about:blank"),
            options=Dict("webPreferences" => Dict("webSecurity" => false)))
    end
    return _window[]
end

function displayhtml(payload; options::Dict=Dict{String,Any}())
    if CONFIG.single_window
        w = _getglobalwindow()
        load(w, payload)
        showfun = get(options, "show", CONFIG.focus) ? "show" : "showInactive"
        run(w.app, "BrowserWindow.fromId($(w.id)).$showfun()")
        return w
    else
        options = Dict{String,Any}(options)
        get!(options, "show", CONFIG.focus)
        return Electron.Window(payload; options=options)
    end
end

displayhtmlbody(payload) =
    displayhtml(string(
        """
        <!doctype html>
        <html>

        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="file:///$(asset("github-markdown-css", "github-markdown.css"))">
        <style>
            .markdown-body {
                box-sizing: border-box;
                padding: 15px;
            }
        </style>
        </head>
        <body>
        <article class="markdown-body">
        """,
        payload,
        """
         </article>
        </body>
         </html>
        """,
    ))


function Base.display(d::ElectronDisplayType, ::MIME{Symbol("text/html")}, x)
    html_page = repr("text/html", x)
    if occursin(r"<html\b"i, html_page)
        # Detect if object `x` rendered itself as a "standalone" HTML page.
        # If so, display it as-is:
        displayhtml(html_page)
    else
        # Otherwise, i.e., if `x` only produced an HTML fragment, apply
        # our default CSS to it:
        displayhtmlbody(html_page)
    end
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("text/html")}) = true

Base.display(d::ElectronDisplayType, ::MIME{Symbol("text/markdown")}, x) =
    displayhtmlbody(repr("text/html", asmarkdown(x)))

asmarkdown(x::Markdown.MD) = x
asmarkdown(x) = Markdown.parse(repr("text/markdown", x))

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("text/markdown")}) = true

function Base.display(d::ElectronDisplayType, ::MIME{Symbol("image/png")}, x)
    img = stringmime(MIME("image/png"), x)

    payload = string("<img src=\"data:image/png;base64,", img, "\"/>")

    displayhtml(payload)
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("image/png")}) = true

function Base.display(d::ElectronDisplayType, ::MIME{Symbol("image/svg+xml")}, x)
    payload = stringmime(MIME("image/svg+xml"), x)

    displayhtml(payload)
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("image/svg+xml")}) = true

asset(url...) = replace(normpath(joinpath(@__DIR__, "..", "assets", url...)), "\\" => "/")

function Base.display(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.vegalite.v2+json")}, x)
    payload = stringmime(MIME("application/vnd.vegalite.v2+json"), x)

    html_page = """
    <html>

    <head>
        <script src="file:///$(asset("vega", "vega.min.js"))"></script>
        <script src="file:///$(asset("vega", "vega-lite.min.js"))"></script>
        <script src="file:///$(asset("vega", "vega-embed.min.js"))"></script>
    </head>
    <body>
      <div id="plotdiv"></div>
    </body>

    <style media="screen">
      .vega-actions a {
        margin-right: 10px;
        font-family: sans-serif;
        font-size: x-small;
        font-style: italic;
      }
    </style>

    <script type="text/javascript">

      var opt = {
        mode: "vega-lite",
        actions: false
      }

      var spec = $payload

      vegaEmbed('#plotdiv', spec, opt);

    </script>

    </html>
    """

    displayhtml(html_page, options=Dict("webPreferences" => Dict("webSecurity" => false)))
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.vegalite.v2+json")}) = true

function Base.display(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.vega.v3+json")}, x)
    payload = stringmime(MIME("application/vnd.vega.v3+json"), x)

    html_page = """
    <html>

    <head>
        <script src="file:///$(asset("vega", "vega.min.js"))"></script>
        <script src="file:///$(asset("vega", "vega-embed.min.js"))"></script>
    </head>
    <body>
      <div id="plotdiv"></div>
    </body>

    <style media="screen">
      .vega-actions a {
        margin-right: 10px;
        font-family: sans-serif;
        font-size: x-small;
        font-style: italic;
      }
    </style>

    <script type="text/javascript">

      var opt = {
        mode: "vega",
        actions: false
      }

      var spec = $payload

      vegaEmbed('#plotdiv', spec, opt);

    </script>

    </html>
    """

    displayhtml(html_page, options=Dict("webPreferences" => Dict("webSecurity" => false)))
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.vega.v3+json")}) = true

function Base.display(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.plotly.v1+json")}, x)
    payload = stringmime(MIME("application/vnd.plotly.v1+json"), x)

    html_page = """
    <html>

    <head>
        <script src="file:///$(asset("plotly", "plotly-latest.min.js"))"></script>
    </head>
    <body>
    </body>

    <script type="text/javascript">
        gd = (function() {
            var WIDTH_IN_PERCENT_OF_PARENT = 100
            var HEIGHT_IN_PERCENT_OF_PARENT = 100;
            var gd = Plotly.d3.select('body')
                .append('div').attr("id", "plotdiv")
                .style({
                    width: WIDTH_IN_PERCENT_OF_PARENT + '%',
                    'margin-left': (100 - WIDTH_IN_PERCENT_OF_PARENT) / 2 + '%',
                    height: HEIGHT_IN_PERCENT_OF_PARENT + 'vh',
                    'margin-top': (100 - HEIGHT_IN_PERCENT_OF_PARENT) / 2 + 'vh'
                })
                .node();
            var spec = $payload
            Plotly.newPlot(gd, spec.data, spec.layout);
            window.onresize = function() {
                Plotly.Plots.resize(gd);
                };
            return gd;
        })();
    </script>

    </html>
    """

    displayhtml(html_page, options=Dict("webPreferences" => Dict("webSecurity" => false)))
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.plotly.v1+json")}) = true

function Base.display(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.dataresource+json")}, x)
    payload = stringmime(MIME("application/vnd.dataresource+json"), x)

    html_page = """
    <html>

    <head>
        <script src="file://$(asset("ag-grid", "ag-grid-community.min.noStyle.js"))"></script>
        <link rel="stylesheet" href="file://$(asset("ag-grid", "ag-grid.css"))">
        <link rel="stylesheet" href="file://$(asset("ag-grid", "ag-theme-balham.css"))">
    </head>
    <body>
        <div id="myGrid" style="height: 100%; width: 100%;" class="ag-theme-balham"></div>
    </body>

    <script type="text/javascript">
        var payload = $payload;
        var gridOptions = {
            onGridReady: event => event.api.sizeColumnsToFit(),
            onGridSizeChanged: event => event.api.sizeColumnsToFit(),
            defaultColDef: {
                resizable: true,
                filter: true,
                sortable: true
            },
            columnDefs: payload.schema.fields.map(function(x) {
                if (x.type == "number" || x.type == "integer") {
                    return {
                        field: x.name,
                        type: "numericColumn",
                        filter: "agNumberColumnFilter"
                    };
                } else if (x.type == "date") {
                    return {
                        field: x.name,
                        filter: "agDateColumnFilter"
                    };
                } else {
                    return {field: x.name};
                };
            }),
            rowData: payload.data
        };
        var eGridDiv = document.querySelector('#myGrid');
        new agGrid.Grid(eGridDiv, gridOptions);
    </script>

    </html>
    """

    displayhtml(html_page, options=Dict("webPreferences" => Dict("webSecurity" => false)))
end

Base.displayable(d::ElectronDisplayType, ::MIME{Symbol("application/vnd.dataresource+json")}) = true

function Base.display(d::ElectronDisplayType, x)
    _display(CONFIG.showable, x)
end

function _display(showable, x)
    d = ElectronDisplayType()
    if showable("application/vnd.vegalite.v2+json", x)
        display(d,MIME("application/vnd.vegalite.v2+json"), x)
    elseif showable("application/vnd.vega.v3+json", x)
            display(d,MIME("application/vnd.vega.v3+json"), x)
    elseif showable("application/vnd.plotly.v1+json", x)
            display(d,MIME("application/vnd.plotly.v1+json"), x)
    elseif showable("application/vnd.dataresource+json", x)
        display(d, "application/vnd.dataresource+json", x)
    elseif showable("image/svg+xml", x)
        display(d,"image/svg+xml", x)
    elseif showable("image/png", x)
        display(d,"image/png", x)
    elseif showable("text/html", x)
        display(d, "text/html", x)
    elseif showable("text/markdown", x)
        display(d, "text/markdown", x)
    else
        throw(MethodError(Base.display,(d,x)))
    end
end

"""
    electrondisplay([mime,] x)

Show `x` in Electron window.  Use MIME `mime` if specified.
"""
electrondisplay(mime, x) = display(ElectronDisplayType(), mime, x)

struct DataresourceTableTraitsWrapper{T}
    source::T
end

function Base.show(io::IO, ::MIME"application/vnd.dataresource+json", source::DataresourceTableTraitsWrapper)
    TableShowUtils.printdataresource(io, IteratorInterfaceExtensions.getiterator(source.source))
end

Base.showable(::MIME"application/vnd.dataresource+json", dt::DataresourceTableTraitsWrapper) = true

struct CachedDataResourceString
    content::String
end

Base.show(io::IO, ::MIME"application/vnd.dataresource+json", source::CachedDataResourceString) = print(io, source.content)

Base.showable(::MIME"application/vnd.dataresource+json", dt::CachedDataResourceString) = true

function electrondisplay(x)
    if TableTraits.isiterabletable(x)!==false
        if showable("application/vnd.dataresource+json", x)
            _display(showable, x)
        elseif TableTraits.isiterabletable(x)===true
            _display(showable, DataresourceTableTraitsWrapper(x))
        else
            try
                buffer = IOBuffer()
                TableShowUtils.printdataresource(buffer, IteratorInterfaceExtensions.getiterator(x))

                buffer_asstring = CachedDataResourceString(String(take!(buffer)))
                _display(showable, buffer_asstring)
            catch err
                _display(showable, x)
            end
        end
    else
        _display(showable, x)
    end
end

"""
    afterreplinit(f)

Like `atreplinit` but triggers `f` even after REPL is initialized when
it is called.
"""
function afterreplinit(f)
    # See: https://github.com/JuliaLang/Pkg.jl/blob/v1.0.2/src/Pkg.jl#L338
    if isdefined(Base, :active_repl)
        f()
    else
        atreplinit(_ -> f())
    end
end

function __init__()
    afterreplinit() do
        Base.Multimedia.pushdisplay(ElectronDisplayType())
    end
end

end # module
