# Function Explorer: Testing Function Properties Analytically and Numerically

**Kelsey Bivens** · October 15, 2026

A web app that samples a function at about 4,000 points correctly classified 21 test cases as injective, surjective, bijective, or continuous, matching the formal proofs every time. It can suggest an answer quickly, but only a proof can confirm one.

**Live app:** https://kelseybivens.shinyapps.io/FunctionExplorer/

## 1. Problem statement

The question this project answers: **can a computer reliably decide whether a function is injective, surjective, bijective, or continuous, and can that tool help students understand the definitions instead of memorizing them?**

Students usually meet these properties through formal proofs and a few hand-drawn graphs. A student can often recite "different inputs give different outputs" without being able to explain why a parabola fails that test, or how changing the domain changes the answer. Each property depends on three things at once, the formula, the domain, and the codomain, and that is hard to see on paper.

This report expands Project 2 from this course. In Question 1, I built an R Shiny app that asked "Give an example of a function" and displayed the answer back. Questions 2 to 4 asked for proofs about f(x) = 4x + 2, parabolas, and continuity. The expanded app, **Function Explorer**, connects those two halves: it graphs the function the user types and tests all four properties on a domain and codomain the user chooses, explaining each result in plain language.

## 2. Mathematical formulation

Let f be a function from a domain A to a codomain B, both subsets of the real numbers. The modeling step is rewriting each definition as something a computer can check.

**Injective (one-to-one).** Different inputs always give different outputs:

```math
f(a_1) = f(a_2) \implies a_1 = a_2 \quad \text{for all } a_1, a_2 \in A
```

Testable version: no horizontal line y = c crosses the graph at two different x-values (the horizontal line test).

**Surjective (onto).** Every value in the codomain is reached:

```math
\text{for every } b \in B \text{ there is an } a \in A \text{ with } f(a) = b
```

Testable version: the estimated range f(A) covers all of B.

**Bijective.** Both of the above. A function has an inverse exactly when it is bijective.

**Continuous.** f is continuous at a point c in its domain when

```math
\lim_{x \to c} f(x) = f(c)
```

In plain words: you can get f(x) as close to f(c) as you want just by picking x close enough to c. (This is the idea behind the formal epsilon-delta definition.) Testable version: zooming in on any spot, the change in f between nearby points shrinks toward zero. At a jump or asymptote, it does not.

**Sampling.** A computer cannot check infinitely many points, so the app replaces the domain with a finite grid of about 4,000 points where the graph is drawn, plus sparser points farther out, and works with the values of f at those points.

## 3. Solution approach

The project uses two approaches side by side: proofs, which give certainty, and a numerical app, which gives speed and a picture.

### 3.1 Analytical: the proofs from Project 2

**f(x) = 4x + 2 is injective.** Suppose f(a) = f(b). Then 4a + 2 = 4b + 2, so 4a = 4b and a = b.

**f(x) = 4x + 2 is surjective onto the real numbers.** For any real y, let x = (y − 2)/4. Then f(x) = 4 · (y − 2)/4 + 2 = y. So f is bijective, with inverse f⁻¹(y) = (y − 2)/4.

**Parabolas.** Every parabola f(x) = a(x − h)² + k is symmetric about its vertex, so f(h − t) = f(h + t) and it is never injective on all real numbers (for x², f(−2) = f(2) = 4). Restricting the domain to one side of the vertex, such as x ≥ h, makes it injective. Its range is [k, ∞) when a > 0, so it is surjective only when the codomain is chosen to be that range. With both restrictions it is bijective, with inverse f⁻¹(y) = h + √((y − k)/a); for x² that is √y.

**Continuity.** The relation x² + y² = 1 is not a function, since x = 0 gives both y = 1 and y = −1. The polynomial 4x + 2 is continuous everywhere. The floor function jumps at every integer n, where the limit from the left (n − 1) does not equal f(n) = n.

### 3.2 Numerical: how the app tests a function

The app is written in R with the Shiny package. When the user types a formula, it:

1. **Reads the formula safely,** accepting everyday notation such as `4x + 2` but allowing only numbers, x, pi, basic operations, and nine math functions.
2. **Samples the function** and marks any x-values where f is undefined.
3. **Finds breaks** by flagging unusually large steps between neighboring points and zooming in twice. If the step shrinks, f is continuous there; if not, it is a jump or an asymptote.
4. **Estimates the range** of each unbroken piece, checking very large x-values and points near each break to see whether f heads toward infinity or levels off.
5. **Runs the horizontal line test** on lines y = f(k) for whole numbers k, and shows the first line with two crossings in red.
6. **Compares the range to the codomain** and names a value that is never reached.

## 4. Results

