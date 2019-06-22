extensions [array]

globals [
  aircraft_rows
  passenger_no
  ticket_queue
  next_boarding_passenger
  total_elapsed_time
  seat_interferences
  aisle_interferences
  boarded_agents
  group_size
  available_aisle_and_filling
  available_aisle_not_filling
  not_available_aisle_but_filling
  not_available_aisle_and_not_filling
  entrances_rate
  overhead_bins
]

turtles-own [
  is_seated?
  has_boarded?
  number_of_seat_interferences
  total_time_of_seat_interferences
  number_of_aisle_interferences
  total_time_of_aisle_interferences
  total_boarding_time
  stowing_time
  has_luggage?
  patch_ticks_speed ;patch/tick
  move_aisle?
  analysed
  on_aisle_interference?
  transparent?
  simpathy
  overhead_bin_for_luggage
  entrance_time


  have_to_wait?

  is_stowing?
  target_seat_row  ; From 0 to the aircraft's seat_rows.
  target_seat_col  ; [-3, -2, -1, 1, 2, 3], negative meaning it's seated to the left of the aisle and positive to the right.
  assigned_group
]

patches-own [
  is_assigned?  ; Is this seat assigned to a passenger?
  is_occupied?  ; Is the passenger assigned to this seat seated?
  row_index
]

to setup
  __clear-all-and-reset-ticks
  setup_aircraft_model
  setup_availability_and_filling
  setup_entrance_rate
  setup_passengers
  setup_boarding_method
  set boarded_agents []
  set next_boarding_passenger first ticket_queue
end

to setup_passengers
  create-turtles passenger_no [
    ; Passenger appearance.
    set shape "person"
    set color one-of [ white brown blue yellow ]
    set target_seat_row 5
    set target_seat_col -3
    set is_stowing? false
    set move_aisle? false
    set has_luggage? false
    set analysed false
    set on_aisle_interference? false
    set total_time_of_aisle_interferences 0
    set total_time_of_seat_interferences 0
    set total_boarding_time 0
    set patch_ticks_speed 1
    set transparent? false
    set simpathy 1
    set entrance_time 0
    set overhead_bins array:from-list n-values 20 [0]


    set heading 90

    ; Position passengers at the airplane's entrance.
    set xcor (- aircraft_rows / 2)
    set ycor 0

    set is_seated? false
    set has_boarded? false
  ]

  let row_lst (range 1 (aircraft_rows + 1))
  let col_lst (filter [i -> i != 0] (range -3 4))

  ;; Create a list with every possible seat permutation. E.g. [[row col]...[row col]].
  let permutations []
  foreach row_lst [row -> foreach col_lst [col -> set permutations insert-item 0 permutations (list row col)]]

  ;; Assign each passenger a unique seat on the airplane.
  foreach (range 0 passenger_no) [
    pass_who -> (
      ask turtle pass_who [
        set target_seat_row (item 0 (item pass_who permutations))
        set target_seat_col (item 1 (item pass_who permutations))
        if(human_factor) [setup_probability pass_who "entrance_time"]
      ])
  ]


  let passengers_with_luggage round ( 180 * luggage_percentage / 100 )
  ask n-of passengers_with_luggage turtles [
    set shape "person farmer"
    set stowing_time 1
    set has_luggage? true
    if(human_factor) [set patch_ticks_speed luggage_speed]
  ]

end

to setup_probability [agent variable]
    let rate random-float 1
    let i 0
    ifelse (variable = "entrance_time") [
       foreach entrances_rate [x -> ifelse(rate < x) [ask turtle agent [set entrance_time i] stop] [set i (i + 1)]]
    ]
    [
     if(variable = "available_aisle_not_filling") [
      foreach available_aisle_not_filling [x -> ifelse(rate < x) [ask turtle agent [set stowing_time i] stop] [set i (i + 1)]]
     ]
     if(variable = "available_aisle_and_filling") [
      foreach available_aisle_and_filling [x -> ifelse(rate < x) [ask turtle agent [set stowing_time i] stop] [set i (i + 1)]]
     ]

     if(variable = "not_available_aisle_and_not_filling") [
      foreach not_available_aisle_and_not_filling [x -> ifelse(rate < x) [ask turtle agent [set stowing_time i] stop] [set i (i + 1)]]
     ]

     if(variable = "not_available_aisle_but_filling") [
      foreach not_available_aisle_but_filling [x -> ifelse(rate < x) [ask turtle agent [set stowing_time i] stop] [set i (i + 1)]]
     ]

    ]
