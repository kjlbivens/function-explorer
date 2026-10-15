# =====================================================================
# Function Explorer
# Author: Kelsey Bivens
# Capstone expansion of Project 2, Question 1 ("Give an example of a function")
#
# The original app asked for an example of a function and echoed the text
# back. This version keeps that, then also:
#   1. graphs the function
#   2. checks whether it is injective, surjective, bijective, and continuous
#      on a domain and codomain the user chooses
#   3. explains each answer in plain words
#
# The checks are numerical: the app evaluates the function at thousands of
# points and looks for patterns. That can suggest an answer but can't prove
# it, which is why the written proofs in the report still matter.
# =====================================================================

library(shiny)

# =====================================================================
# PART 1: Reading the user's function safely
# =====================================================================

# Only these functions may appear in a formula
allowed_functions <- c("sin", "cos", "tan", "exp", "log", "sqrt",
                       "abs", "floor", "ceiling")

# A sealed environment holding ONLY the allowed math. The formula is
# evaluated inside it, so it can't run any other R code.
safe_env <- new.env(parent = emptyenv())
for (name in c(allowed_functions, "+", "-", "*", "/", "^", "(")) {
  assign(name, get(name, envir = baseenv()), envir = safe_env)
}
assign("pi", pi, envir = safe_env)

# Turn everyday math typing into R syntax
clean_input <- function(txt) {
  txt <- tolower(trimws(txt))
  txt <- sub("^.*=", "", txt)                           # "f(x) = x^2" -> "x^2"
  txt <- gsub("**", "^", txt, fixed = TRUE)             # x**2 -> x^2
  txt <- gsub("([0-9.])\\s*([a-z(])", "\\1*\\2", txt)   # 4x -> 4*x
  txt <- gsub("\\)\\s*([a-z0-9.(])", ")*\\1", txt)      # (x+1)(x-1)
  txt <- gsub("\\bx\\s*\\(", "x*(", txt, perl = TRUE)   # x(x+1)
  trimws(txt)
}

# Returns list(ok = TRUE, f = <R function>) or list(ok = FALSE, msg = "...")
parse_function <- function(txt) {
  if (is.null(txt) || trimws(txt) == "") {
    return(list(ok = FALSE,
                msg = "Type a function above to see its graph and properties."))
  }
  expr_txt <- clean_input(txt)
  parsed <- tryCatch(parse(text = expr_txt, keep.source = TRUE),
                     error = function(e) NULL)
  if (is.null(parsed) || length(parsed) != 1) {
    return(list(ok = FALSE,
                msg = "I couldn't read that as a formula. Try something like 4x + 2 or x^2 - 3."))
  }

  # Check every piece of the formula against the allowed list
  tokens <- getParseData(parsed)
  names_used <- tokens$text[tokens$token %in% c("SYMBOL", "SYMBOL_FUNCTION_CALL")]
  unknown <- setdiff(names_used, c("x", "pi", allowed_functions))
  allowed_tokens <- c("expr", "SYMBOL", "SYMBOL_FUNCTION_CALL", "NUM_CONST",
                      "'+'", "'-'", "'*'", "'/'", "'^'", "'('", "')'")
  if (length(unknown) > 0 || any(!tokens$token %in% allowed_tokens)) {
    return(list(ok = FALSE,
                msg = paste0("Use x as the variable, numbers, + - * / ^, parentheses, pi, and these functions: ",
                             paste(allowed_functions, collapse = ", "), ".")))
  }

  expr <- parsed[[1]]
  f <- function(x) {
    out <- suppressWarnings(eval(expr, list(x = x), safe_env))
    rep_len(suppressWarnings(as.numeric(out)), length(x))
  }
  if (is.null(tryCatch(f(c(0.5, 1.5)), error = function(e) NULL))) {
    return(list(ok = FALSE,
                msg = "That formula gave an error when I tried to use it. Check the parentheses and function names."))
  }
  list(ok = TRUE, f = f)
}

# =====================================================================
# PART 2: Small helpers
# =====================================================================

near_dists <- 10^-c(3, 5, 7, 9, 11)       # steps toward a break point
far_points <- 10^c(60, 120, 180, 240, 300) # steps out toward infinity

