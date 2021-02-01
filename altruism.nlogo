globals [
  ;;From interface:
  ;; N_Basic              number of Basic agents
  ;; N_Altruistic         number of Altruistic agents
  ;; N_Profiteer          number of Profiteer agents
  ;; prob_mutation        probability of mutation when reproducing

  ;; init_energy          initial value of turtle energy
  ;; life_span            number of ticks until death if no repreduction
  ;; chemical_cost        energy consumed to produce the signalling chemical

  ;; diffusion_rate
  ;; evaporation_rate

  ;; N_food_source        number of food sources
  ;; food_amount          food amount by food patch
  ;; food_surface         surface size of food sources
  ;; food_energy          energy recovered when eating
  ;; food_expiration      number of ticks until food rots and disappears
  ;; eating_cooldown          keeps eating every X ticks

  ;; tick_energy          energy spent every tick

  ;;Internal variables:
  food_xcor            ;; x coordinate list of food sources
  food_ycor            ;; y coordinate list of food sources
]

patches-own [
  chemical             ;; amount of chemical on this patch
  chemical2            ;; amount of chemical2 on this patch
  food                 ;; amount of food on this patch (0, 1, or 2)
  food-source-number   ;; number (1, ..., N_food_source) to identify the food sources
  food_age             ;; number of ticks since it has been created
]


turtles-own [
  energy               ;; amount of energy left
  base_color           ;; base color for each breed
  age                  ;; number of ticks it has been alive
  last_meal            ;; tick number when last ate food
  pregnancy            ;; tick number when impregnated (default -1 for not pregnant)
  pop_ID               ;; whether from population 1 or 2
]

breed [basics basic]
breed [altruistics altruistic]
breed [profiteers profiteer]

breed [basics2 basic2]
breed [altruistics2 altruistic2]
breed [profiteers2 profiteer2]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  ;; set initial food source coordinates at random
  set food_xcor n-values N_food_source [random-float (2 * max-pxcor) - max-pxcor]
  set food_ycor n-values N_food_source [random-float (2 * max-pycor) - max-pycor]

  ;; create basic agents
  create-basics N_Basic
  [
    set pop_ID 1
    setup-breeds
  ]

  ;; create altruistic agents
  create-altruistics N_Altruistic
  [
    set pop_ID 1
    setup-breeds
  ]

  ;; create profiteer agents
  create-profiteers N_Profiteer
  [
    set pop_ID 1
    setup-breeds
  ]

  ;; create basic2 agents
  create-basics2 N_Basic2
  [
    set pop_ID 2
    setup-breeds
  ]

  ;; create altruistic2 agents
  create-altruistics2 N_Altruistic2
  [
    set pop_ID 2
    setup-breeds
  ]

  ;; create profiteer2 agents
  create-profiteers2 N_Profiteer2
  [
    set pop_ID 2
    setup-breeds
  ]

  ask patches
  [ setup-food
    recolor-patch ]

  reset-ticks
end

to setup-breeds ;; turtle procedure
  ifelse pop_ID = 1 [set shape "bug"] [set shape "butterfly"]

  if (breed = basics) or (breed = basics2) [ set base_color 9.9 ]
  if (breed = altruistics) or (breed = altruistics2) [ set base_color 75 ]
  if (breed = profiteers) or (breed = profiteers2) [ set base_color 25 ]

  set size 2             ;; easier to see
  set color base_color

  set energy init_energy
  set age random (0.3 * life_span)

  set last_meal 0
  set pregnancy -1 ;; not pregnant

  set xcor random-xcor
  set ycor random-ycor
end

to setup-food  ;; patch procedure
  set food-source-number 0
  set food_age 0
  set food 0

  (foreach food_xcor food_ycor (range 1 (N_food_source + 1))
  [
      [x y fs_num] ->

      if (distancexy (round x) (round y) ) < food_surface ;; inward circle where everything inside is food
      [
        ;; set "food" at sources to either 1 or 2, randomly
        set food one-of (range 1 (food_amount + 1)) ;;amount of food in each patch, nb of times an ant can get food
        ;; identify food source
        set food-source-number fs_num
        set food_age 0
      ]
  ])
end