end


to setup_aircraft_model
  if aircraft_model = "A320" [set aircraft_rows 30]
  ask patch (- aircraft_rows / 2) 0 [set pcolor blue]  ;Color the spawn point.

  foreach (range 1 (aircraft_rows + 1)) [
    row -> foreach (filter [i -> i != 0] (range -3 4)) [
      col -> ask patch (row - (aircraft_rows / 2)) col [
        set pcolor green
        set plabel (word (col))
      ]
    ]
  ]

  set passenger_no aircraft_rows * 6
end


to setup_boarding_method
  if boarding_method = "random" [set ticket_queue setup_random_method]
  if boarding_method = "back-to-front" [set ticket_queue setup_back_to_front_method]
  if boarding_method = "block-back-to-front" [set ticket_queue setup_block_back_to_front_method]
  if boarding_method = "front-to-back" [set ticket_queue setup_front_to_back_method]
  if boarding_method = "block-front-to-back" [set ticket_queue setup_block_front_to_back_method]
  if boarding_method = "wilma" [set ticket_queue setup_wilma_method]
  if boarding_method = "weird-wilma" [set ticket_queue setup_weird_wilma_method]
  if boarding_method = "ordered" [set ticket_queue setup_ordered_method]
  if boarding_method = "steffen" [set ticket_queue setup_steffen_method]
  if boarding_method = "kautzka" [set ticket_queue setup_kautzka_method]
end

to setup_availability_and_filling
  set available_aisle_and_filling [
    0.25703
    0.30824
    0.50978
    0.63650
    0.73223
    0.76510
    0.85617
    0.90183
    0.92738
    0.93407
    0.94867
    0.95368
    0.95809
    1
  ]
  set available_aisle_not_filling [
    0.20000
    0.21336
    0.28309
    0.39237
    0.45540
    0.62440
    0.68456
    0.72131
    0.78084
    0.84515
    0.86672
    0.87955
    0.88393
    1
  ]
  set not_available_aisle_but_filling [
    0.43574
    0.45263
    0.64688
    0.77020
    0.83552
    0.92163
    0.97276
    0.98387
    0.98939
    0.99360
    0.99432
    0.99546
    0.99659
    1
  ]
  set not_available_aisle_and_not_filling [
    0.38755
    0.40644
    0.44793
    0.55773
    0.57379
    0.67191
    0.73781
    0.82276
    0.85420
    0.87896
    0.89091
    0.89794
    0.90373
    1
  ]
end

to setup_entrance_rate
  set entrances_rate [0.30000 0.430331 0.702985 0.842925  0.883241 0.928445 0.977536 1]
end


;; Setup random boarding method.
to-report setup_random_method
  report shuffle (range 0 passenger_no)
end

to-report setup_back_to_front_method
  let queue []

  foreach reverse (range 1 (aircraft_rows + 1)) [
    index -> ask turtles with [index = target_seat_row] [set queue lput who queue]
  ]

  report queue
end

;; Setup back-to-front boarding method.
to-report setup_block_back_to_front_method

  ;; Assign groups to passengers.
  set group_size 5
  let group_rows (aircraft_rows / group_size)

  let groups []
  let queue []

  foreach (range group_size) [
    index -> set groups (insert-item index groups (range ((index * group_rows) + 1) (((index + 1) * group_rows) + 1)))
  ]

  foreach groups [
    grp -> ask turtles with [member? target_seat_row grp] [
      set assigned_group ((position grp groups) + 1)
      set queue (insert-item 0 queue who)
    ]
  ]

  report queue
end