# Given values of f marching toward a break point (or toward infinity),
# decide whether f blows up: +1 (to +inf), -1 (to -inf), 0 (settles), NA
blow_up_direction <- function(v) {
  if (any(is.infinite(v))) return(sign(v[is.infinite(v)][1]))
  if (any(is.na(v))) return(NA)
  a <- abs(v)
  d <- diff(a)
  if (all(d > 1e-9) && all(d[-1] >= 0.5 * d[-length(d)])) return(sign(v[length(v)]))
  0
}

# Zoom in on the edge between an undefined point and a defined point
find_edge_defined <- function(f, x_bad, x_good) {
  for (k in 1:60) {
    m <- (x_bad + x_good) / 2
    if (is.finite(f(m))) x_good <- m else x_bad <- m
  }
  x_good
}

# Zoom in on where a jump happens between a and b
find_jump <- function(f, a, b) {
  fa <- f(a); fb <- f(b)
  for (k in 1:60) {
    m <- (a + b) / 2; fm <- f(m)
    if (!is.finite(fm)) return(list(at = m, undefined = TRUE))
    if (abs(fm - fa) >= abs(fb - fm)) { b <- m; fb <- fm } else { a <- m; fa <- fm }
  }
  list(at = (a + b) / 2, undefined = FALSE)
}

# Is there a break between a and b? Zoom in twice. For a continuous
# function the biggest step shrinks as we zoom; for a jump it doesn't.
has_jump <- function(f, a, b) {
  s <- numeric(2)
  for (level in 1:2) {
    xs <- seq(a, b, length.out = 1001)
    ys <- f(xs)
    if (any(!is.finite(ys))) return(TRUE)
    steps <- abs(diff(ys))
    k <- which.max(steps)
    s[level] <- steps[k]
    a <- xs[k]; b <- xs[k + 1]
  }
  s[1] > 1e-9 && s[2] > 0.5 * s[1]
}

fmt_num <- function(v) {
  if (is.infinite(v)) return(if (v > 0) "\u221e" else "-\u221e")
  if (abs(v - round(v)) < 1e-6) v <- round(v)
  as.character(signif(v, 4))
}

fmt_interval <- function(r) {
  if (r$lo == r$hi) return(paste0("{", fmt_num(r$lo), "}"))
  paste0(if (r$lo_open) "(" else "[", fmt_num(r$lo), ", ",
         fmt_num(r$hi), if (r$hi_open) ")" else "]")
}

fmt_range <- function(merged) {
  parts <- vapply(merged, fmt_interval, "")
  if (length(parts) > 6) {
    # Too many pieces to list: show the five closest to y = 0
    dist0 <- vapply(merged, function(r) if (r$lo <= 0 && r$hi >= 0) 0 else min(abs(c(r$lo, r$hi))), 0)
    mid <- which.min(dist0)
    keep <- max(1, min(mid - 2, length(parts) - 4)):min(length(parts), max(mid + 2, 5))
    parts <- c(if (min(keep) > 1) "...", parts[keep], if (max(keep) < length(parts)) "...")
  }
  paste(parts, collapse = " \u222a ")
}

# A "nice" number strictly between a and b, for examples in messages
example_between <- function(a, b) {
  if (is.infinite(a) && is.infinite(b)) return(0)
  if (is.infinite(a)) return(floor(b) - 1)
  if (is.infinite(b)) return(ceiling(a) + 1)
  mid <- (a + b) / 2
  if (round(mid) > a && round(mid) < b) return(round(mid))
  signif(mid, 3)
}

# =====================================================================
# PART 3: The analysis
# =====================================================================