to recolor-patch  ;; patch procedure
  ;; give color to food sources
  ifelse food > 0 [ set pcolor cyan ]
  ;; scale color to show chemical concentration
  [
    ifelse chemical >= chemical2
    [set pcolor scale-color green chemical 0.1 5]
    [set pcolor scale-color violet chemical2 0.1 5]
  ]
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  ask turtles
  [
    look-for-food            ;; search for food in the environment
    if (color = base_color) and (food <= 0)
    [
      wiggle
      fd 1
    ]

    if ( energy >= (2 * init_energy) ) and ( pregnancy < 0 ) [ set pregnancy ticks ]
    if ( pregnancy >= 0 ) and ( (ticks - pregnancy) >= gestation_period ) [reproduce]

    if (age > life_span) or (energy <= 0) [die] ;; death, old age or starvation
    set age (age + 1)
    set energy (energy - tick_energy)

  ]

  diffuse chemical (diffusion-rate / 100)
  diffuse chemical2 (diffusion-rate / 100)
  ask patches
  [
    set chemical chemical * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical
    set chemical2 chemical2 * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical2
    recolor-patch
    if food > 0
    [
      ifelse food_age > food_expiration
      [
        set food 0
        set food_age 0
        set food-source-number 0
      ]
      [ set food_age (food_age + 1) ]
    ]
  ]

  foreach (range 1 (N_food_source + 1)) ;;if food runs out, it appears elsewhere
  [
    [fs_num] ->
    if ( (sum [food] of patches with [food-source-number = fs_num]) = 0 )
    [
      let x round (random-float (2 * max-pxcor) - max-pxcor)
      let y round (random-float (2 * max-pycor) - max-pycor)

      ask patches
      [
        if (distancexy x y) < food_surface
        [
          ;; set "food" at sources to either 1 or 2, randomly
          set food one-of (range 1 (food_amount + 1))
          ;; identify food source
          set food-source-number fs_num
          set food_age 0
        ]
      ]
    ]
  ]
  tick
end

to reproduce ;; turtle procedure

  if energy > init_energy
  [
    set energy (energy - init_energy)

    ifelse prob_mutation > random-float 1
    [
      ifelse 0.5 > random-float 1
      [
        if breed = basics [ hatch-profiteers 1 [ setup-breeds ] ]
        if breed = altruistics [ hatch-basics 1 [ setup-breeds ] ]
        if breed = profiteers [ hatch-altruistics 1 [ setup-breeds ] ]

        if breed = basics2 [ hatch-profiteers2 1 [ setup-breeds ] ]
        if breed = altruistics2 [ hatch-basics2 1 [ setup-breeds ]]
        if breed = profiteers2 [ hatch-altruistics2 1 [ setup-breeds ] ]
      ]
      [
        if breed = basics [ hatch-altruistics 1 [ setup-breeds ] ]
        if breed = altruistics [ hatch-profiteers 1 [ setup-breeds ] ]
        if breed = profiteers [ hatch-basics 1 [ setup-breeds ] ]

        if breed = basics2 [ hatch-altruistics2 1 [ setup-breeds ] ]
        if breed = altruistics2 [ hatch-profiteers2 1 [ setup-breeds ]  ]
        if breed = profiteers2 [ hatch-basics2 1 [ setup-breeds ] ]
      ]
    ]
    [
      hatch 1 [ setup-breeds ]
    ]
  ]
  set pregnancy -1 ;; not pregnant
end

to look-for-food  ;; turtle procedure
  ifelse food > 0
  [
    if breed = altruistics
    [
      set chemical chemical + 60  ;; drop some chemical
      set energy (energy - chemical_cost) ;; energy spent producing the signalling chemical
    ]
    if breed = altruistics2
    [
      set chemical2 chemical2 + 60  ;; drop some chemical2
      set energy (energy - chemical_cost) ;; energy spent producing the signalling chemical2
    ]

    if (ticks - last_meal) >= eating_cooldown
    [
      set color brown          ;; eating
      set food food - 1        ;; and reduce the food source
      set energy (energy + food_energy)
      set last_meal ticks
      if food = 0
      [
        set food-source-number 0
        set food_age 0
      ]
      stop
    ]
  ]
  [
    ;; go in the direction where the chemical smell is strongest
    if ((breed = profiteers) or (breed = altruistics)) and (chemical >= 0.05) and (chemical < 2)
    [ uphill-chemical ]
    ;; go in the direction where the chemical2 smell is strongest
    if ((breed = profiteers2) or (breed = altruistics2)) and (chemical2 >= 0.05) and (chemical2 < 2)
    [ uphill-chemical2 ]
  ]
  set color base_color