;; Setup front-to-back boarding method.
to-report setup_front_to_back_method
  report reverse setup_back_to_front_method
end

;; Setup front-to-back boarding method.
to-report setup_block_front_to_back_method
  report reverse setup_block_back_to_front_method
end

;; Setup Wilma boarding method.
to-report setup_wilma_method
  let col_lst reverse (range 1 4)
  let queue []

  foreach col_lst [
    grp -> ask turtles with [target_seat_col = grp or target_seat_col = (- grp)] [
      if grp = 3 [set assigned_group 1]
      if grp = 2 [set assigned_group 2]
      if grp = 1 [set assigned_group 3]
    ]
  ]

  foreach reverse (range 1 4) [
    grp -> ask turtles with [assigned_group = grp] [set queue fput who queue]
  ]

  report queue
end

to-report setup_weird_wilma_method
  let col_lst reverse (range 1 4)
  let queue []

  foreach col_lst [
    grp -> ask turtles with [target_seat_col = grp or target_seat_col = (- grp)] [
      if grp = 3 [set assigned_group 2]
      if grp = 2 [set assigned_group 1]
      if grp = 1 [set assigned_group 3]
    ]
  ]

  foreach reverse (range 1 4) [
    grp -> ask turtles with [assigned_group = grp] [set queue fput who queue]
  ]

  report queue
end


;; Set ordered boarding method.
to-report setup_ordered_method
  report (range 0 passenger_no)
end

;; Set steffen method
to-report setup_steffen_method
  let i 0
  let queue []
  while [i < 29][
   set queue  insert-item 0 queue (i * 6)
    set i i + 2
  ]

  set i 0
  while [i < 29] [
    set queue insert-item 0 queue ((i * 6) + 5)
    set i i + 2
  ]

  set i 1
  while [i < 30] [
   set queue insert-item 0 queue ((i * 6))
   set i i + 2
  ]

   set i 1
  while [i < 30] [
   set queue insert-item 0 queue ((i * 6) + 5)
   set i i + 2
  ]

  set i 0
   while [i < 29][
   set queue  insert-item 0 queue ((i * 6) + 1)
    set i i + 2
  ]

  set i 0
  while [i < 29] [
    set queue insert-item 0 queue ((i * 6) + 4)
    set i i + 2
  ]

  set i 1
  while [i < 30] [
   set queue insert-item 0 queue ((i * 6) + 1)
   set i i + 2
  ]

   set i 1
  while [i < 30] [
   set queue insert-item 0 queue ((i * 6) + 4)
   set i i + 2
  ]

  set i 0
   while [i < 29][
   set queue  insert-item 0 queue ((i * 6) + 2)
    set i i + 2
  ]

  set i 0
  while [i < 29] [
    set queue insert-item 0 queue ((i * 6) + 3)
    set i i + 2
  ]

    set i 1
  while [i < 30] [
   set queue insert-item 0 queue ((i * 6) + 2)
   set i i + 2
  ]

   set i 1
  while [i < 30] [
   set queue insert-item 0 queue ((i * 6) + 3)
   set i i + 2
  ]


  report reverse queue

end