analyze_function <- function(f, lo, hi, co_lo, co_hi) {

  # ---- Step 1: sample points across the domain ----------------------
  # A dense grid where the graph is drawn, plus sparser "tail" points out
  # to about 100 units past it when the domain runs to infinity.
  core_lo <- if (is.finite(lo)) lo else if (is.finite(hi)) hi - 20 else -10
  core_hi <- if (is.finite(hi)) hi else core_lo + 20
  core_x  <- seq(core_lo, core_hi, length.out = 4001)
  left_tail  <- if (is.finite(lo)) numeric(0) else core_lo - rev(10^seq(0, 2, length.out = 150))
  right_tail <- if (is.finite(hi)) numeric(0) else core_hi + 10^seq(0, 2, length.out = 150)
  x <- c(left_tail, core_x, right_tail)
  y <- f(x)
  n <- length(x)
  core_dx <- diff(core_x[1:2])

  defined <- is.finite(y)
  if (!any(defined)) {
    return(list(ok = FALSE, msg = "This function isn't defined anywhere on the domain you picked."))
  }

  # ---- Step 2: find jumps between neighboring sample points --------
  dy <- diff(y)
  slope <- dy / diff(x)
  is_jump <- rep(FALSE, n - 1)
  jump_info <- vector("list", n - 1)
  for (i in which(defined[-n] & defined[-1])) {
    # Compare slopes (rise over run) so wide and narrow gaps compare fairly
    nb <- c(if (i > 1) slope[i - 1], if (i < n - 1) slope[i + 1])
    nb <- nb[is.finite(nb)]
    # Suspicious if: a wide gap between sample points, or a step much
    # bigger than its neighbors, or a step going the opposite way from
    # BOTH neighbors (a smooth curve only turns around once at a time)
    suspicious <- (x[i + 1] - x[i] > 2 * core_dx) ||
      (abs(dy[i]) > 1e-12 && (length(nb) == 0 || abs(slope[i]) > 2 * max(abs(nb)) ||
                                (length(nb) == 2 && all(sign(nb) == -sign(dy[i])))))
    if (suspicious && has_jump(f, x[i], x[i + 1])) {
      is_jump[i] <- TRUE
      jump_info[[i]] <- find_jump(f, x[i], x[i + 1])
    }
  }

  # ---- Step 3: split the graph into unbroken pieces ----------------
  connected <- defined[-n] & defined[-1] & !is_jump
  piece_id <- cumsum(c(TRUE, !connected))
  pieces <- unname(split(which(defined), piece_id[defined]))
  first_right_tail <- if (length(right_tail)) length(left_tail) + length(core_x) + 1 else NA
  last_left_tail   <- if (length(left_tail)) length(left_tail) else NA

  # Values of f as we approach the left or right end of a piece
  end_probe <- function(idx, side) {
    if (side == "left") {
      s <- idx[1]
      if (s == 1) {
        if (is.finite(lo) || is.na(last_left_tail) || idx[length(idx)] <= last_left_tail) return(NULL)
        return(f(-far_points))
      }
      if (x[s] - x[s - 1] > 2 * core_dx) return(NULL)   # coarse tail: too rough to probe
      if (!defined[s - 1]) return(f(find_edge_defined(f, x[s - 1], x[s]) + near_dists))
      return(f(jump_info[[s - 1]]$at + near_dists))
    } else {
      e <- idx[length(idx)]
      if (e == n) {
        if (is.finite(hi) || is.na(first_right_tail) || idx[1] >= first_right_tail) return(NULL)
        return(f(far_points))
      }
      if (x[e + 1] - x[e] > 2 * core_dx) return(NULL)
      if (!defined[e + 1]) return(f(find_edge_defined(f, x[e + 1], x[e]) - near_dists))
      return(f(jump_info[[e]]$at - near_dists))
    }
  }

  # ---- Step 4: estimate the range of each piece --------------------
  piece_ranges <- lapply(pieces, function(idx) {
    ys <- y[idx]; xs <- x[idx]
    r <- list(lo = min(ys), hi = max(ys), lo_open = FALSE, hi_open = FALSE)
    k <- which.min(ys)
    if (k > 1 && k < length(idx)) {
      v <- optimize(f, c(xs[k - 1], xs[k + 1]))$objective
      if (is.finite(v)) r$lo <- min(r$lo, v)
    }
    k <- which.max(ys)
    if (k > 1 && k < length(idx)) {
      v <- optimize(f, c(xs[k - 1], xs[k + 1]), maximum = TRUE)$objective
      if (is.finite(v)) r$hi <- max(r$hi, v)
    }
    for (side in c("left", "right")) {
      v <- end_probe(idx, side)
      if (is.null(v)) next
      dir <- blow_up_direction(v)
      if (is.na(dir)) next
      if (dir == 1)  { r$hi <- Inf;  r$hi_open <- TRUE }
      if (dir == -1) { r$lo <- -Inf; r$lo_open <- TRUE }
      if (dir == 0) {
        L <- v[length(v)]
        if (abs(L) < 1e-9) L <- 0
        if (L > r$hi) { r$hi <- L; r$hi_open <- TRUE }
        if (L < r$lo) { r$lo <- L; r$lo_open <- TRUE }
      }
    }
    if (is.infinite(r$lo)) r$lo_open <- TRUE
    if (is.infinite(r$hi)) r$hi_open <- TRUE
    r
  })

  # Combine overlapping pieces into one list of intervals
  tol <- 1e-9
  rs <- piece_ranges[order(vapply(piece_ranges, function(r) r$lo, 0))]
  merged <- list(rs[[1]])
  for (r in rs[-1]) {
    cur <- merged[[length(merged)]]
    touches <- if (is.infinite(cur$hi)) cur$hi > 0 else
      r$lo < cur$hi - tol || (abs(r$lo - cur$hi) <= tol && !(r$lo_open && cur$hi_open))
    if (touches) {
      if (r$lo == cur$lo) cur$lo_open <- cur$lo_open && r$lo_open
      if (r$hi > cur$hi) { cur$hi <- r$hi; cur$hi_open <- r$hi_open }
      else if (r$hi == cur$hi) cur$hi_open <- cur$hi_open && r$hi_open
      merged[[length(merged)]] <- cur
    } else {
      merged[[length(merged) + 1]] <- r
    }
  }

  # ---- Step 5: SURJECTIVE? Does the range cover the codomain? ------
  # Walk up the codomain from bottom to top. "need" is the lowest value
  # not yet covered; every time the next range piece starts above it,
  # that stretch of the codomain is a gap nobody reaches.
  outside <- any(vapply(merged, function(r) r$lo < co_lo - tol || r$hi > co_hi + tol, TRUE))
  done <- function(need, need_incl) {
    (is.infinite(need) && need > 0) ||
      (is.finite(need) && (need > co_hi + tol || (abs(need - co_hi) <= tol && !need_incl)))
  }
  need <- co_lo; need_incl <- is.finite(co_lo)
  gaps <- list()
  for (r in merged) {
    if (done(need, need_incl)) break
    if (is.finite(need) && r$hi < need - tol) next
    if (r$lo > co_hi + tol) break
    starts_ok <- if (is.infinite(need)) r$lo == need else
      r$lo < need - tol || (abs(r$lo - need) <= tol && (!r$lo_open || !need_incl))
    if (!starts_ok) {
      gaps[[length(gaps) + 1]] <- c(need, r$lo)
      need <- r$lo; need_incl <- r$lo_open
    }
    if (r$hi > need || (r$hi == need && !r$hi_open)) { need <- r$hi; need_incl <- r$hi_open }
  }
  if (!done(need, need_incl)) gaps[[length(gaps) + 1]] <- c(need, co_hi)
  covered <- length(gaps) == 0
  # For the message, use the missing value closest to y = 0
  gap <- NULL
  if (!covered) {
    ex <- vapply(gaps, function(g) {
      if (is.finite(g[1]) && is.finite(g[2]) && abs(g[2] - g[1]) < 1e-9) g[1] else example_between(g[1], g[2])
    }, 0)
    gap <- ex[which.min(abs(ex))]
  }

  # ---- Step 6: INJECTIVE? Horizontal line test ----------------------
  # Draw horizontal lines y = f(k) for whole numbers k on the graph, and
  # look for any line that crosses the graph at two different x-values.
  core <- x >= core_lo & x <= core_hi
  ks <- seq(ceiling(core_lo), floor(core_hi))
  ks <- ks[order(abs(ks - (core_lo + core_hi) / 2), ks)]
  start_x <- c(ks, quantile(core_x, seq(0.05, 0.95, 0.05), names = FALSE))
  collision <- NULL
  idx_c <- which(connected)
  # First pass: only lines that sit comfortably inside the graph, so the
  # example is easy to see. Second pass: any line at all.
  yq <- quantile(y[core & defined], c(0.02, 0.98), names = FALSE)
  visible <- function(level) diff(yq) < 1e-9 ||
    (level - yq[1] >= 0.1 * diff(yq) && yq[2] - level >= 0.1 * diff(yq))
  for (x0 in c(start_x, NA, start_x)) {
    if (is.na(x0)) { visible <- function(level) TRUE; next }
    level <- f(x0)
    if (!is.finite(level) || !visible(level)) next
    d <- y - level
    hits <- x[defined & d == 0]
    cross <- idx_c[sign(d[idx_c]) * sign(d[idx_c + 1]) < 0]
    cross <- cross[order(abs(x[cross] - x0))]          # nearest crossings first
    for (i in head(cross, 20)) {
      hits <- c(hits, uniroot(function(t) f(t) - level, c(x[i], x[i + 1]))$root)
    }
    others <- hits[abs(hits - x0) > 3 * core_dx]
    if (length(others) > 0) {
      pref <- others[abs(others - x0) >= 0.5]
      x2 <- if (length(pref)) pref[which.min(abs(pref - x0))] else others[which.max(abs(others - x0))]
      collision <- list(level = level, x1 = min(x0, x2), x2 = max(x0, x2))
      break
    }
  }

  # ---- Step 7: CONTINUOUS? List every break we found ----------------
  issues <- list()
  runs <- rle(defined)
  ends <- cumsum(runs$lengths); starts <- ends - runs$lengths + 1
  for (k in which(!runs$values)) {
    s <- starts[k]; e <- ends[k]
    left  <- if (s == 1) (if (is.finite(lo)) x[1] else -Inf) else find_edge_defined(f, x[s], x[s - 1])
    right <- if (e == n) (if (is.finite(hi)) x[n] else Inf) else find_edge_defined(f, x[e], x[e + 1])
    if (is.finite(left) && is.finite(right) && right - left < 1e-6) {
      at <- (left + right) / 2
      side_vals <- c(f(at - near_dists), f(at + near_dists))
      blows <- any(!is.finite(side_vals)) || any(abs(side_vals) > 1e6)
      issues[[length(issues) + 1]] <- list(at = at, jump = FALSE, text = if (blows)
        paste0("f is undefined at x = ", fmt_num(at), " and blows up there (vertical asymptote).") else
        paste0("f is undefined at x = ", fmt_num(at), " (a hole in the graph)."))
    } else {
      at <- if (is.finite(left)) left else right
      issues[[length(issues) + 1]] <- list(at = at, jump = FALSE,
        text = paste0("f is undefined from x = ", fmt_num(left), " to x = ", fmt_num(right), " (approximately)."))
    }
  }
  for (i in which(is_jump)) {
    j <- jump_info[[i]]
    lv <- f(j$at - near_dists); rv <- f(j$at + near_dists)
    bl <- blow_up_direction(lv); br <- blow_up_direction(rv)
    if (any(!is.finite(c(lv, rv))) || isTRUE(bl != 0) || isTRUE(br != 0)) {
      txt <- paste0("f blows up at x = ", fmt_num(j$at), " (vertical asymptote).")
    } else {
      txt <- paste0("f jumps at x = ", fmt_num(j$at), ", from about ",
                    fmt_num(lv[length(lv)]), " to about ", fmt_num(rv[length(rv)]), ".")
    }
    issues[[length(issues) + 1]] <- list(at = j$at, jump = TRUE, text = txt)
  }
  if (length(issues)) {
    center <- (core_lo + core_hi) / 2
    issues <- issues[order(vapply(issues, function(z) abs(z$at - center), 0))]
  }

  list(ok = TRUE, x = x, y = y, pieces = pieces, core = c(core_lo, core_hi),
       merged = merged, covered = covered, gap = gap, outside = outside,
       collision = collision, issues = issues, undefined_somewhere = !all(defined))
}

