;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; GNU GENERAL PUBLIC LICENSE ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; ES-1-outcome (Endogenous Separation conditioned on the previous outcome)
;; is a model designed to formally analyze the mechanism of endogenous
;; separation (or conditional dissociation) in the evolutionary
;; emergence of cooperation.
;; Copyright (C) 2025
;; Luis R. Izquierdo, Segismundo S. Izquierdo & Robert Boyd
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;
;; Contact information:
;; Luis R. Izquierdo
;;   University of Burgos, Spain.
;;   e-mail: lrizquierdo@ubu.es


extensions [array rnd]

;;;;;;;;;;;;;;;;;
;;; variables ;;;
;;;;;;;;;;;;;;;;;

globals [
  C D L
    ;; these are labels for the actions, to improve code readability
    ;; C (Cooperate) = 0, D (Defect) = 1 and L (Leave) = 2

  %-CC %-CD %-DD
    ;; these variables store the percentage of
    ;; each of the outcomes in the tick
  n-of-outcomes

  strategy-payoffs
  strategy-frequencies
  strategy-numbers

  C-if-CC-players  D-if-CC-players LD-if-CC-players
  C-if-CD-players  D-if-CD-players LD-if-CD-players
  C-if-DC-players  D-if-DC-players LD-if-DC-players
  C-if-DD-players  D-if-DD-players LD-if-DD-players
  action-first-C-players

  exogenously-separated

  strategy-name-number-and-color-trios

]

breed [players player]