to-report setup_kautzka_method

  ifelse family_size = 1[

    report setup_steffen_method
  ][

    ifelse family_size = 2 [

      let i 0
      let queue []
      while [i < 29][
        set queue  insert-item 0 queue (i * 6)
        set queue  insert-item 0 queue ((i * 6) + 1)
        set i i + 2
      ]

      set i 0
      while [i < 29] [
        set queue insert-item 0 queue ((i * 6) + 5)
        set queue insert-item 0 queue ((i * 6) + 4)
        set i i + 2
      ]

      set i 1
      while [i < 30] [
        set queue insert-item 0 queue ((i * 6))
        set queue insert-item 0 queue ((i * 6) + 1)
        set i i + 2
      ]

      set i 1
      while [i < 30] [
        set queue insert-item 0 queue ((i * 6) + 5)
        set queue insert-item 0 queue ((i * 6) + 4)
        set i i + 2
      ]

      set i 0
      while [i < 29][
        set queue  insert-item 0 queue ((i * 6) + 2)
        set i i + 2
      ]

      set i 0
      while [i < 29] [
        set queue insert-item 0 queue ((i * 6) + 3)
        set i i + 2
      ]

      set i 1
      while [i < 30] [
        set queue insert-item 0 queue ((i * 6) + 2)
        set i i + 2
      ]

      set i 1
      while [i < 30] [
        set queue insert-item 0 queue ((i * 6) + 3)
        set i i + 2
      ]

      report reverse queue

    ][

      let i 0
      let queue []
      while [i < 29][
        set queue  insert-item 0 queue (i * 6)
        set queue  insert-item 0 queue ((i * 6) + 1)
        set queue  insert-item 0 queue ((i * 6) + 2)
        set i i + 2
      ]

      set i 0
      while [i < 29] [
        set queue insert-item 0 queue ((i * 6) + 5)
        set queue insert-item 0 queue ((i * 6) + 4)
        set queue insert-item 0 queue ((i * 6) + 3)
        set i i + 2
      ]

      set i 1
      while [i < 30] [
        set queue insert-item 0 queue ((i * 6))
        set queue insert-item 0 queue ((i * 6) + 1)
        set queue insert-item 0 queue ((i * 6) + 2)
        set i i + 2
      ]

      set i 1
      while [i < 30] [
        set queue insert-item 0 queue ((i * 6) + 5)
        set queue insert-item 0 queue ((i * 6) + 4)
        set queue insert-item 0 queue ((i * 6) + 3)
        set i i + 2
      ]
      report reverse queue
    ]
  ]


end

;; Board the next passenger and remove it from the queue (FIFO).
to board_next_passenger
  ask turtle first ticket_queue [ifelse(entrance_time > 0) [set entrance_time entrance_time - 1]
    [
     set has_boarded? true
     set boarded_agents lput first ticket_queue boarded_agents
     set ticket_queue but-first ticket_queue
     if length ticket_queue > 0 [set next_boarding_passenger first ticket_queue]
    ]
  ]
end

