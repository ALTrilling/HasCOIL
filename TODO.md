I think the current plan would probably be to:
- Create a small syntax for working with the language. This could be through some structure in the host language at the start, thoug we over time we should move in the direction of the the construction of a small lisp-like-language (LLL). Also this annoys the prof :3


Example syntax:

Stylistically, largely going from: [the pattern matching file I showed before](https://github.com/HigherOrderCO/HVM2/blob/73da3bbc4b222fb8f044fcc5dad202e9752a0abc/HOW.md)
Though the problem that it mentions about how "If a lambda that clones its argument is itself cloned, then its clones aren't allowed to clone each-other." is an issue that was fixed by the time that [HVM4 was a thing. They went with using "labels"](https://github.com/HigherOrderCO/HVM4/blob/main/docs/theory/interaction_calculus.md)
This is the issue that was mentioned at the end of the talk [Interaction Combinators: The Hidden Patterns of Computation?](https://www.youtube.com/watch?v=F880mnxu9c0). One of the makers of that talk went into more details [here](https://marvinborner.de/ba.pdf) on the problem and potential solutions, but if you want a quick summary, look at section 1.3.6 (page 29)
As for the type system, that actually seems pretty doable. We can mostly yoink from the [interaction calculus of constructions](https://github.com/VictorTaelin/interaction-calculus-of-constructions) repo. Though to allievate any confusion (since I needed to stare at a minute before I got it), the way that that works is simply by writing out two programs. The first is a program to typecheck. The second is the program itself. Both of these programs are run through [HVM1](https://github.com/HigherOrderCO/HVM1) (which is a eh... decently smallish rust project). It's pretty well organized and it seems relatively easy to see how the different nodes create connections in the network. The [rulebook.rs](https://github.com/HigherOrderCO/HVM1/blob/master/src/language/rulebook.rs) file is also useful as it shows how to convert from the pattern matching syntax into the network's wires.
If you would like to see an implentation with everything in one place, [this is a Python version](https://gist.github.com/LeeeeT/f3ae48dd9279f6fd8db8184ffdb183a6). That person has some other gist's that are similar, but afaik this is the shortest / simplest one.
Also, I had forgotten how small the [HVM2 codebase](https://github.com/HigherOrderCO/HVM2/tree/73da3bbc4b222fb8f044fcc5dad202e9752a0abc/src) was. (Combination of Rust and C). (I am using an older commit since that uses the more familiar pattern matching syntax)

- Make an implementation of an HVM-like system. Previously I posted some links (which didn't make it into the proposal submission, they are just earlier links here) that show the code for this. It does actually seem faaaaaairly doable.
- Have the pattern matching code of the LLL compile into interaction calculus nodes. I suspect that scott encodings will make this MUCH easier, since they allow for IC nodes to specify which path in the matcher to go down, so matching can be done by just supplying the appropriate function. 
- Since ICoC works by simply compling to a interaction calculus, we actually don't need to do much special for that. We can just add type annotations to our language, and then (perhaps abusing the fact that this is a lisp we could do it homoiconically) split it into the type section and the code section. Then evaluate both of those as seperate programs. Though if the type checker program fails, we just throw some kind of error.
Oh btw, the prior ICoC repo was based on HVM1, but I checked with one of the creators of HVM, and was informed that ICoC should still work for other interaction calculus systems. So even if we deviate a bit from HVM1, it should be fine.


Steps:
Start with the inital body and rewrite book.

Pretty much all of the scott encodings here where yoinked from the wikipedia page.
https://en.wikipedia.org/wiki/Mogensen%E2%80%93Scott_encoding

Scott encodings make brain happy


```py
zero  = lambda on_zero: lambda on_succ: on_zero
succ  = lambda n: lambda on_zero: lambda on_succ: on_succ(n)

one   = succ(zero)
two   = succ(one)
three = succ(two)

# The "*" isn't anything special. It just forces me to put key word arguments rather than positional arguments.
def nat_match(n, *, on_zero, on_succ):
    return n(on_zero)(on_succ)

def to_int(n):
    return nat_match(n,
      on_zero=0,
      on_succ=lambda pred: 1 + to_int(pred)
)

def to_word(n):
    return nat_match(n,
        on_zero = "zero",
        on_succ = lambda p: nat_match(p,
            on_zero = "one",
            on_succ = lambda p2: nat_match(p2,
                on_zero = "two",
                on_succ = lambda p3: nat_match(p3,
                    on_zero = "three",
                    on_succ = lambda _: "many"
                )
            )
        )
    )


# m < n. Peel both simultaneously. if m hits zero first, True
def lt(m, n):
    return nat_match(n,
        on_zero = False, # n hit zero first.
        on_succ = lambda n_pred: nat_match(m,
            on_zero = True, # We already validated that n > 0, so if m == 0, than True
            on_succ = lambda m_pred: lt(m_pred, n_pred) # Recurse to peel from both
        )
    )

def gt(m, n):
    return lt(n, m)

def eq(m, n):
    return nat_match(m,
        on_zero = nat_match(n,
            on_zero = True, # on_zero for both `m` and `n`. Both are `0`
            on_succ = lambda _: False
        ),
        on_succ = lambda m_pred: nat_match(n,
            on_zero = False,
            on_succ = lambda n_pred: eq(m_pred, n_pred) # Recurse to peel from both
        )
    )

def lte(m, n): return lt(m, n) or eq(m, n)

def gte(m, n): return gt(m, n) or eq(m, n)

# Example of what is happening with modification to the environment
# >>> zero = lambda f: f["on_zero"]
# >>> succ = lambda n: lambda f: f["on_succ"](n)
# >>> handler = {"on_zero": lambda: "zero", "on_succ": lambda n: "succ"}
# >>> zero(handler)()
# 'zero'
# >>> succ(zero)(handler)
# 'succ' 

T = lambda t: lambda f: t
F = lambda t: lambda f: f

NIL  = lambda n: lambda c: n
CONS = lambda fst: lambda snd: (
    lambda n: lambda c: c(fst)(snd)
)
IsEmpty = lambda l: l(T)(lambda fst: lambda snd: F)
Fst    = lambda l: l(NIL)(T)
Snd    = lambda l: l(NIL)(F)

# From https://github.com/HigherOrderCO/HVM2/blob/73da3bbc4b222fb8f044fcc5dad202e9752a0abc/HOW.md
# (Map f Nil)         = Nil
# (Map f (Cons x xs)) = (Cons (f x) (Map f xs))
# 
# (Main) =
#   let list = (Cons 1 (Cons 2 Nil))
#   let add1 = λx (+ x 1)
#   (Map add1 list)

def list_match(lst, *, on_nil, on_cons):
    return lst(on_nil)(on_cons)

# Realized this is cheating cause it uses Python's built in recursion
# def Map(f, lst):
#     return list_match(lst,
#         on_nil  = NIL,
#         on_cons = lambda x: lambda xs: CONS(f(x))(Map(f, xs))
#     )
Y = lambda f: (lambda x: f(lambda v: x(x)(v)))(lambda x: f(lambda v: x(x)(v)))

Map = lambda f: Y(lambda self: lambda lst: list_match(lst,
    on_nil  = NIL,
    on_cons = lambda x: lambda xs: CONS(f(x))(self(xs))
))

# Which allows for 
x = Map(succ)(CONS(one)(CONS(two)(CONS(three)(NIL))))
print(to_int(Fst(x)))
print(to_int(Fst(Snd(x))))

def from_python_list(lst):
    result = NIL
    for x in reversed(lst):
        result = CONS(x)(result)
    return result

def to_python_list(lst):
    result = []
    current = lst
    while not list_match(current, on_nil=True, on_cons=lambda _: lambda _: False):
        result.append(Fst(current))
        current = Snd(current)
    return result

print(to_python_list(Map(to_int)(x)))

# I didn't really end up using `Maybe`, but here it is.
nothing   = lambda on_nothing: lambda on_just: on_nothing
just      = lambda x: lambda on_nothing: lambda on_just: on_just(x)

def maybe_match(m, *, on_nothing, on_just):
    return m(on_nothing)(on_just)
 
def maybe_map(f, m):
    return maybe_match(m, on_nothing=nothing, on_just=lambda x: just(f(x)))
```

From https://github.com/HigherOrderCO/HVM2/blob/73da3bbc4b222fb8f044fcc5dad202e9752a0abc/HOW.md
```clj
; (+ 1 {2 3})
; (let {x y} 67)
(let {x y} [(+ 1 1) (+ 2 2) (+ 3 3)])
(Pair x y)
; Evaluated by
(let {x y} [(+ 2 2) (+3 3)])
(let {a b} (+ 1 1))
(let {a b} 2)
(Pair
  2 : x
  2 : y
)

; (Cons (+ 1 1) (Cons (+ 2 2) (Cons (+ 3 3) Nil)))



(:main
  
)
```

<!---->
<!-- ```clj -->
<!-- (:book  -->
<!---->
<!--     ; [(Fst (Pair x y)) :> x] -->
<!--     (:include "./book/*") -->
<!-- ) -->
<!---->
<!---->
<!-- (BODY) -->
<!-- (dup {a b} 67) -->
<!---->
<!-- (Cons (+ 1 1) (Cons (+ 2 2) (Cons (+ 3 3) Nil))) -->
<!-- ``` -->
<!---->
Scott encodings make brain happy