# =====================================================================
# PART 4: Graph and written results
# =====================================================================

plot_analysis <- function(a) {
  x <- a$x; y <- a$y
  in_core <- x >= a$core[1] & x <= a$core[2]
  yc <- y[in_core & is.finite(y)]
  q <- quantile(yc, c(0.02, 0.98), names = FALSE)
  ylim <- if (diff(range(yc)) <= 10 * max(diff(q), 1e-9)) range(yc) else q
  if (!is.null(a$collision)) ylim <- range(c(ylim, a$collision$level))
  if (diff(ylim) < 1e-9) ylim <- ylim + c(-1, 1)
  ylim <- ylim + c(-0.08, 0.08) * diff(ylim)

  par(mar = c(4.2, 4.2, 1, 1), las = 1)
  plot(NA, xlim = a$core, ylim = ylim, xlab = "x", ylab = "f(x)", bty = "l")
  grid(col = "gray92", lty = 1)
  abline(h = 0, v = 0, col = "gray70")
  for (iss in a$issues) {
    if (iss$at >= a$core[1] && iss$at <= a$core[2]) abline(v = iss$at, col = "gray55", lty = 3, lwd = 1.5)
  }
  for (idx in a$pieces) {
    k <- idx[in_core[idx]]
    if (length(k) == 1) points(x[k], y[k], pch = 19, col = "#2C5F8A", cex = 0.6)
    if (length(k) > 1) lines(x[k], y[k], lwd = 3, col = "#2C5F8A")
  }
  if (!is.null(a$collision)) {
    cl <- a$collision
    abline(h = cl$level, col = "#C0392B", lty = 2, lwd = 2)
    points(c(cl$x1, cl$x2), rep(cl$level, 2), pch = 21, bg = "#C0392B", col = "white", cex = 2)
  }
}

