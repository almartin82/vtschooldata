# TODO

## pkgdown Build Issues

### Network Connectivity Issue (2026-01-01)

The full
[`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
command fails due to network timeout errors when trying to reach CRAN
and Bioconductor servers to check for package links in the sidebar.

**Error:**

    Error in `httr2::req_perform()`:
    ! Failed to perform HTTP request.
    Caused by error in `curl::curl_fetch_memory()`:
    ! Timeout was reached [cloud.r-project.org]:
    Connection timed out after 10000 milliseconds

**Workaround:** Individual components can be built successfully: -
`pkgdown::build_articles('.')` - Works -
`pkgdown::build_reference('.')` - Works

The issue is specifically in `pkgdown:::data_home_sidebar_links()` which
tries to check if the package exists on CRAN/Bioconductor.

**Possible Solutions:** 1. Wait for network connectivity to be restored
2. Use a VPN or different network 3. Run
[`pkgdown::build_site()`](https://pkgdown.r-lib.org/reference/build_site.html)
in a GitHub Actions workflow where network access is available 4.
Consider adding a `_pkgdown.yml` configuration to disable CRAN link
checking if such an option becomes available