to board_not_seated_agent [agent]
    ask turtle agent [
     if(is_seated?) [stop]

     set total_boarding_time total_boarding_time + 1
     set analysed true
     let aisle_row (xcor + (aircraft_rows / 2))
     if target_seat_row = round aisle_row and not is_seated?
     [
      ;; Decide which direction rotate when it has found its row.
      ifelse target_seat_col > 0 [set heading 0] [set heading 180]
      set xcor ((round aisle_row) - (aircraft_rows / 2))
      set patch_ticks_speed 1

      ifelse (is_stowing? = false and stowing_time > 0 and human_factor) [
        ; get overhead bin sector
        let overhead_full 0
        let other_side 0
        if(target_seat_col < 0)
        [
          set other_side 1
        ]

        ifelse(target_seat_col / 3 < 1) [
          ; just the first sector

          if((array:item overhead_bins (0 + 10 * other_side)) > 2)[
            set overhead_full 1
          ]
          set overhead_bin_for_luggage (0 + 10 * other_side)
        ]
        [
          ; just the last sector
          ifelse(target_seat_col / 3 = 10) [
            if((array:item overhead_bins (9 + 10 * other_side)) > 2)[
              set overhead_full 1
            ]
            set overhead_bin_for_luggage (9 + 10 * other_side)
          ]
          [
            let sector ((target_seat_col / 3) + 10 * other_side)
            ; for the last row of each sector
            let total 0
            ifelse (target_seat_col mod 3 = 0) [
              set total (array:item overhead_bins sector) + (array:item overhead_bins (sector + 1))
              ifelse(array:item overhead_bins sector < 4) [
                set overhead_bin_for_luggage sector
              ]
              [
                set overhead_bin_for_luggage (sector + 1)
              ]
            ]
            ; for rows in the middle
            [
              set total (array:item overhead_bins (floor sector)) + (array:item overhead_bins (ceiling sector))
              ifelse(array:item overhead_bins (floor sector) < 4) [
                set overhead_bin_for_luggage (floor sector)
              ]
              [
                set overhead_bin_for_luggage (ceiling sector)
              ]

            ]
            if(total > 4)[
              set overhead_full 1
            ]
          ]
        ]


        ;generate rando number for probability of stowing time
        let prob_stowing_time random-float 1

        ifelse(((patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1)) or (patch-at 0 -1 != nobody and not any? (turtles-on patch-at 0 -1)))) [

          let simp_num (random (100 * simpathy))
          ifelse(simp_num <= 93) [
            set transparent? true
            set simpathy simpathy + 1
          ]
          [
            set transparent? false
            set simpathy 1
          ]
          ifelse(overhead_full > 0) [
            setup_probability agent "available_aisle_not_filling"

          ]
          [
            setup_probability agent "available_aisle_and_filling"
          ]
          set is_stowing? true

       ]
       [
          let simp_num (random (100 * simpathy))
          ifelse(simp_num <= 53) [
            set transparent? true
            set simpathy simpathy + 1
          ]
          [
            set transparent? false
            set simpathy 1

          ]
          ifelse(overhead_full > 0) [
            setup_probability agent "not_available_aisle_and_not_filling"
          ]
          [
            setup_probability agent "not_available_aisle_but_filling"
          ]
          set is_stowing? true
       ]
      ]
      [
        if(is_stowing? = false and stowing_time > 0) [ set is_stowing? true ]
      ]


        let current_row target_seat_row
        let current_seat_col target_seat_col
        ifelse (stowing_time > 0) [
          set stowing_time stowing_time - 1
          stop
        ]
        [
          if(is_stowing? = true) [
            array:set overhead_bins overhead_bin_for_luggage ((array:item overhead_bins overhead_bin_for_luggage) + 1)
            set is_stowing? false
          ]
        ]
        if(human_factor)[
          ifelse(current_row > 1 and patch-at -1 0 != nobody and any? (turtles-on patch-at -1 0) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0  and abs(target_seat_col) > abs(current_seat_col)]) [
            set transparent? true
            stop
          ]
          [
            set transparent? false
          ]
          if(count turtles-here > 1)[

            let my_patch (turtles-on patch-here) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0 and is_stowing? = false]
            let most_distant max-one-of my_patch [ abs(target_seat_col) ]
            show most_distant
            if (most_distant = self) [
              if (most_distant != self) [
                  stop
              ]
            ]
         ]
        ]
      ; has a middle or window seat
      if abs(target_seat_col) > 1
      [
        let var false
        ; if has someone next to him ask to move backwards
        if patch-ahead 1 != nobody and any? (turtles-on patch-ahead 1) with [is_seated?] and ycor != target_seat_col
        [
          ask (turtles-on patch-ahead 1)[
            set analysed true
            set number_of_seat_interferences number_of_seat_interferences + 1
            fd (0 - patch_ticks_speed)
            set move_aisle? true
          ]
          set seat_interferences seat_interferences + 1
          set number_of_seat_interferences number_of_seat_interferences + 1
          set var true
        ]
        ;if has someone in the middle and his seat is a window seat
        if abs(target_seat_col) = 3
        [
          ; ask middle guy to move backward
          if patch-ahead 2 != nobody and any? (turtles-on patch-ahead 2) with [is_seated? = true] and ycor != target_seat_col
          [
            ask (turtles-on patch-ahead 2)[
              set analysed true
              fd (0 - patch_ticks_speed)
              set move_aisle? true
            ]
            set var true
          ]
        ]
        if var = true [stop]
      ]
    ]

    ifelse (patch-ahead 1 != nobody and ycor = 0 and any? (turtles-on patch-ahead 1) with [heading != 90 and transparent? = false] and heading = 90)[
	    set total_time_of_aisle_interferences total_time_of_aisle_interferences + 1
	    if on_aisle_interference? = false [
	      set number_of_aisle_interferences number_of_aisle_interferences + 1
	      set aisle_interferences aisle_interferences + 1
	      set on_aisle_interference? true
	    ]
	    stop
	   ]
	   [
	    if patch-ahead 1 != nobody and ycor = 0 and any? (turtles-on patch-ahead 1) with [heading = 90 and transparent? = false] and heading = 90
	    [
	      set total_time_of_aisle_interferences total_time_of_aisle_interferences + 1
	      if on_aisle_interference? = false [
	        set number_of_aisle_interferences number_of_aisle_interferences + 1
	        set on_aisle_interference? true
	      ]
	      stop
	     ]
	    ]

     ;; Seat the passenger if it's in the right column.
     ifelse ycor = target_seat_col
     [
       ask patch-here [set pcolor red]
       set is_seated? true
     ]
     [

       fd patch_ticks_speed
       set on_aisle_interference? false
       ;;ifelse any? (turtles-on patch-ahead 1) with [not is_seated?] [show "Aisle interference!"] [fd 1]
     ]
   ]
