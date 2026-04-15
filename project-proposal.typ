#set page(height: auto)
#show link: it => underline(text(blue, it))

#align(center)[
  = `HasCOIL`; The Calculus of Interactive Lisps
]

#align(center)[Eleanor, Adrian, Jai]

= Background
Syntactically and semantically, `HasCOIL` (a combination of "Haskell" and "The Calculus of Interactive Lisps" made to sound similar to Haskell for pun reasons) will be most similar to Haskell and Lisp. However, rather than using the substrate of lambda calculus, we will be using "interaction calculus", which can initially be thought of as a different way to implement lambda calculus that reduces duplicate work, yet adds a lot of features that will be exposed to the user in the language.

An advantage of this approach to program evaluation over Haskell's is that lambda calculus does not efficiently manage resources usage. When needing a resource multiple times, often times cloning an entire subtrees is required. Conversely, if a resource is not required, entire subtrees (which took processing power to construct) must be deleted. This is why many functional programming languages need a garbage collector. But interaction calculus doesn't allow for this. If you use resources multiple times, you need to explicitly duplicate those exact resources. And once you are done with them, you free those resources individually. 

This also links to systems of linear logic where you need to explicitly think about the way that you duplicate and free resources. Some resources this is allowed for, but for others it isn't. Ex: in Quantum Mechanics you can't duplicate things (no cloning theorem). And as it so happens there are #link("https://pennylane.ai/qml/demos/tutorial_zx_calculus")[graph rewriting systems used for quantum mechanics].

An example of programming languages with systems like this is the borrow checker in Rust. Mutable resources cannot be duplicated, they can only be moved. Rust is not actually a linear system, it is affine, but the idea is still there.

This has the potential of turning into a lower level language then most functional languages typically aim for. Due to this language using concepts from linear logic, you need to be a lot more explicit about how data is being moved around and used. You can know yourself that you should never be duplicating a file descriptor for instance, as a file descriptor should only be freed once. Resource usage and movement throughout the program is far more explicit. 

On top of that, runtimes for this language can quite easily be implemented in very few lines and doesn't need to be as smart as the Haskell runtime. It is potentially possible to put a runtime on a microcontroller. This lower level angle is more of a stretch goal or a post-class project but the possibility of a low level functional language was worth mentioning. We will, however, be making a more basic runtime to run on an operating system.