end

;; sniff left and right, and go where the strongest smell is
to uphill-chemical  ;; turtle procedure
  let scent-ahead chemical-scent-at-angle   0
  let scent-right chemical-scent-at-angle  45
  let scent-left  chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

;; sniff left and right, and go where the strongest smell is
to uphill-chemical2  ;; turtle procedure
  let scent-ahead chemical2-scent-at-angle   0
  let scent-right chemical2-scent-at-angle  45
  let scent-left  chemical2-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

to wiggle  ;; turtle procedure
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical] of p
end

to-report chemical2-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical2] of p
end
@#$#@#$#@
GRAPHICS-WINDOW
204
10
919
726
-1
-1
7.0
1
10
1
1
1
0
0
0
1
-50
50
-50
50
1
1
1
ticks
30.0

BUTTON
19
301
99
334
NIL
setup
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
2
692
213
725
diffusion-rate
diffusion-rate
0
100
50.0
10
1
per tick
HORIZONTAL

SLIDER
2
654
201
687
evaporation-rate
evaporation-rate
0
50
25.0
5
1
per tick
HORIZONTAL

BUTTON
101
301
176
334
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
0

SLIDER
1
82
197
115
N_Altruistic
N_Altruistic
0
200
100.0
10
1
individuals
HORIZONTAL

SLIDER
0
46
197
79
N_Basic
N_Basic
0
200
100.0
10
1
individuals
HORIZONTAL

SLIDER
1
119
198
152
N_Profiteer
N_Profiteer
0
200
100.0
10
1
individuals
HORIZONTAL

SLIDER
27
370
180
403
N_food_source
N_food_source
0
10
8.0
1
1
NIL
HORIZONTAL

SLIDER
26
405
180
438
food_amount
food_amount
1
10
4.0
1
1
NIL
HORIZONTAL

SLIDER
26
439
180
472
food_surface
food_surface
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
2
616
201
649
chemical_cost
chemical_cost
0.0
2
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
290
733
545
766
init_energy
init_energy
50
200
100.0
1
1
per individual
HORIZONTAL

SLIDER
21
259
178
292
prob_mutation
prob_mutation
0.0
1.0
0.0
0.05
1
NIL
HORIZONTAL

SLIDER
96
733
273
766
life_span
life_span
400
2000
1000.0
20
1
ticks
HORIZONTAL

MONITOR
1486
10
1578
71
#basics
count turtles with [breed = basics]
1
1
15

MONITOR
1486
94
1579
155
#altruistics
count turtles with [breed = altruistics]
1
1
15

MONITOR
1486
177
1580
238
#profiteers
count turtles with [breed = profiteers]
1
1
15

PLOT
1016
10
1485
258
Population
Time
#Individuals
0.0
50.0
0.0
150.0
true
true
"" ""
PENS
"basics" 1.0 0 -16777216 true "" "plot count turtles with [breed = basics]"
"altruistics" 1.0 0 -14835848 true "" "plot count turtles with [breed = altruistics]"
"profiteers" 1.0 0 -955883 true "" "plot count turtles with [breed = profiteers]"

PLOT
1016
259
1580
468
Evolution of energy for population 1
Energy
#Individuals
0.0
200.0
0.0
20.0
false
true
"" ""
PENS
"basics" 1.0 1 -16777216 true "" "histogram [energy] of turtles with [breed = basics]"
"altruistics" 1.0 1 -14835848 true "" "histogram [energy] of turtles with [breed = altruistics]"
"profiteers" 1.0 1 -955883 true "" "histogram [energy] of turtles with [breed = profiteers]"

SLIDER
27
473
180
506
food_energy
food_energy
1
50
20.0
1
1
NIL
HORIZONTAL

SLIDER
563
733
721
766
tick_energy
tick_energy
0
1
0.8
0.1
1
NIL
HORIZONTAL

PLOT
1016
469
1580
677
Histogram of age (pop 1)
Age
#Individuals
0.0
1000.0
0.0
20.0
false
true
"" ""
PENS
"basics" 5.0 1 -16777216 true "" "histogram [age] of turtles with [breed = basics]"
"altruistics" 5.0 1 -14835848 true "" "histogram [age] of turtles with [breed = altruistics]"
"profiteers" 5.0 1 -955883 true "" "histogram [age] of turtles with [breed = profiteers]"