verdict_card <- function(title, yes, body) {
  div(class = "card mb-2",
      div(class = "card-body py-2",
          h5(class = "mb-1", title, " ",
             span(class = paste("badge", if (yes) "bg-success" else "bg-danger"),
                  if (yes) "Yes" else "No")),
          p(class = "mb-0", body)))
}

results_ui <- function(a) {
  # Injective
  inj <- is.null(a$collision)
  inj_text <- if (inj) {
    "Every horizontal line crossed the graph at most once on this domain, so it passes the horizontal line test: different inputs always give different outputs."
  } else {
    cl <- a$collision
    paste0("f(", fmt_num(cl$x1), ") = f(", fmt_num(cl$x2), ") = ", fmt_num(cl$level),
           ". Two different inputs give the same output, so the red dashed line crosses the graph more than once and the horizontal line test fails.")
  }

  # Surjective
  rng <- fmt_range(a$merged)
  surj <- a$covered && !a$outside
  surj_text <- if (a$outside) {
    paste0("Some outputs land outside the codomain you picked (estimated range: ", rng,
           "), so f doesn't fit inside this codomain. Try widening the codomain.")
  } else if (surj) {
    paste0("Every value in the codomain gets reached by some input. Estimated range: ", rng,
           if (!endsWith(rng, "...")) ".")
  } else {
    paste0("Estimated range: ", rng, if (!endsWith(rng, "...")) ".", " Some codomain values are never reached. For example, no input gives y = ",
           fmt_num(a$gap), ".")
  }

  # Bijective
  bij <- inj && surj && !a$undefined_somewhere
  missing <- c(if (!inj) "injective", if (!surj) "surjective")
  bij_text <- if (bij) {
    "f is both injective and surjective, so it pairs every input with exactly one output. That means f has an inverse function on this domain and codomain."
  } else if (a$undefined_somewhere && length(missing) == 0) {
    "f is not defined for every x in this domain, so it isn't a bijection on it. Shrink the domain to where f is defined and check again."
  } else {
    paste0("f is not ", paste(missing, collapse = " or "),
           ", so it is not bijective and has no inverse from this codomain back to this domain.")
  }

  # Continuous
  cont <- length(a$issues) == 0
  cont_text <- if (cont) {
    "No breaks, jumps, or holes were found anywhere on this domain."
  } else {
    shown <- vapply(head(a$issues, 2), function(z) z$text, "")
    extra <- length(a$issues) - length(shown)
    txt <- paste(shown, collapse = " ")
    if (extra > 0) txt <- paste0(txt, " (", extra, " more break", if (extra > 1) "s", " found.)")
    if (!any(vapply(a$issues, function(z) z$jump, TRUE)) &&
        !any(grepl("blows up", vapply(a$issues, function(z) z$text, "")))) {
      txt <- paste(txt, "Everywhere f IS defined, the graph is unbroken.")
    }
    txt
  }

  tagList(
    if (a$undefined_somewhere) div(class = "alert alert-warning py-2",
      "Heads up: f isn't defined for every x in this domain, so strictly speaking it isn't a function on this whole domain (every input needs an output). The checks below only use the x-values where f is defined. Try shrinking the domain."),
    verdict_card("Injective (one-to-one)?", inj, inj_text),
    verdict_card("Surjective (onto the codomain)?", surj, surj_text),
    verdict_card("Bijective (has an inverse)?", bij, bij_text),
    verdict_card("Continuous on this domain?", cont, cont_text),
    p(class = "text-muted small mt-2",
      "How this works: the app evaluates f at about 4,000 points across the domain (plus far-away test points), then checks each property numerically. A numerical check can suggest an answer but can't prove it. A proof is what confirms it.")
  )
}