end

to move_seated_agent [agent]
  ask turtle agent [
    if(not is_seated? or ycor = target_seat_col) [stop]
    set analysed true

    let current_row target_seat_row
    let current_seat_col target_seat_col
    if(human_factor and ycor = 0)[
      ifelse(current_row > 1 and patch-at -1 0 != nobody and any? (turtles-on patch-at -1 0) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0  and abs(target_seat_col) > abs(current_seat_col)]) [
        set transparent? true
        stop
      ]
      [
        set transparent? false
      ]
     ]

    ifelse (ycor = 0 and move_aisle? = true) [
      beep
      set move_aisle? false
   ]
   [
      if move_aisle? = true [stop]
      set total_time_of_seat_interferences total_time_of_seat_interferences + 1
      ifelse (count turtles-here = 1) [
        if ((patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1) with [analysed = true]) or (patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1))) [
          fd patch_ticks_speed
          stop
        ]
      ]
      [
        let my_patch (turtles-on patch-here) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0 and is_stowing? = false]
        let most_distant max-one-of my_patch [ abs(target_seat_col) ]
        if (most_distant = self) [
          if (patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1)) [
            fd patch_ticks_speed
            stop
          ]
        ]
      ]

    ]
  ]
end

to-report get_all_satisfactions

  let total_satisfactions []
  foreach boarded_agents [agent -> ask turtle agent [
    let satisfaction 0
    set satisfaction (0.7 * total_boarding_time) + (0.2 * total_time_of_seat_interferences) + (0.1 * total_time_of_aisle_interferences)
    set total_satisfactions insert-item 0 total_satisfactions satisfaction

  ]]
  report  reverse total_satisfactions

end

to-report get_all_satisfactions_v2
  let total_satisfactions []
  foreach boarded_agents [agent -> ask turtle agent [
    let satisfaction 0
    set satisfaction (0.7 * total_boarding_time) + (0.2 * (total_time_of_seat_interferences / seat_interferences)) + (0.1 * (total_time_of_aisle_interferences / aisle_interferences))

    set total_satisfactions insert-item 0 total_satisfactions satisfaction

  ]]
  report  reverse total_satisfactions

end

to-report get_average_satisfaction
  let satisfaction 0
  report mean get_all_satisfactions

end

to-report get_average_satisfaction_v2
  let satisfaction 0
  report mean get_all_satisfactions_v2
end

to-report get_median_satisfaction
  let satisfaction 0
  report median get_all_satisfactions
end

to-report get_median_satisfaction_v2
  let satisfaction 0
  report median get_all_satisfactions_v2
end

to-report get_median_aisle_interferences_per_person
  let total_interferences []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_aisle_interferences
  ]]

  report median total_interferences
end

to-report get_median_seat_interferences_per_person
  let total_interferences []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_seat_interferences
  ]]

  report median total_interferences
end

to-report get_all_boarding_times
  let total_times []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_times insert-item 0 total_times total_boarding_time
  ]]

  report reverse total_times
end

to-report difference_time_with_luggage
  let agents []
  foreach boarded_agents [agent -> ask turtle agent [
    if has_luggage? = true[
      set agents insert-item 0 agents total_boarding_time
    ]

  ]]
  report abs( (max agents) - (min agents))
