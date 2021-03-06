drake_context("edge cases")

test_with_dir("skip everything", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  f <- function(x){
    x
  }
  pl <- drake_plan(a = f(0))
  con <- make(
    pl,
    session_info = FALSE,
    skip_targets = TRUE,
    skip_imports = TRUE
  )
  expect_equal(justbuilt(con), character(0))
})

test_with_dir("can keep going", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  scenario <- get_testing_scenario()
  e <- eval(parse(text = scenario$envir))
  parallelism <- scenario$parallelism
  jobs <- scenario$jobs
  e$fail <- function(...) {
    stop("oops")
  }
  e$succeed <- function(...) {
    invisible()
  }
  plan <- drake_plan(
    a1 = fail(),
    a2 = succeed(),
    a3 = succeed(),
    a4 = fail(),
    b1 = fail(a1),
    b2 = succeed(a2),
    b3 = succeed(a3),
    b4 = succeed(a4)
  )
  # warnings depend on the parallelism
  suppressWarnings(
    make(
      plan,
      keep_going = TRUE,
      parallelism = parallelism,
      verbose = FALSE,
      jobs = jobs,
      envir = e,
      hook = suppressWarnings,
      session_info = FALSE
    )
  )
  expect_equal(sort(built()), sort(c("a2", "a3", "b2", "b3", "b4")))
  expect_equal(sort(failed()), sort(c("a1", "a4", "b1")))
  expect_equal(
    sort(failed(upstream_only = TRUE)),
    sort(c("a1", "a4"))
  )
})

test_with_dir("failed targets do not become up to date", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  fail <- FALSE
  plan <- drake_plan(
    d = 3,
    a = {
      if (fail){
        stop("my failure message")
      } else {
        d
      }
    },
    b = 5,
    c = list(a, b),
    strings_in_dots = "literals"
  )
  con <- make(plan)
  expect_equal(sort(justbuilt(con)), sort(letters[1:4]))
  fail <- TRUE
  expect_error(make(plan))
  expect_error(make(plan))
  meta <- diagnose(a)
  expect_true(grepl("my failure message", meta$error$message, fixed = TRUE))
  con <- drake_config(plan)
  expect_equal(sort(outdated(con)), sort(c("a", "c")))
})

test_with_dir("drake_plan_override() quits correctly in error", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  con <- dbug()
  con$plan$missing <- "nope"
  expect_error(
    drake_plan_override(target = "missing", field = "missing", config = con),
    regexp = "not in the workflow plan"
  )
})

test_with_dir("config and make without safety checks", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  x <- drake_plan(
    file = readRDS(file_in("my_file.rds")),
    strings_in_dots = "literals"
  )
  expect_warning(tmp <- config(x, verbose = FALSE))
  expect_silent(
    tmp <- drake_config(x, skip_safety_checks = TRUE, verbose = FALSE))
  expect_silent(check_drake_config(config = tmp))
})

test_with_dir("Strings stay strings, not symbols", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  expect_silent(x <- drake_plan(a = "A", strings_in_dots = "literals"))
  expect_silent(make(x, verbose = FALSE, session_info = FALSE))
})

test_with_dir("error handlers", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  expect_equal(error_na(1), NA)
  expect_false(error_false(1))
  expect_equal(error_character0(1), character(0))
  expect_null(error_null(1))
  expect_error(error_tibble_times(123))
  expect_error(
    error_process(
      e = list(message = 5),
      id = "2",
      config = dbug()),
    regexp = "failed"
  )
})

test_with_dir("error when file target names do not match actual filenames", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  expect_warning(x <- drake_plan(y = 1, file_targets = TRUE))
  expect_warning(expect_error(make(x, verbose = FALSE, session_info = FALSE)))
})

test_with_dir("clean a nonexistent cache", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  clean(list = "no_cache")
  expect_false(file.exists(default_cache_path()))
})

test_with_dir("stringsAsFactors can be TRUE", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  f <- function(x) {
    return(x)
  }
  myplan <- data.frame(target = "a", command = "f(\"helloworld\")",
    stringsAsFactors = TRUE)
  expect_true(is.factor(myplan$target))
  expect_true(is.factor(myplan$command))
  make(myplan, verbose = FALSE, session_info = FALSE)
  expect_equal(readd(a), "helloworld")
})

# Target/import conflicts are unpredictable. A warning should
# be enough.
test_with_dir("target conflicts with current import or another target", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  config <- dbug()
  config$plan <- rbind(config$plan, data.frame(target = "f",
    command = "1+1"))
  expect_message(check_plan(plan = config$plan,
    envir = config$envir))
  config$plan$target <- "repeated"
  expect_error(check_plan(plan = config$plan))
})

test_with_dir("target conflicts with previous import", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  config <- dbug()
  testrun(config)
  config$plan$command[2] <- "g(1+1)"
  config$plan <- rbind(config$plan, data.frame(target = "f",
    command = "1+1"))
  config$targets <- config$plan$target
  testrun(config)
  expect_equal(justbuilt(config), sort(c("\"intermediatefile.rds\"",
    "combined", "f", "final", "yourinput")))
})

test_with_dir("true targets can be functions", {
  skip_on_cran() # CRAN gets whitelist tests only (check time limits).
  generator <- function() return(function(x) {
    x + 1
  })
  plan <- drake_plan(myfunction = generator(), output = myfunction(1))
  config <- make(plan, verbose = FALSE, session_info = FALSE)
  expect_equal(readd(output), 2)
  expect_true(
    is.character(
      config$cache$get("myfunction",
      namespace = "kernels")
    )
  )
  myfunction <- readd(myfunction)
  expect_equal(myfunction(4), 5)
})