SLIDER
26
541
181
574
eating_cooldown
eating_cooldown
0
20
1.0
1
1
NIL
HORIZONTAL

SLIDER
27
507
181
540
food_expiration
food_expiration
100
1000
500.0
100
1
ticks
HORIZONTAL

SLIDER
0
155
201
188
N_Basic2
N_Basic2
0
200
0.0
10
1
individuals
HORIZONTAL

SLIDER
0
189
201
222
N_Altruistic2
N_Altruistic2
0
200
0.0
10
1
individuals
HORIZONTAL

SLIDER
1
223
201
256
N_Profiteer2
N_Profiteer2
0
200
0.0
10
1
individuals
HORIZONTAL

PLOT
1582
469
2147
677
Histogram of age (pop 2)
Age
#Individuals
0.0
1000.0
0.0
20.0
false
true
"" ""
PENS
"basics2" 5.0 1 -16777216 true "" "histogram [age] of turtles with [breed = basics2]"
"altruistics2" 5.0 1 -14835848 true "" "histogram [age] of turtles with [breed = altruistics2]"
"profiteers2" 5.0 1 -955883 true "" "histogram [age] of turtles with [breed = profiteers2]"

PLOT
1582
259
2146
468
Histogram of energy 2
Energy
#Individuals
0.0
200.0
0.0
20.0
false
true
"" ""
PENS
"basics2" 1.0 1 -16777216 true "" "histogram [energy] of turtles with [breed = basics2]"
"altruistics2" 1.0 1 -14835848 true "" "histogram [energy] of turtles with [breed = altruistics2]"
"profiteers2" 1.0 1 -955883 true "" "histogram [energy] of turtles with [breed = profiteers2]"

PLOT
1581
10
2050
257
Population 2
Time
#Individuals
0.0
50.0
0.0
150.0
true
true
"" ""
PENS
"basics2" 1.0 0 -16777216 true "" "plot count turtles with [breed = basics2]"
"altruistics2" 1.0 0 -14835848 true "" "plot count turtles with [breed = altruistics2]"
"profiteers2" 1.0 0 -955883 true "" "plot count turtles with [breed = profiteers2]"

MONITOR
2051
11
2143
72
#basics2
count turtles with [breed = basics2]
1
1
15

MONITOR
2051
97
2154
158
#altruistics2
count turtles with [breed = altruistics2]
1
1
15

MONITOR
2051
179
2155
240
#profiteers2
count turtles with [breed = profiteers2]
1
1
15

TEXTBOX
69
345
219
369
FOOD
20
0.0
1

TEXTBOX
27
17
165
41
POPULATION
20
0.0
1

TEXTBOX
15
590
193
609
COMMUNICATION
20
0.0
1

TEXTBOX
24
735
78
759
LIFE
20
0.0
1

SLIDER
740
733
918
766
gestation_period
gestation_period
0
500
100.0
10
1
ticks
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?
In this project, groups of agents look for food. While all agents belong to the same specie, they adopt different behaviours depending on their type.

Though each agent follows a set of simple rules depending on its type, each group as a whole acts in a sophisticated way, clearly illustrating the phenomenon of emergence.
In this model we can see the evolution of populations of altruistic versus greedy agents.

## HOW IT WORKS
Agents explore the map searching for food and stop to consume it when they find it. Depending on their type, the exact behaviour they adopt when finding the source of food varies. Agents are of three types: altruistic, greedy and standard.

When an altruistic agent finds a source of food, it starts eating it and signals other agents the location of the food source.

When a greedy agent finds a food source, it starts eating it but does not signal it to other agents, moreover it is capable of picking up on the altruistic agent's signals.

When a standard agent finds a food source, it stops to eat it, it does not signal its presence nor can it pick up on other agents' signals.

All agents will eat until the food source disappears and they are compelled to resume their search. When a food source disappears, another one appears in some random location. Agents exploit food sources as they go.

Altruistic population fares better than standard one. Greedy population fares as well as standard one when there are no altruist agents since they adopt the same behaviour as the standard agents, yet their population does better as soon as altruistic agents are introduced.

Once a food source disappears, the chemical signal keeps the agents "trapped" on the spot of the previous food source until it disappears, making it dangerous to use long-persisting chemical in a fast-evolving environment.