Interaction calculus has some interesting advantages over regular lambda calculus. Lambda calculus being a system where you repeatedly rewrite a tree of lambda terms through function application. But there are several issues with that. An example of this in Haskell (which avoids some but not all of the inherent issues of lambda calculus)
```hs
f :: Int -> Int -> Int
f x y = x + x
-- Thunks that represent some expensive computation
f (6666^2) (7777^2)
```
The problem with this, is that there is no way to evaluate this without wasting work. You either evaluate it "lazily" (pieces aren't evaluated until they are needed), or "strictly" (they are). If evaluate lazily, we evaluate `(6666^2)` twice. But if we evaluate strictly, we evaluate `(7777^2)` even though we don't need to. 
But if we use interaction calculus (which is very difficult to describe in text because text is not very good at describing graphs), we "incrementally clone" values as we use them. Whereas in something like lambda calculus we clone the entire expression if we use it multiple times.

Now, as it happens, Haskell actually *does* evaluate this without duplicating work, however it's ability to do so breaks down if the computed pieces are inside of a lambdas. So if you are trying to evaluate.

```hs
let x = expensive 67 in x + x
```

Then the thunk of expensive 67 is only evaluted once even though you use it twice. But if you do something like this inside of a lambda
```hs
f = \x -> let y = expensive 67 in y + x
```

Haskell's sharing does not allow for that. And while there are techniques to move it into a more optimized piece of code, like moving the expensive 67 out of scope so it is only evaluated once, that is itself a compiler optimization that is allowed for by static analysis of the computation graph. Which is still moreso moving away from lambda calculus towards some graphical format. Be that graph rewriting or graph relabeling.

An example of the sharing allowing for decreased work is shown on the next page.

#pagebreak()
```
a = {0, 1, 2, 3, 4}
b = {5, 6}
f(x) = 2*x
g(x) = x-1
h(a, b) = f(a) + g(b)

# Naive:
[[h(i, j) for i in range(5)] for j in range(5, 6+1)]
h(0, 5) = f(0) + g(4) -> 3 interactions
h(0, 6) = f(0) + g(5) -> 3 interactions

h(1, 5) = f(1) + g(4) -> 3 interactions
h(1, 6) = f(1) + g(5) -> 3 interactions

h(2, 5) = f(2) + g(4) -> 3 interactions
h(2, 6) = f(2) + g(5) -> 3 interactions

h(3, 5) = f(3) + g(4) -> 3 interactions
h(3, 6) = f(3) + g(5) -> 3 interactions

h(4, 5) = f(3) + g(4) -> 3 interactions
h(4, 6) = f(3) + g(5) -> 3 interactions

Total interactions:
n*m (10) equations. Each of which has 3 interactions. So 30 interactions in total.

# Sharing:
f(0) = 0
f(1) = 2
f(2) = 4
f(3) = 6
f(4) = 8

g(5) = 4
g(6) = 5

n+m (7) interactions for precalculation

h(0, 5) = 0 + 4 -> 1 interactions
h(0, 6) = 0 + 5 -> 1 interactions

h(1, 5) = 2 + 4 -> 1 interactions
h(1, 6) = 2 + 5 -> 1 interactions

h(2, 5) = 4 + 4 -> 1 interactions
h(2, 6) = 4 + 5 -> 1 interactions

h(3, 5) = 6 + 4 -> 1 interactions
h(3, 6) = 6 + 5 -> 1 interactions

h(4, 5) = 8 + 4 -> 1 interactions
h(4, 6) = 8 + 5 -> 1 interactions

Total interactions:
n*m (10) equations. Each of which has only 1 inteaction. Then the shared n+m (7) interactions. This makes 17 interactions in total.
```

#pagebreak()

And here is a visual example of how graphs can be helpful.

- Left side is lambda calculus. The number of terms doubles each time. Because it is a tree, it is not possible to share.
- Right side is interaction calculus. Because it is a graph, sharing is very easy.

#image("tree-vs-graph.png")

#pagebreak()
= Merit
This language will be useful for program writers who wish to avoid having their algorithms do unnecessary work. Current high level languages automate allocation/deallocation and infer datatype based on usage, allowing the programmers to focus on writing their algorithms instead of worrying about the hardware on which their code runs or quirks inherit to the operation of computers. These properties makes languages like Python popular for statisticians and mathematicians. Yet virtually all high level languages do not have constructs to efficiently avoid duplication of work. This means that beyond just focusing on the logic of the code, the algorithm writer must manually implement optimization techniques such as memoization. Yet in some cases, even manually implementing techniques to maximize reuse cannot compare to the efficiency of interaction calculus, #link("https://stackoverflow.com/questions/31707614/why-are-%CE%BB-calculus-optimal-evaluators-able-to-compute-big-modular-exponentiation")[where even primitive mathematical operations such as exponentiation of integers can be encoded as shared subgraphs], allowing operations such as `10 ^ 10 % 13` to be solved more quickly than if a conventional encoding of integers was used.

Additionally, this language will fill the niche of being a typed Lisp. Lisps are valuable for their elegant S-expression based syntax and uncontrived tree program structure, reminiscent of lambda calculus. However, they lack the powerful type systems, both making them difficult to develop in large code bases due to the lack of rich type signatures, and difficult to create logically rigorous proofs like those of theorem provers. Lisps also have a very rare ability among programming languages. Macros allow developers to write whatever syntax they want and have it translated into standard lisp. An example of the use of syntax sugar is Haskell's `do` expressions. Lisps let users write their own syntax sugar within the language instead of it being unmodifiable.

While experimentation will need to be done before it is possible to say for sure, it will likely be simple to parallelize operations in this language because interaction calculus exhibits "strong confluence" which means that (if a program halts) than it should take the same number of steps no matter the route you took to get there. Additionally, all graph rewrites are associative (`a(bc)=(ab)c`). This means that rewrites can be grouped based on whichever expressions the interpreter deems are ready to be evaluated next. All in all, this means that separate rewrites can be accomplished in parallel, as different threads won't need to coordinate with each other. 

There is an implementation of Calculus of Constructions #link("https://github.com/VictorTaelin/interaction-calculus-of-constructions/")[using interaction calculus.]. It acts as a very simple preprocessor that outputs two interaction calculus programs: the untyped program and a program that expresses the type checking. It is however not a very well known about extension to the language. We discovered this while exploring adding a type system to interaction calculus and from what we could tell, going off other peoples research, the easiest kind or type system to add is Calculus of Constructions. That is probably the biggest merit of making HasCOIL into a proof assistant. It is surprisingly easy to give interaction calculus a type system capable of expressing dependent types. It still would be a stretch goal or a post-class development, but the ability to prove aspects of the programs represented in the language is incredibly powerful.

For asynchronous circuit design, being able to make sure that loops won't deadlock is extremely important. For embedded software, debugging is so much more annoying than traditional software, so making sure mission critical components work as intended before it goes to the microcontroller makes the software more likely to work properly. There are many advantages in many domains to being able to write proofs about your code alongside the code.

#pagebreak()
= Action Plan

Much of the code will be built through term rewriting. This will look a lot like pattern matching in Haskell, but as that is based on lambda calculus, the underlying mechanisms are quite different. And here there is the ability to make use of 

#quote(block: true, attribution: link("https://github.com/HigherOrderCO/HVM4/blob/main/docs/theory/interaction_calculus.md")[HVM4 Docs])[
  Duplications: allow a single value to exist in multiple locations
  
Superpositions: allow multiple values to exist in a single location
]