# =====================================================================
# PART 5: The app
# =====================================================================

ui <- fluidPage(
  theme = bslib::bs_theme(version = 5, bootswatch = "flatly"),
  titlePanel("Function Explorer"),
  sidebarLayout(
    sidebarPanel(
      h4("Give an example of a function."),
      textInput(inputId = "user_answer",
                label = "Your answer:",
                placeholder = "e.g., f(x) = 4x + 2"),
      selectInput("example", "Or pick an example:",
                  choices = c("Choose one..." = "", "4x + 2", "x^2", "x^3", "1/x",
                              "sqrt(x)", "abs(x)", "sin(x)", "floor(x)", "exp(x)")),
      hr(),
      radioButtons("domain_type", "Domain (allowed inputs):",
                   choiceNames = list("All real numbers", "x \u2265 a", "a \u2264 x \u2264 b"),
                   choiceValues = list("all", "from", "between")),
      conditionalPanel("input.domain_type != 'all'", numericInput("dom_a", "a =", 0)),
      conditionalPanel("input.domain_type == 'between'", numericInput("dom_b", "b =", 5)),
      radioButtons("codomain_type", "Codomain (target outputs):",
                   choiceNames = list("All real numbers", "y \u2265 c", "c \u2264 y \u2264 d"),
                   choiceValues = list("all", "from", "between")),
      conditionalPanel("input.codomain_type != 'all'", numericInput("co_c", "c =", 0)),
      conditionalPanel("input.codomain_type == 'between'", numericInput("co_d", "d =", 10)),
      helpText("Use x as the variable. Allowed: numbers, + - * / ^, parentheses, pi,",
               "and sin, cos, tan, exp, log, sqrt, abs, floor, ceiling.")
    ),
    mainPanel(
      h4("You typed:"),
      textOutput("echoed_text"),
      hr(),
      uiOutput("message"),
      plotOutput("graph", height = "380px"),
      uiOutput("results")
    )
  )
)