After reaching double the initial amount of energy, an agent becomes pregnant. After the gestation period, it gives birth to another agent of the same type, unless a mutation occurs. When the new agent is born, a share equivalent to the initial energy is subtracted from the parent and given to the child. If by the time of birth the parent doesn't have more than the initial amount of energy, the parent loses the child and becomes not pregnant again.

## HOW TO USE IT
Click the SETUP button to parameterise the simulation as chosen.

Click the GO button to start the simulation.

Food sources appear at random on the map, in a circle shape.

Agents from population 1 have an ant shape, while agents from population 2 have a butterfly shape.

The diffusion of the information signal is shown in a green-to-white gradient for population 1 and in a purple-to-white gradient for population 2.

Altruistic agents are green, greedy agents are red and standard agents are white.

### N_BASIC
Defines the initial population of standard-behaving agents.

### N_ALTRUISTIC
Defines the initial population of altruistic agents.

### N_PROFITEERS
Defines the initial population of greedy agents.

### N_BASIC2
Defines the initial population of standard-behaving agents of the second population.

### N_ALTRUISTIC2
Defines the initial population of altruistic agents of the second population.

### N_PROFITEERS2
Defines the initial population of greedy agents of the second population.

### PROB_MUTATION
Determines the likelihood of a child to be from another type than its parent.

### N_FOOD_SOURCE
Defines the number of food sources initially available. 

### FOOD_AMOUNT
The amount of food contained in a patch within a food source is a random integer between 1 and this number.

### FOOD_SURFACE
The radius of a food source.

### FOOD_ENERGY
The energy agents gain by consuming one unit of food.

### FOOD_EXPIRATION
Number of ticks after which the food will expire and disappear to reappear somewhere else.

### EATING_COOLDOWN
Number of ticks for which the agents must wait before consuming a another unit of food after they have consumed one.

### INIT_ENERGY
The energy agents are born with.

### CHEMICAL_COST
Cost (in energy) of chemical emission for the altruistic agents.

### EVAPORATION_RATE
Rate at which the emited chemical fades away. If set to 0, all emitted chemical remains until it finally covers all the screen.

### DIFFUSION_RATE
Rate at which the chemical signal is diffused accross the environment.


### TICK_ENERGY
The energy that is wasted at each timestep, no matter what the agent is doing. 

### LIFE_SPAN
The maximum number of ticks an agent survives, if the agent's age reaches this number of ticks without having died by starvation, it dies of old age.



## THINGS TO NOTICE

Observe how changing the evaporation rate can render the use of chemical either useless (too high a rate) or dangerous (too low a rate) since it ends up trapping the agents where the food had once been but is no longer.

Notice how the eating rate influences the balance between populations.

Pay attention to the fragile conditions in which altruists survive, observe the food distribution. Now Try and tweak the food distributions s.t. standard agents overlive others. What can you conclude?


## EXTENDING THE MODEL

In this project, the only sort of competition taken into account is the depletion of food sources. However in a real ecosystem, social dynamics come into play, a food source with a majority of agents from a certain type might be less accessible to agents of another type depending on how agressive the agents might be. Do you think implementing a behaviour whereby an agent can also use a certain amount of energy to prevent another type of agent from coming might impact their respective survival rates? Try to add this action to the set of possibilities an ant has when feeding.

The ants only respond to chemical levels between 0.05 and 2.  The lower limit is used so the ants aren't infinitely sensitive.  Try removing the upper limit.  What happens?  Why?

In the `uphill-chemical` procedure, the ant "follows the gradient" of the chemical. That is, it "sniffs" in three directions, then turns in the direction where the chemical is strongest. You might want to try variants of the `uphill-chemical` procedure, changing the number and placement of "ant sniffs."

## NETLOGO FEATURES

The built-in `diffuse` primitive lets us diffuse the chemical easily without complicated code.

The primitive `patch-right-and-ahead` is used to make the agents smell in different directions without actually turning.

## PREVIOUS WORK

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

### For the original model:

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

### For the adapted model:

* Luz-Brochado R.C. , Vigneron A. (2021) "Altruism versus greed" (https://github.com/Narmondil/altruism_versus_greed)


### NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 2021 Luz-Brochado R., Vigneron A.

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

This model was developed at Institut Polytechnique de Paris - Télécom Paris using NetLogo as part of a student project on Multi-Agent Modeling for the Data Science and Artificial Intelligence Masters program. The project was conducted under the supervision of Ada Diaconescu Ph.D. .
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
NetLogo 6.1.1
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