players-own [
  action-first    ;; action-first is either 0 (C) or 1 (D)
    ;; the following variables can take the values 0 (C), 1 (D) of 2 (L);
    ;; actions C and D imply that the agent stays with the current partner
  decision-if-CC  ;; action if both cooperated
  decision-if-CD  ;; if THE AGENT cooperated and THE PARTNER defected
  decision-if-DC  ;; if THE AGENT defected and THE PARTNER cooperated
  decision-if-DD  ;; action if both defected

  next-action     ;; if the partnership is broken, next-action = action-first
  active-action   ;; the action used to play the game

  mate
  payoff
  strategy-number
  new-partnership?
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; the following procedure is called when the model is first loaded
to startup
  clear-all
  no-display
  setup-variables
  setup-players
  setup-graph
  reset-ticks
  compute-strategy-frequencies
end

to setup-variables
  set C 0
  set D 1
  set L 2

  set strategy-numbers range 162
  ;; 2 * (3 ^ 4) = 162 strategies
  ;; In the model without the option to leave,
  ;; we will only use 32 (= 2^5) of them
end

to setup-players
  create-players n-of-players [
    set action-first -1
    set decision-if-CC -1
    set decision-if-CD -1
    set decision-if-DC -1
    set decision-if-DD -1
    set strategy-number -1
    set mate nobody
    set payoff -1
    set hidden? true
  ]

  if-else initial-strategy = "random" [
    ;; random distribution of initial strategies for the whole population
    let n-of-possible-actions ifelse-value option-to-leave? [3][2]
    ask players [
      set action-first random 2
      set decision-if-CC random n-of-possible-actions
      set decision-if-CD random n-of-possible-actions
      set decision-if-DC random n-of-possible-actions
      set decision-if-DD random n-of-possible-actions

      set strategy-number (genome-to-decimal genome)
        ;; genome is a reporter that reports the set of genes,
        ;; e.g. [C D L L D]
        ;; genome-to-decimal converts a genome into a decimal number
        ;; strategies are numbered from 0 (0 0 0 0 0) to 161 (1 2 2 2 2)

      set active-action -1
      set next-action action-first
    ]
  ]
  [
    ask players [
      set strategy-number name-to-decimal initial-strategy
      setup-new-strategy
    ]
  ]
end

to setup-graph
  set-current-plot "Strategy Distribution"
  let strategy-name-and-color-pairs read-from-string plot-the-following-strategy-names-and-colors
  set strategy-name-number-and-color-trios map [[p] -> (list (first p) (name-to-decimal first p) last p)] strategy-name-and-color-pairs
  foreach strategy-name-and-color-pairs [ p ->
    create-temporary-plot-pen first p
    set-plot-pen-mode 1
    set-plot-pen-color last p
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; run-time procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go

  make-couples
  ask players [update-action]
  ask players [play]

  gather-data

  ask players [update-next-action]

  ;; EXOGENOUS separation
  conduct-exogenous-separation

  ;; ENDOGENOUS separation
  if option-to-leave? [conduct-endogenous-separation]

  tick
  if show-plots? [update-graphs]

  ;; REVISION
  conduct-revisions

  if (count players != n-of-players) [adjust-num-players]
end

to make-couples
  ask players [
    set new-partnership? ifelse-value mate = nobody [true][false]
  ]
  ask players [
    if (mate = nobody) [
      set mate one-of other players with [mate = nobody]
      ask mate [set mate myself]
    ]
  ]
end

to update-action
  set active-action ifelse-value (random-float 1.0 < action-error)
    [ (next-action + 1) mod 2 ] ;; flip C <-> D on error
    [ next-action ]
end

to play
  set payoff payoff-for active-action ([active-action] of mate)
end

to-report payoff-for [my-action her-action]
  report ifelse-value my-action = C
    [ ifelse-value her-action = C [CC-payoff][CD-payoff] ]
    [ ifelse-value her-action = C [DC-payoff][DD-payoff] ]
end

to update-next-action
  let mate-s-action ([active-action] of mate)

  set next-action ifelse-value (active-action = C)
  [ ifelse-value mate-s-action = C [decision-if-CC][decision-if-CD] ]
  [ ifelse-value mate-s-action = C [decision-if-DC][decision-if-DD] ]
  ;; if next-action here takes the value L (Leave, 2),
  ;; next-action will be set to action-first in procedure
  ;; conduct-endogenous-separation -> break-partnership
end

to conduct-exogenous-separation
  ask players with [random-float 1.0 < 1 - (sqrt (1 - 1 / exp-n-of-interactions))] [
    if (mate != nobody) [ break-partnership ]
    ;; if mate = nobody, this player has already everything set up
    ;; (see break-partnership), so there is nothing else to do
  ]
  set exogenously-separated players with [mate = nobody]
end

to break-partnership
  ask mate [
    set next-action action-first
    set mate nobody
  ]
  set next-action action-first
  set mate nobody
end

to conduct-endogenous-separation
  ask players [
    if (mate != nobody) and (next-action = L) [
      break-partnership
    ]
  ]
end

to conduct-revisions

  let players-to-revise exogenously-separated with [random-float 1.0 < prob-revision]

  let num-players-to-revise count players-to-revise

  compute-strategy-payoffs ;; this sets the value of strategy-payoffs
  let new-strategies rnd:weighted-n-of-list-with-repeats num-players-to-revise strategy-numbers [[s] -> array:item strategy-payoffs s]
    ;; new strategies is ordered, but this is not a problem,
    ;; since agents in players-to-revise are in random order

  let i 0

  ask players-to-revise [

    set strategy-number ifelse-value (random-float 1.0 < prob-experimentation)
      [ strategy-after-mutation-in-one-gene ]
      [ item i new-strategies ]

    setup-new-strategy
    set i (i + 1)
  ]
end

to-report strategy-after-mutation-in-one-gene
  ifelse option-to-leave?

  [   ;; EXPERIMENTATION WITH THE OPTION TO LEAVE
    ifelse (random-float 1.0 < 0.2)
    [ ;; mutation on the first gene
      report (strategy-number + 81) mod 162
    ]
    [ ;; mutation on any of the other four genes
      let g decimal-to-genome strategy-number
      let rd-position (1 + random 4)
      let current-value item rd-position g
      report genome-to-decimal replace-item rd-position g ((current-value + 1 + random 2) mod 3)
    ]
  ]

  [ ;; EXPERIMENTATION WITHOUT THE OPTION TO LEAVE
    let g decimal-to-genome strategy-number
    let rd-position (random 5)
    let current-value item rd-position g
    report genome-to-decimal replace-item rd-position g ((current-value + 1) mod 2)
  ]

end

to compute-strategy-payoffs
  ;; compute the payoff of strategies (sum of payoffs of all agents that are using each strategy)
  set strategy-payoffs array:from-list n-values 162 [0]
  let tmp 0
  ask players [
    set tmp (array:item strategy-payoffs strategy-number)
    array:set strategy-payoffs strategy-number (tmp + payoff)
  ]
end

to adjust-num-players
  let adjustment (n-of-players - (count players))
  if adjustment != 0 [
  ifelse adjustment > 0
    [
      create-players adjustment [
        set mate nobody
        set strategy-number ifelse-value (initial-strategy = "random")
          [ifelse-value option-to-leave?
            [random 162]
            [genome-to-decimal n-values 5 [random 2]]]
          [name-to-decimal initial-strategy]
        setup-new-strategy
      ]
    ]
    [
      ask n-of (0 - adjustment) players [
        if (mate != nobody)  [ break-partnership ]
        die
      ]
    ]
  ]
end

to setup-new-strategy
  ;; this procedure is only used by newborns
  ;; first, update strategy variables from strategy-number
;  set [action-first decision-if-CC decision-if-CD decision-if-DC decision-if-DD]
;    decimal-to-genome strategy-number
  let tmp decimal-to-genome strategy-number
  set action-first    item 0 tmp
  set decision-if-CC  item 1 tmp
  set decision-if-CD  item 2 tmp
  set decision-if-DC  item 3 tmp
  set decision-if-DD  item 4 tmp

  ;; and then set next-action
  set next-action action-first
  set hidden? true
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;;    Statistics    ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to gather-data
  let n-of-CC (count players with [active-action = C and [active-action] of mate = C]) / 2
  let n-of-DD (count players with [active-action = D and [active-action] of mate = D]) / 2
  let n-of-CD (count players with [active-action = C and [active-action] of mate = D])
  set n-of-outcomes (n-of-CC + n-of-DD + n-of-CD)

  set %-CC (n-of-CC / n-of-outcomes)
  set %-CD (n-of-CD / n-of-outcomes)
  set %-DD (n-of-DD / n-of-outcomes)

  compute-strategy-frequencies

  set C-if-CC-players count players with [decision-if-CC = C]
  set D-if-CC-players count players with [decision-if-CC = D]
  set LD-if-CC-players (count players with [decision-if-CC = L and action-first = D])

  set C-if-CD-players count players with [decision-if-CD = C]
  set D-if-CD-players count players with [decision-if-CD = D]
  set LD-if-CD-players (count players with [decision-if-CD = L and action-first = D])

  set C-if-DC-players count players with [decision-if-DC = C]
  set D-if-DC-players count players with [decision-if-DC = D]
  set LD-if-DC-players (count players with [decision-if-DC = L and action-first = D])

  set C-if-DD-players count players with [decision-if-DD = C]
  set D-if-DD-players count players with [decision-if-DD = D]
  set LD-if-DD-players (count players with [decision-if-DD = L and action-first = D])

  set action-first-C-players count players with [action-first = C]
end

to compute-strategy-frequencies
  ;; compute the distribution of strategies (number of agents that are using each strategy)
  set strategy-frequencies array:from-list n-values 162 [0]
  let tmp 0
  ask players [
    set tmp (array:item strategy-frequencies strategy-number)
    array:set strategy-frequencies strategy-number (tmp + 1)
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;;    Reporters     ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to-report genome
  report (list
    action-first
    decision-if-CC
    decision-if-CD
    decision-if-DC
    decision-if-DD
  )
end

to-report genome-to-decimal [g]
  report reduce [ [?1 ?2] -> 3 * ?1 + ?2 ] g
end

to-report decimal-to-genome [n]
  let g []

  let remain n
  repeat 4 [
    set g fput (remain mod 3) g
    set remain floor (remain / 3)
  ]

  report fput (remain mod 2) g
end

to-report name-of-genome [g]
  report but-last reduce word map [
    [n] -> (ifelse-value
    n = C [ "C-" ]
    n = D [ "D-" ]
    n = L [ "L-" ])
  ] g
end

to-report name-of-strategy [s]
  report name-of-genome decimal-to-genome s
end

to-report name-to-decimal [name]
  let simple-name remove "-" name
  let decimal 0
  let i 0
  repeat 5 [
    set decimal 3 * decimal + (ifelse-value
      (item i simple-name) = "C" [0]
      (item i simple-name) = "D" [1]
      (item i simple-name) = "L" [2]
    )
    ;; read-from-string only takes literals
    set i (i + 1)
  ]
  report decimal
end

;;;;;;;;;;;;;;;;;;;;;;;;
;;;      Plots       ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to update-graphs
  ;; all graphs refer to the situation before the new breed comes in.

  set-current-plot "Outcome Frequencies"
    set-current-plot-pen "DD"     plotxy ticks 1
    set-current-plot-pen "CD"     plotxy ticks  1 - %-DD
    set-current-plot-pen "CC"     plotxy ticks  %-CC

  let current-n-of-players (count players)
  let n-of-single-players (count (players with [mate = nobody]))

  set-current-plot "Action after CC"
    set-current-plot-pen "Leave-D"    plotxy ticks  1
    set-current-plot-pen "Leave-C"    plotxy ticks  1 - (LD-if-CC-players / current-n-of-players)
    set-current-plot-pen "Stay-D"     plotxy ticks  (C-if-CC-players / current-n-of-players) + (D-if-CC-players / current-n-of-players)
    set-current-plot-pen "Stay-C"     plotxy ticks  (C-if-CC-players / current-n-of-players)

  set-current-plot "Action after CD"
    set-current-plot-pen "Leave-D"    plotxy ticks  1
    set-current-plot-pen "Leave-C"    plotxy ticks  1 - (LD-if-CD-players / current-n-of-players)
    set-current-plot-pen "Stay-D"     plotxy ticks  (C-if-CD-players / current-n-of-players) + (D-if-CD-players / current-n-of-players)
    set-current-plot-pen "Stay-C"     plotxy ticks  (C-if-CD-players / current-n-of-players)

  set-current-plot "Action after DC"
    set-current-plot-pen "Leave-D"    plotxy ticks  1
    set-current-plot-pen "Leave-C"    plotxy ticks  1 - (LD-if-DC-players / current-n-of-players)
    set-current-plot-pen "Stay-D"     plotxy ticks  (C-if-DC-players / current-n-of-players) + (D-if-DC-players / current-n-of-players)
    set-current-plot-pen "Stay-C"     plotxy ticks  (C-if-DC-players / current-n-of-players)

  set-current-plot "Action after DD"
    set-current-plot-pen "Leave-D"    plotxy ticks  1
    set-current-plot-pen "Leave-C"    plotxy ticks  1 - (LD-if-DD-players / current-n-of-players)
    set-current-plot-pen "Stay-D"     plotxy ticks  (C-if-DD-players / current-n-of-players) + (D-if-DD-players / current-n-of-players)
    set-current-plot-pen "Stay-C"     plotxy ticks  (C-if-DD-players / current-n-of-players)

  set-current-plot "Action with new partner"
    set-current-plot-pen "D"     plotxy ticks 1
    set-current-plot-pen "C"     plotxy ticks (action-first-C-players / current-n-of-players)

  set-current-plot "% Individuals separated"
    plotxy ticks 100 * (n-of-single-players / current-n-of-players)

  set-current-plot "Avg Payoff"
    set-current-plot-pen "all"
    plotxy ticks mean [payoff] of players
    if (any? players with [new-partnership?]) [
      set-current-plot-pen "new couples"
      plotxy ticks mean [payoff] of players with [new-partnership?]
    ]

  set-current-plot "Strategy Distribution"
    set-plot-y-range 0 n-of-players
    let selected-strategies-frequencies map [[t] -> array:item strategy-frequencies (item 1 t)] strategy-name-number-and-color-trios
    let bar sum selected-strategies-frequencies

    foreach strategy-name-number-and-color-trios [ t ->
      set-current-plot-pen first t
      plotxy ticks bar
      set bar bar - (array:item strategy-frequencies (item 1 t))
    ]
end

to show-?-main-strategies [n]
  let strategy-names map name-of-strategy strategy-numbers
  let pairs (map [[name f] -> list name f] strategy-names array:to-list strategy-frequencies)
  set pairs sort-by [[l1 l2] -> last l1 > last l2] pairs
  set pairs (sublist pairs 0 n)
  show pairs
end
@#$#@#$#@
GRAPHICS-WINDOW
304
289
480
466
-1
-1
56.0
1
10
1
1
1
0
1
1
1
-1
1
-1
1
1
1
1
ticks
30.0

SLIDER
15
130
229
163
n-of-players
n-of-players
2
1000
500.0
2
1
NIL
HORIZONTAL

SLIDER
15
55
135
88
CC-payoff
CC-payoff
0
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
142
56
259
89
CD-payoff
CD-payoff
0
10
0.0
1
1
NIL
HORIZONTAL

SLIDER
15
91
135
124
DC-payoff
DC-payoff
0
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
142
92
259
125
DD-payoff
DD-payoff
0
10
1.0
1
1
NIL
HORIZONTAL

BUTTON
12
429
93
462
setup
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
96
465
167
498
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
266
10
632
239
Outcome Frequencies
NIL
NIL
0.0
1.0
0.0
1.0
true
true
"" ""
PENS
"DD" 1.0 1 -2674135 true "" ""
"CD" 1.0 1 -4539718 true "" ""
"CC" 1.0 1 -13345367 true "" ""

MONITOR
647
10
720
55
% of CCs
100 * %-CC
2
1
11

MONITOR
1004
10
1079
55
% of DDs
100 * %-DD
2
1
11

MONITOR
820
10
889
55
% of CDs
100 * %-CD
2
1
11

PLOT
861
61
1079
240
Avg Payoff
NIL
NIL
0.0
10.0
0.0
0.0
true
true
"" ""
PENS
"all" 1.0 0 -16777216 true "" ""
"new couples" 1.0 0 -955883 true "" ""

PLOT
11
502
260
662
% Individuals separated
NIL
% Separated
0.0
10.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
14
202
262
235
exp-n-of-interactions
exp-n-of-interactions
1
100
20.0
1
1
NIL
HORIZONTAL

BUTTON
12
465
93
498
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
13
273
261
306
prob-experimentation
prob-experimentation
0
0.1
0.05
0.001
1
NIL
HORIZONTAL

PLOT
640
243
855
448
Action after CC
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Leave-D" 1.0 1 -1184463 true "" ""
"Leave-C" 1.0 1 -10899396 true "" ""
"Stay-D" 1.0 1 -2674135 true "" ""
"Stay-C" 1.0 1 -13345367 true "" ""

MONITOR
176
446
260
499
NIL
ticks
17
1
13

PLOT
640
451
855
665
Action after DC
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Leave-D" 1.0 1 -1184463 true "" ""
"Leave-C" 1.0 1 -10899396 true "" ""
"Stay-D" 1.0 1 -2674135 true "" ""
"Stay-C" 1.0 1 -13345367 true "" ""

PLOT
640
61
856
240
Action with new partner
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"D" 1.0 1 -2674135 true "" ""
"C" 1.0 1 -13345367 true "" ""

PLOT
267
242
633
486
Strategy Distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS

TEXTBOX
17
35
77
53
Payoffs
13
0.0
1

SLIDER
14
166
229
199
action-error
action-error
0
0.1
0.05
0.01
1
NIL
HORIZONTAL

INPUTBOX
14
328
161
388
initial-strategy
random
1
0
String

TEXTBOX
157
313
273
399
Examples of values:\n    * D-C-L-C-C\n    * C-C-D-C-D\n    * D-L-L-L-L\n    * D-C-L-L-C
11
0.0
1

PLOT
861
243
1079
448
Action after CD
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Leave-D" 1.0 1 -1184463 true "" ""
"Leave-C" 1.0 1 -10899396 true "" ""
"Stay-D" 1.0 1 -2674135 true "" ""
"Stay-C" 1.0 1 -13345367 true "" ""

PLOT
860
451
1079
665
Action after DD
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Leave-D" 1.0 1 -1184463 true "" ""
"Leave-C" 1.0 1 -10899396 true "" ""
"Stay-D" 1.0 1 -2674135 true "" ""
"Stay-C" 1.0 1 -13345367 true "" ""

INPUTBOX
268
491
628
625
plot-the-following-strategy-names-and-colors
[ [\"C-C-D-C-D\" 87]  [\"C-C-D-L-L\" 84] \n  [\"C-C-L-C-L\" 107] [\"C-C-L-L-L\" 104] \n  [\"C-C-L-C-C\" 97]  [\"C-C-L-C-D\" 94]\n  [\"D-C-L-C-C\" lime] [\"D-C-L-L-C\" green] \n  [\"D-C-L-D-C\" 75][\"D-D-L-D-C\" 17]\n  [\"D-D-D-D-D\" red] [\"D-L-L-L-L\" orange] ] 
1
1
String (commands)

BUTTON
268
630
494
663
show 5 most popular strategies
show-?-main-strategies 5
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
497
631
627
664
show-plots?
show-plots?
0
1
-1000

TEXTBOX
16
397
256
432
You can also type 'random' to make agents' initial strategy random
11
0.0
1

SLIDER
14
237
186
270
prob-revision
prob-revision
0
1
0.1
0.01
1
NIL
HORIZONTAL

SWITCH
96
10
257
43
option-to-leave?
option-to-leave?
0
1
-1000

@#$#@#$#@
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