server <- function(input, output, session) {

  # Picking an example fills in the text box
  observeEvent(input$example, {
    if (nzchar(input$example)) updateTextInput(session, "user_answer", value = input$example)
  })

  # The original requirement: show exactly what the user typed
  output$echoed_text <- renderText({
    input$user_answer
  })

  # Wait until the user pauses typing before analyzing
  typed <- debounce(reactive(input$user_answer), 600)

  analysis <- reactive({
    p <- parse_function(typed())
    if (!p$ok) return(p)
    dom <- switch(input$domain_type,
                  all = c(-Inf, Inf),
                  from = c(input$dom_a, Inf),
                  between = c(input$dom_a, input$dom_b))
    co <- switch(input$codomain_type,
                 all = c(-Inf, Inf),
                 from = c(input$co_c, Inf),
                 between = c(input$co_c, input$co_d))
    if (any(is.na(c(dom, co)))) return(list(ok = FALSE, msg = "Fill in the numbers for the domain and codomain."))
    if (dom[1] >= dom[2]) return(list(ok = FALSE, msg = "For the domain, a has to be less than b."))
    if (co[1] >= co[2]) return(list(ok = FALSE, msg = "For the codomain, c has to be less than d."))
    tryCatch(analyze_function(p$f, dom[1], dom[2], co[1], co[2]),
             error = function(e) list(ok = FALSE,
                                      msg = paste("Something went wrong analyzing that function:", conditionMessage(e))))
  })

  output$message <- renderUI({
    a <- analysis()
    if (!a$ok) div(class = "alert alert-secondary", a$msg)
  })

  output$graph <- renderPlot({
    a <- analysis()
    req(a$ok)
    plot_analysis(a)
  })

  output$results <- renderUI({
    a <- analysis()
    req(a$ok)
    results_ui(a)
  })
}

shinyApp(ui = ui, server = server)