The app's answer matched the analytical answer in all 21 test cases, including every function from Project 2 Questions 2 to 4. Rows marked \* are not defined on the whole chosen domain; the app flags these with a warning and checks only the x-values where f exists.

| Function | Domain | Codomain | Injective | Surjective | Bijective | Continuous |
| --- | --- | --- | --- | --- | --- | --- |
| 4x + 2 | ℝ | ℝ | Yes | Yes | Yes | Yes |
| x² | ℝ | ℝ | No: f(−4) = f(4) = 16 | No: misses y = −1 | No | Yes |
| x² | x ≥ 0 | ℝ | Yes | No | No | Yes |
| x² | ℝ | y ≥ 0 | No | Yes | No | Yes |
| x² | x ≥ 0 | y ≥ 0 | Yes | Yes | Yes | Yes |
| x² | x ≥ 0 | y ≥ −5 | Yes | No | No | Yes |
| x² − 4x + 3 | x ≥ 2 | y ≥ −1 | Yes | Yes | Yes | Yes |
| (x + 1)(x − 1) | ℝ | ℝ | No | No | No | Yes |
| x³ | ℝ | ℝ | Yes | Yes | Yes | Yes |
| \|x\| | ℝ | ℝ | No | No | No | Yes |
| √x \* | ℝ | ℝ | Yes | No | No | No: undefined for x < 0 |
| √x | x ≥ 0 | y ≥ 0 | Yes | Yes | Yes | Yes |
| 1/x \* | ℝ | ℝ | Yes | No: misses y = 0 | No | No: asymptote at x = 0 |
| eˣ | ℝ | ℝ | Yes | No | No | Yes |
| eˣ | ℝ | y ≥ 0 | Yes | No: misses y = 0 | No | Yes |
| ln x \* | ℝ | ℝ | Yes | Yes | No | No: undefined for x ≤ 0 |
| sin x | ℝ | ℝ | No: sin 0 = sin π = 0 | No | No | Yes |
| sin x | [−π/2, π/2] | [−1, 1] | Yes | Yes | Yes | Yes |
| tan x | ℝ | ℝ | No | Yes | No | No: asymptotes at ±π/2, … |
| floor(x) | ℝ | ℝ | No | No | No | No: jumps at each integer |
| 5 (constant) | ℝ | ℝ | No | No | No | Yes |

Screenshots of the app are on the [repository's main page](README.md). Each check took half a second or less.

## 5. Interpretation

**The same formula can be a bijection or not, depending on the domain and codomain.** On all real numbers, x² fails both tests. Restricting only the domain fixes injectivity, restricting only the codomain fixes surjectivity, and restricting both makes it bijective. That is the answer to Questions 2.3 and 3.3, but in the app a student watches it happen by changing one setting.

**Injective and surjective are independent.** The table has every combination: both (x³), neither (sin x), injective only (eˣ), and surjective only (tan x). Asking students to find one function for each combination makes a good classroom exercise.

**Easy-to-miss details show up clearly.** The app reports that eˣ never reaches 0, and that 1/x is injective but never outputs 0. It also flags √x and ln x on all real numbers, which ties back to the definition of a function: every input in the domain needs an output.

## 6. Assumptions and limitations

The central limitation is that **a finite sample can suggest a property but never prove it.** Every "Yes" means "no counterexample was found among the points checked." The method assumes:

- **Nothing important happens between sample points.** A spike or jump narrower than the grid spacing (about 0.005) could be missed.
- **Far-away behavior follows the trend.** The app samples about 100 units past the graph, then checks a few huge values (up to 10³⁰⁰). A function that changes behavior in between would be misjudged.
- **A few dozen horizontal lines are enough.** An unusual function could repeat a value only at a level the app never tries.
- **Rounding is harmless.** Very small numbers round to zero (e⁻¹⁰⁰⁰ is stored as 0), so the app uses small tolerances.
- **The thresholds generalize.** "Unusually large step" was tuned on familiar functions; wildly oscillating ones like sin(1/x) near 0 can fool it.
- **Domains are intervals.** The app cannot choose all real numbers except 0, and formulas may use only nine built-in functions.

This is why the app is a companion to proof, not a replacement: it gives a fast first answer and a concrete counterexample, and a proof makes the answer certain.

## 7. Conclusion

Function Explorer turns four definitions into tests a computer can run, and it agreed with the formal proofs in all 21 test cases. Where the original Project 2 app only repeated the user's answer, the expanded version responds to the mathematics in it.

- **Live app:** [kelseybivens.shinyapps.io/FunctionExplorer](https://kelseybivens.shinyapps.io/FunctionExplorer/)
- **Code (R and Shiny):** [app.R](app.R) in this repository

Built in R with Shiny, with AI assistance for development and testing.
