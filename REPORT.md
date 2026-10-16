# Function Explorer: Checking Function Properties with Proofs and an App

**Kelsey Bivens** · October 15, 2026

For this project, I turned a simple Shiny app into a tool that graphs a function and checks whether it is injective, surjective, bijective, and continuous. Its answers matched the proofs in all 21 functions I tested, but only a proof can actually confirm an answer.

Live app: https://kelseybivens.shinyapps.io/FunctionExplorer/

## 1. Problem statement

The question I wanted to answer was whether a computer can reliably check if a function is injective, surjective, bijective, or continuous, and whether that can help students actually understand these ideas instead of just memorizing them.

Most of us learn these properties through proofs and a few graphs drawn by hand. It is easy to memorize "different inputs give different outputs" without really understanding why a parabola fails that test, or why changing the domain can change the answer. Each property depends on three things at once, the formula, the domain, and the codomain, and that is hard to see on paper.

This report builds on Project 2 from this course. For Question 1, I made an R Shiny app that asked "Give an example of a function" and showed the answer back. Questions 2 to 4 asked for proofs about f(x) = 4x + 2, parabolas, and continuity. For the capstone, I connected those two parts: Function Explorer graphs whatever function the user types, checks all four properties on a domain and codomain the user picks, and explains each answer in plain words.

## 2. Mathematical formulation

Let f be a function from a domain A to a codomain B, where both are sets of real numbers. The modeling part of this project was taking each definition and turning it into something a computer can actually check.

A function is injective (one-to-one) if different inputs always give different outputs:

```math
f(a_1) = f(a_2) \implies a_1 = a_2 \quad \text{for all } a_1, a_2 \in A
```

How the app checks it: if any horizontal line crosses the graph at two different x-values, the function is not injective. This is the horizontal line test.

A function is surjective (onto) if every value in the codomain gets hit by some input:

```math
\text{for every } b \in B \text{ there is an } a \in A \text{ with } f(a) = b
```

How the app checks it: it estimates the range and checks whether the range covers the whole codomain.

A function is bijective if it is both injective and surjective, and a function has an inverse only when it is bijective.

Finally, f is continuous at a point c in its domain when

```math
\lim_{x \to c} f(x) = f(c)
```

In plain words: you can get f(x) as close to f(c) as you want just by picking x close enough to c. (This is the idea behind the formal epsilon-delta definition.) How the app checks it: if you zoom in on any spot of a continuous graph, the change between nearby points gets smaller and smaller. At a jump or an asymptote, it does not.

One more piece of the model is sampling. A computer cannot check every real number, so the app checks about 4,000 points across the part of the graph you can see, plus some points farther out.

## 3. Solution approach

I used two approaches side by side: proofs, which give certainty, and the app, which is fast and gives a picture.

### 3.1 Analytical: the proofs from Project 2

To show that f(x) = 4x + 2 is injective, suppose f(a) = f(b). Then 4a + 2 = 4b + 2, so 4a = 4b and a = b.

To show it is surjective onto the real numbers, take any real y and let x = (y − 2)/4. Then f(x) = 4 · (y − 2)/4 + 2 = y. So f is bijective, with inverse f⁻¹(y) = (y − 2)/4.

For parabolas, every parabola f(x) = a(x − h)² + k is symmetric about its vertex, so f(h − t) = f(h + t) and it is never injective on all real numbers (for x², f(−2) = f(2) = 4). Restricting the domain to one side of the vertex, such as x ≥ h, makes it injective. Its range is [k, ∞) when a > 0, so it is surjective only when the codomain is chosen to be that range. With both restrictions it is bijective, with inverse f⁻¹(y) = h + √((y − k)/a); for x² that is √y.

For the continuity questions, the relation x² + y² = 1 is not a function, since x = 0 gives both y = 1 and y = −1. The polynomial 4x + 2 is continuous everywhere. The floor function jumps at every integer n, where the limit from the left (n − 1) does not equal f(n) = n.

### 3.2 Numerical: how the app checks a function

I wrote the app in R using the Shiny package. When someone types a formula, the app:

1. Reads the formula, so it understands everyday typing like `4x + 2`, but only allows numbers, x, pi, basic math, and nine functions such as sin and sqrt.
2. Plugs in thousands of x-values and notes any where f is undefined, like x = 0 for 1/x.
3. Looks for breaks. If two neighboring points are much farther apart than the ones around them, the app zooms in. If the gap shrinks when it zooms, the graph is connected there. If it doesn't, that is a jump or an asymptote.
4. Figures out the range of each connected piece of the graph, including whether the function keeps growing toward infinity or levels off.
5. Runs the horizontal line test using lines at heights like f(0), f(1), and f(−1), and highlights the first line that hits the graph twice in red.
6. Compares the range to the codomain to decide surjectivity, and names a value that never gets reached.

## 4. Results

The app's answers matched the proofs in all 21 test cases, including every function from Project 2, Questions 2 to 4. Rows marked \* are functions that are not defined everywhere in the chosen domain. The app shows a warning for these and only checks the x-values where f exists.

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

The same formula can be bijective or not, depending on the domain and codomain. On all real numbers, x² fails both tests. Restricting just the domain fixes injectivity, restricting just the codomain fixes surjectivity, and restricting both makes it bijective. This is the same answer I gave for Questions 2.3 and 3.3, but in the app you can watch it happen by changing one setting.

Injective and surjective don't depend on each other. The table has every combination: both (x³), neither (sin x), only injective (eˣ), and only surjective (tan x). Asking students to find a function for each combination would make a good classroom activity.

The app catches details that are easy to miss. It shows that eˣ never actually reaches 0, and that 1/x is injective but never outputs 0. It also flags √x and ln x on all real numbers, which goes back to the definition of a function: every input in the domain has to have an output.

## 6. Assumptions and limitations

The biggest limitation is that checking a lot of points can suggest an answer, but it can never prove it. When the app says "Yes," it really means "I didn't find a problem in the points I checked."

The app also depends on a few assumptions. It assumes nothing important happens between the points it checks, so a very small jump or spike could fall between two points and be missed. It assumes the function keeps doing the same thing far away, since it only checks about 100 units past the graph plus a few very large x-values. It assumes a few dozen horizontal lines are enough, even though an unusual function could repeat a value only at a height the app never checks. And because computers round very tiny numbers to zero, the app allows a small margin of error when comparing values.

There are a couple of practical limits too. I tested the app's rules for spotting breaks on familiar functions, but one that wiggles wildly, like sin(1/x) near 0, could confuse them. The domain also has to be an interval, so you can't pick "all real numbers except 0," and formulas can only use nine built-in functions.

That is why the app works best alongside proofs, not instead of them. It gives a quick first answer and a specific counterexample, and the proof is what makes the answer certain.

## 7. Conclusion

Function Explorer turns four definitions into checks a computer can run, and it agreed with the proofs in all 21 test cases. The original Project 2 app only repeated back what the user typed. This version actually responds to the math in it.

- Live app: [kelseybivens.shinyapps.io/FunctionExplorer](https://kelseybivens.shinyapps.io/FunctionExplorer/)
- Code (R and Shiny): [app.R](app.R) in this repository

I built the app in R with Shiny, with help from Claude AI on the coding and testing.