end

to-report difference_time_without_luggage
  let agents []
  foreach boarded_agents [agent -> ask turtle agent [
    if  has_luggage? = false[
      set agents insert-item 0 agents total_boarding_time
    ]

  ]]
  report abs( (max agents) - (min agents))

end

to-report difference_average
  let agents_luggage []
  foreach boarded_agents [agent -> ask turtle agent [
    if has_luggage? = true [
      set agents_luggage insert-item 0 agents_luggage total_boarding_time
    ]

  ]]

  let agents_no_luggage []
  foreach boarded_agents [agent -> ask turtle agent [
    if has_luggage? = false[
      set agents_no_luggage insert-item 0 agents_no_luggage total_boarding_time
    ]

  ]]

  report abs ((mean agents_luggage) - (mean agents_no_luggage))


end





to go
  tick

  every .1 [
    set total_elapsed_time total_elapsed_time + .1
  ]

  ;; Board the next passenger and remove it from the queue (FIFO).
  if length ticket_queue > 0 [board_next_passenger]

  foreach boarded_agents [agent -> ask turtle agent [set analysed false] board_not_seated_agent agent]

  foreach boarded_agents [agent -> move_seated_agent agent]


  if not any? patches with [pcolor = green] [
    let sum2 0
    foreach boarded_agents [agent -> ask turtle agent [set sum2 sum2 + number_of_seat_interferences]]
    show sum2
    show "Thank you for flying with Copacabana Airlines."
    stop
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
14
67
749
287
-1
-1
23.452
1
10
1
1
1
0
0
0
1
-15
15
-4
4
0
0
1
ticks
69.0

BUTTON
15
295
78
328
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

BUTTON
155
295
222
328
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

CHOOSER
751
66
889
111
aircraft_model
aircraft_model
"A320" "Custom"
0

MONITOR
934
114
1026
159
NIL
passenger_no
17
1
11

CHOOSER
752
116
907
161
boarding_method
boarding_method
"block-back-to-front" "back-to-front" "block-front-to-back" "front-to-back" "random" "wilma" "weird-wilma" "steffen" "kautzka" "ordered"
4

BUTTON
85
296
148
329
NIL
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

MONITOR
14
14
98
59
Now boarding
next_boarding_passenger
17
1
11

MONITOR
104
14
161
59
Elapsed
total_elapsed_time
3
1
11

MONITOR
933
62
1060
107
seat_interferences
seat_interferences
17
1
11

SLIDER
752
165
931
198
luggage_percentage
luggage_percentage
0
100
0.0
1
1
NIL
HORIZONTAL

MONITOR
935
170
1064
215
aisle_interferences
aisle_interferences
17
1
11

SLIDER
752
203
924
236
family_size
family_size
1
3
3.0
1
1
NIL
HORIZONTAL

PLOT
936
226
1136
376
Passenger seating rate
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [is_seated?]"

SLIDER
754
246
926
279
luggage_speed
luggage_speed
0.6
1
0.6
0.1
1
NIL
HORIZONTAL

SWITCH
757
288
900
321
human_factor
human_factor
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="steffen_0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;steffen&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="kautzka_0_2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;kautzka&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="kautzka_0_3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;kautzka&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="block-back-to-front-0" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;block-back-to-front&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="back-to-front-0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;back-to-front&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random_0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="wilma_0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;wilma&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="steffen_50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;steffen&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="kautzka_50_2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;kautzka&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="kautzka_50_3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;kautzka&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="block-back-to-front-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;block-back-to-front&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="back-to-front-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;back-to-front&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="random_50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="wilma_50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;wilma&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Example" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="block-front-to-back-0" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;block-front-to-back&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="block-front-to-back-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;block-front-to-back&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="front-to-back-0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;front-to-back&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="front-to-back-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
    <enumeratedValueSet variable="luggage_percentage">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="boarding_method">
      <value value="&quot;front-to-back&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aircraft_model">
      <value value="&quot;A320&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human_factor">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
