# R CMD Check False Positives with R6 Classes

This repository demonstrates an issue where R CMD check fails to detect usage of packages inside R6 classes, resulting
in false positive NOTE that declared Imports are unused. To replicate this, simply just make an R6 class that have
`pkg::foo()` inside the R6 class (should be only usage of that package) and add the package to Imports.

Below is the example this repository uses:

The package contains a single `.R` file defining a custom filter function and an R6 class, where `stats::filter()` is
used inside a method:
``` r
filter <- function() {
  message("This is a custom filter function.")
}

DataProcessor <- R6::R6Class(
  "DataProcessor",
  public = list(
    data = NULL,
    initialize = function(data) self$data <- data,

    filter_data = function(data) {
      filter()
      self$data <- stats::filter(self$data, rep(1, 3))
    }
  )
)
```
Although both R6 and stats are used, running R CMD check produces a NOTE indicating that
these packages are not used:
```         
* checking dependencies in R code ... NOTE
Namespaces in Imports field not imported from:
  ‘R6’ ‘stats’
```

## R CMD check results

This NOTE appears in all local checks, whether using devtools:
``` r
devtools::check()
devtools::check(remote = TRUE, manual = TRUE)
```
or directly with R CMD check:
``` bash
>R CMD build .
>R CMD check RCMDcheckFalsePositive_0.1.0.tar.gz
```
The `.tar.gz` and `.Rcheck/` are included in the repository for reference.

Interestingly, the issue does not occur when trying on CRAN release/dev winbuilder https://win-builder.r-project.org/
(Remember to change email in DESCRIPTION if trying this yourself!).
This check passes:
``` r
* checking dependencies in R code ... OK
```
The results of this for dev version Windows check are in `CRAN-dev-winbuilder-results/`.

I found this related stackoverflow post:
https://stackoverflow.com/questions/64055049/unexpected-note-namespace-in-imports-field-not-imported-from-r6

My sessionInfo (same issue appears on Windows):
``` r
> sessionInfo()
R version 4.5.2 (2025-10-31)
Platform: x86_64-pc-linux-gnu
Running under: Linux Mint 22.3

Matrix products: default
BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/libopenblasp-r0.3.26.so;  LAPACK version 3.12.0

locale:
 [1] LC_CTYPE=en_US.UTF-8       LC_NUMERIC=C               LC_TIME=en_US.UTF-8       
 [4] LC_COLLATE=en_US.UTF-8     LC_MONETARY=en_US.UTF-8    LC_MESSAGES=en_US.UTF-8   
 [7] LC_PAPER=en_US.UTF-8       LC_NAME=C                  LC_ADDRESS=C              
[10] LC_TELEPHONE=C             LC_MEASUREMENT=en_US.UTF-8 LC_IDENTIFICATION=C       

time zone: Europe/Copenhagen
tzcode source: system (glibc)

attached base packages:
[1] stats     graphics  grDevices utils     datasets  methods   base     

loaded via a namespace (and not attached):
[1] compiler_4.5.2 tools_4.5.2
```

## Questions

1. Is this the intended behavior of R CMD check, or is it a bug that it fails to detect usage of packages inside
R6 classes? If intended (e.g. due to it being too expensive to check for :: in "hidden places") should this be
mentioned somewhere on WRE? Currently
[WRE](https://cran.r-project.org/doc/manuals/r-devel/R-exts.html#Package-Dependencies-1) says:
*"The ‘Imports’ field should not contain packages which are not imported from (via the NAMESPACE file or :: or ::: operators)"*
indicating that `::` usage should be fully supported.

2. How/Why does the NOTE disappear when checking on CRAN dev winbuilder? Can I replicate this behavior locally using
R CMD check? Will it pass on CRAN?

## Workaround

Of course I can just import `importFrom(R6, R6Class)` to prevent the R6 note, but since I want to use `stats::filter()`
and my custom filter function I need to use `stats::filter()` to resolve the conflict[^1].

I see two possible hacks to get around this:

1. Import a different arbitrary functions for the packages I use in NAMESPACE to silence the NOTE. E.g. adding 
```
importFrom(stats, anova)
```
2. Make a (unused) function that calls `stats::filter()` (outside of the R6 class). R CMD check will correctly
pick up the usage of the package then. I.e. adding something like this to the package:
```r
avoid_cran_note <- function() {
  x <- 1:100
  stats::filter(x, rep(1, 3))
}
```
Neither of these solutions are ideal.

The first one is a bit hacky and requires importing functions that are not
actually used in the package, which pollutes NAMESPACE and can be confusing for users and maintainers. In theory
this solution could even be impossible due to conflicts.

The second one adds unnecessary code to the package, which can also be confusing,
especially if using many packages inside the R6 class that are not detected by R CMD check.

[^1]: Since stats is a base package, I technically don't need to add it in Imports, but this is besides the point.
Replace the use of `stats::filter()` any other conflicts (e.g. just replace `stats::filter()` with `dplyr::filter()`
in my example) and the issue is the same. I chose to only use base packages (except the needed R6 for the issue)
to replicate the issue I observed as minimal as possible.