Example of duplications
```lisp
(letdup {x y} 67)
(Pair x y)
---
(Pair 67 67)
```

Example of superpositions
```lisp
(+ 5 {1 2})
---
{6 7}
```

Example of interaction between multiple superpositions
```lisp
(+ {3 7} {1 2})
---
{{4 8} {5 9}}
```
Which looks a bit like how FOIL-ing when you multiply two polynomials

The reason that these superpositions are nested like that is that superpositions are something that are represented as nodes in the graph of the expression, and this formatting comes from reading off the graph directly, where these superposition nodes are nested in a similar way, and they become nested like that because evaluating a superposition is done through graph rewriting.

And because there isn't much of a distinction between functions and everything else, we can also apply an argument to a superposition.

```lisp
(defn f (x) (* 2 x))
(defn g (x) (* 2 (+ 1 x)))
{f g}(3)
{(* 2 3) (* 2 (+1 3))}
{6 7}
```

Some of the improvements we can make over past iterations of similar ideas, but the pieces are disjoint enough that even a unification of those ideas into a single coherent project would still be sufficient to be interesting.

Also, one of main academics behind this (`Victor Taelin`) has had slow mental faculty reduction due to his heavy LLM usage. So there is probably a good amount of places where we can improve on his work `:p`.

What has been discussed in this section so far is what we intend to do as a base. The language will be a lisp-like frontend for an interaction calculus underlying evaluation approach. It will expose to the user the ability to define their own nodes, use more traditional lambdas and the nodes associated with them, and allow superposition with curly braces.

#pagebreak()
= Limitations

The incremental resource usage is cool, but because of how computers work it is sometimes faster to just clone / delete large sections in bulk. Which might mean that even if the time complexity is faster, the algorithm might run somewhat slower. 

Similarly, GHC has been developed for years by a bunch of very smart people. We are 3 undergrads. We probably won't be as fast as GHC can be `:p` even if the performance ceiling for this is higher than it would be for that.

= Future Work

#link("https://gist.github.com/VictorTaelin/9061306220929f04e7e6980f23ade615")[It is seemingly possible to use superpositions for SAT-solving like tasks]. This feels a bit like how #link("https://rosettacode.org/wiki/Amb")[Amb] can be used to run through all possibilities and find results that match a predicate, but because of how superpositions work, they allow for some degree of the work to be shared between the execution running through each set of values separately. Rather than more naively back-tracking.

This usage of superpositions #link("https://www.youtube.com/watch?v=GddkKIhDE2c")[might also allow for program search]. The thing demo'd here is closed source, but we might be able to re-create it.

We would like to explore a few more concepts, but it is unlikely we will be able to get these done before the end of the class. These are: a proof assistant/checker system, a more visual way to see what the lambda expression looks like, and access to lower level functionality like syscalls or C FFI.