roxygen2::roxygenize()
rmarkdown::render("README.Rmd")
unlink("docs", recursive = TRUE)
pkgdown::build_site()
fs::dir_copy("images", "docs")
