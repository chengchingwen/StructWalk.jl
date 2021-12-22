using StructWalk
using Documenter

DocMeta.setdocmeta!(StructWalk, :DocTestSetup, :(using StructWalk); recursive=true)

makedocs(;
    modules=[StructWalk],
    authors="chengchingwen <adgjl5645@hotmail.com> and contributors",
    repo="https://github.com/chengchingwen/StructWalk.jl/blob/{commit}{path}#{line}",
    sitename="StructWalk.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://chengchingwen.github.io/StructWalk.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/chengchingwen/StructWalk.jl",
    devbranch="main",
)
