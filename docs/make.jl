using GalerkinToolkit
using Documenter

DocMeta.setdocmeta!(
    GalerkinToolkit,
    :DocTestSetup,
    :(using GalerkinToolkit);
    recursive = true,
)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [GalerkinToolkit],
    authors = "Francesc Verdugo <f.verdugo.rojano@vu.nl> and contributors",
    repo = "https://github.com/fverdugo/GalerkinToolkit.jl/blob/{commit}{path}#{line}",
    sitename = "GalerkinToolkit.jl",
    format = Documenter.HTML(; canonical = "https://fverdugo.github.io/GalerkinToolkit.jl"),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/fverdugo/GalerkinToolkit.jl")
