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
  stop_moving


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
    set stop_moving false


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
        if(human_factor) [
          setup_probability pass_who "entrance_time"
          if(distributed_passenger_speed) [
            let speed random-normal 1 (0.25 / 1.3)
            set patch_ticks_speed speed
          ]
        ]

      ])
  ]


  let passengers_with_luggage round ( 180 * luggage_percentage / 100 )
  ask n-of passengers_with_luggage turtles [
    set shape "person farmer"
    set stowing_time 1
    set has_luggage? true
    if(not distributed_passenger_speed) [set patch_ticks_speed luggage_speed]
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
    0.2605952019590450
    0.2627842335675820
    0.2648439007171920
    0.2649015775406920
    0.2720431336686480
    0.2799153033920980
    0.2827598689224200
    0.2921681211744570
    0.3005880180019980
    0.3018118427069040
    0.3063673160502370
    0.3125285779606770
    0.3187800068587100
    0.3244360615759790
    0.3327988180126400
    0.3399157902758720
    0.3506325255296450
    0.3613492607834170
    0.3666163030637410
    0.3768289894833100
    0.3863549763755520
    0.3911179698216730
    0.3973363223763310
    0.3997910775862280
    0.4077884468830970
    0.4122206768954590
    0.4185051821368690
    0.4256496723060510
    0.4333356615116290
    0.4399386526444140
    0.4494646395366560
    0.4625628715134890
    0.4744703551287910
    0.4804199968201480
    0.4887593354671540
    0.4982853223593960
    0.5090020576131680
    0.5137650510592900
    0.5229876273102780
    0.5292447797591830
    0.5351985215668340
    0.5423430117360160
    0.5494875019051970
    0.5554412437128480
    0.5631859670845760
    0.5651987650087210
    0.5697302240512120
    0.5756218151776100
    0.5804469593049840
    0.5887821978356960
    0.5965180847711770
    0.5983081847279380
    0.6078341716201800
    0.6146201307825190
    0.6245046486816030
    0.6316491388507850
    0.6347432978684170
    0.6411751257430270
    0.6460616442720950
    0.6536783461287600
    0.6614178478890410
    0.6672949586625260
    0.6697530864197530
    0.6757068282274040
    0.6825254123995070
    0.6908888698369150
    0.6947588020118880
    0.6990291098973990
    0.7066662856271910
    0.7122702394075550
    0.7173830208809630
    0.7267808539566820
    0.7352442463039170
    0.7411979881115680
    0.7461940194606690
    0.7529070136666160
    0.7535680678986850
    0.7574081181502890
    0.7585720525575610
    0.7630826367304950
    0.7709666971498250
    0.7793019356805360
    0.7854999322034050
    0.7924001676573690
    0.7983539094650200
    0.8039968588455500
    0.8090706447187930
    0.8130819383420630
    0.8197873799725650
    0.8233053893400490
    0.8265018776778600
    0.8316948635878670
    0.8385570211463530
    0.8436023472031700
    0.8495938719132590
    0.8567005791800030
    0.8575898237984850
    0.8602728242645940
    0.8650358177107150
    0.8704085127261780
    0.8735010442088050
    0.8762246417546890
    0.8805155464106080
    0.8887123469122430
    0.8971860234720310
    0.9007582685566220
    0.9031397652796830
    0.9059737857191000
    0.9067120103642740
    0.9125237487966700
    0.9171820649956210
    0.9203216502685960
    0.9228712115373480
    0.9269953264918330
    0.9282350520176920
    0.9307302769427650
    0.9309636989655570
    0.9319966773271620
    0.9329324144714480
    0.9330915587282750
    0.9355548398880600
    0.9367681856822610
    0.9398439496371290
    0.9418118920982810
    0.9461693273523530
    0.9479351200659340
    0.9509184401437960
    0.9510730018397440
    0.9510753072638100
    0.9512659879725500
    0.9535441451444540
    0.9537297610553570
    0.9553807072298930
    0.9556297940112080
    0.9556379263583310
    0.9557063843251210
    0.9571981347056950
    0.9577246042878200
    0.9579240706000790
    0.9624296554620540
    0.9635691592333570
    0.9647076512980010
    0.9657937159396110
    0.9669691337220670
    0.9670217080928210
    0.9670957054602090
    0.9731626681732870
    0.9735960861730760
    0.9736625637507150
    0.9737420798624140
    0.9737747449456440
    0.9753822028913770
    0.9759566010621790
    0.9760163171312760
    0.9760441828997970
    0.9760482220824820
    0.9761225876809050
    0.9763458170428640
    0.9771465470581290
    0.9771525219605070
    0.9772317308264610
    0.9772512163624840
    0.9804122794353700
    0.9857600590221540
    0.9873871433519690
    0.9874611169591920
    0.9885921354234320
    0.9895578741766800
    0.9897125220037300
    0.9906216953475450
    0.9907277945393010
    0.9918420480761860
    0.9918600130891840
    0.9918690465469730
    0.9918691479521810
    0.9918695080368140
    0.9918695081588450
    0.9918695081755170
    0.9918695085490740
    0.9918695085723040
    0.9918695309087340
    0.9918696415743340
    0.9918701285564840
    0.9918904580412080
    0.9919994840135100
    0.9921265891086750
    0.9922689412735120
    0.9924237084548240
    0.9925880585994200
    0.9927591596541050
    0.9929341795656840
    0.9931102862809660
    0.9932846477467550
    0.9934544319098570
    0.9936168067170800
    0.9937689401152280
    0.9939080000511100
    0.9940311544715290
    0.9940722634501870
    0.9941182522740030
    0.9941392957757080
    0.9941775472456900
    0.9941918874895860
    0.9946720466470910
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9952518718560750
    0.9958207347651510
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9962625690757480
    0.9962823472668270
    0.9963508148512590
    0.9963538172817670
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    1.0000000000000000

  ]
  set available_aisle_not_filling [
    0.2021465096050900
    0.2057553240325020
    0.2084642478973460
    0.2116352142992790
    0.2139999661520320
    0.2164828583423220
    0.2220828864805770
    0.2392408972361320
    0.2515102134127230
    0.2636524210072530
    0.2770531253113780
    0.2883563306557520
    0.3256438264859390
    0.3353534840884330
    0.3469632010444230
    0.3594456327675500
    0.3699994465263500
    0.4010026001494480
    0.4078138071435390
    0.4127699068749540
    0.4328658782931750
    0.4478369581220050
    0.4518059941866220
    0.4600296874381240
    0.4701754108229120
    0.5269430211977510
    0.5457736155721820
    0.5749109665229390
    0.6019498388256570
    0.6281456190617090
    0.6308541351604870
    0.6560422314611330
    0.6760055813043200
    0.6803786348099330
    0.6830533607847310
    0.6862744208424660
    0.6893358959079710
    0.6916964383044330
    0.6955869797054900
    0.6996935079194650
    0.7214344768030310
    0.7433138859575770
    0.7461533821409480
    0.7493164294493350
    0.7518344153108880
    0.7702448692833370
    0.7828872634923190
    0.7861197746014620
    0.7893576841582240
    0.7917820323440140
    0.8120951930504570
    0.8419779367902250
    0.8457536837625710
    0.8487829787857020
    0.8505031490753960
    0.8537469759899330
    0.8567488666039980
    0.8626554642240990
    0.8687752758233700
    0.8713550413793020
    0.8762954675564560
    0.8784713712153150
    0.8786523312986750
    0.8798982735208450
    0.8808983778387520
    0.8810275118672790
    0.8823918326901400
    0.8828990470790620
    0.8831519762249070
    0.8841867575231500
    0.8843505776657990
    0.8854091304287470
    0.8854315214011100
    0.8861237861715000
    0.8869707720872590
    0.8876954497307110
    0.8877395801110980
    0.8888368575903580
    0.8889541482486380
    0.8897602233460660
    0.8899229955919380
    0.8899755827971590
    0.8911250215556630
    0.8911277248772630
    0.8922359741436670
    0.8923445489147220
    0.8932711221315190
    0.8934461872073830
    0.8944840714469600
    0.8945148759381160
    0.8955137409330710
    0.8962236213421680
    0.8967886103675460
    0.8967908138064970
    0.8979022120142290
    0.8980008278648510
    0.8991027677192660
    0.8993697924495990
    0.9001589154006360
    0.9010200890024800
    0.9012891601023310
    0.9013946417065870
    0.9024023123223450
    0.9030117653170090
    0.9035746123018050
    0.9046282824444490
    0.9057843264298220
    0.9058158280234190
    0.9059228205626940
    0.9070135470243360
    0.9073801253418090
    0.9079577908416430
    0.9080856644353190
    0.9080857400468650
    0.9089640253339070
    0.9103301339587160
    0.9114789154030210
    0.9127632812727600
    0.9132941827605380
    0.9149158940592480
    0.9151160154115350
    0.9160594157308860
    0.9172696187055590
    0.9335772423452820
    0.9469286761962860
    0.9516319416961230
    0.9594774509265780
    0.9745842252647130
    0.9775949582187230
    0.9782545611150220
    0.9782816787840330
    0.9782822482470420
    0.9782830083473950
    0.9783101273074690
    0.9794142824393810
    0.9794143758226760
    0.9794145086679580
    0.9794173292907900
    0.9794472351480470
    0.9794902308167550
    0.9803029738599460
    0.9803576855780180
    0.9804090556735960
    0.9804802184150220
    0.9805380325936880
    0.9805463058492110
    0.9805465759500300
    0.9805467005584280
    0.9805467969007430
    0.9805467972309770
    0.9805468004988140
    0.9805468199122150
    0.9806663387834610
    0.9809899508528530
    0.9821521982609820
    0.9828026930778880
    0.9828068508478170
    0.9828114100143040
    0.9828114422119220
    0.9829177190077140
    0.9830736687243650
    0.9839415587068130
    0.9839435714423610
    0.9839435985844600
    0.9839436107291100
    0.9839436114445090
    0.9839440400825900
    0.9839442574027980
    0.9839660850861600
    0.9850738129673270
    0.9850757971383240
    0.9850758629203660
    0.9850758814919010
    0.9850758818053360
    0.9850758841609210
    0.9850797678067160
    0.9851401231887760
    0.9851835593694550
    0.9852745614704480
    0.9862134597097420
    0.9871494324578880
    0.9873266006189060
    0.9873297090810890
    0.9873359445787750
    0.9873369042758450
    0.9873383687750170
    0.9873402192686210
    0.9873403795090180
    0.9873404179880970
    0.9873404223035330
    0.9873404240394290
    0.9873404240484530
    0.9873404240756320
    0.9873404241711150
    0.9873404243971790
    0.9873404305216810
    0.9873416757867180
    0.9873421496670420
    0.9884704197410580
    0.9884722648589600
    0.9884726951028450
    0.9884726951158560
    0.9884726951624380
    0.9884726960580000
    0.9884727072377490
    0.9884727263101580
    0.9884747889617290
    0.9885301146393990
    0.9893435088168370
    0.9896043660228150
    0.9896048647498890
    0.9896049622908000
    0.9896049654839690
    0.9896049662814340
    0.9896049662943250
    0.9896049662982120
    0.9896049665084580
    0.9896049668453050
    0.9896136093757430
    0.9896311368267630
    0.9906212175342460
    0.9907367593953650
    0.9907370138384200
    0.9907373571076620
    0.9907416161798760
    0.9907668819910250
    0.9907990615741390
    0.9916526828706250
    0.9918369520479810
    0.9918676697551740
    0.9918693870011670
    0.9918695055144050
    0.9918695085509870
    0.9918695087532970
    0.9918698030509790
    0.9918779241550210
    0.9919834171653460
    1.0000000000000000

  ]
  set not_available_aisle_but_filling [
   0.4391849635613770
    0.4418401066794180
    0.4439214551453020
    0.4459244290323170
    0.4477591378215800
    0.4523585543393290
    0.4726686035822560
    0.5210130697704780
    0.5824631369573760
    0.6178215367052290
    0.6324971030883140
    0.6487568967902250
    0.7017011904904220
    0.7345147703024910
    0.7542241643055930
    0.7600470753598140
    0.7653549598388490
    0.7698701605614390
    0.7737980669430000
    0.7817013813023900
    0.8152853730202640
    0.8261278277500810
    0.8299022639018000
    0.8470469201676940
    0.8773086739436380
    0.8999815829760170
    0.9074447798755490
    0.9172904346817230
    0.9243171314137080
    0.9284113260992050
    0.9316962088347400
    0.9496056622718390
    0.9635802151412390
    0.9697818849700430
    0.9731202882914920
    0.9772411346644800
    0.9791830581807720
    0.9805544690466860
    0.9817306521953210
    0.9828538125177340
    0.9840730845203170
    0.9850650653535740
    0.9851847314096600
    0.9860669893804020
    0.9873325312248690
    0.9885247712042750
    0.9893918125813870
    0.9896053201514290
    0.9897569976960810
    0.9907492109965040
    0.9918041442520830
    0.9919763099912350
    0.9930104947660360
    0.9930326516786160
    0.9940938636895320
    0.9941334326088300
    0.9941339143625880
    0.9941365755390360
    0.9942556181179220
    0.9943401913507380
    0.9951448368649000
    0.9951497697610600
    0.9952172406655690
    0.9952247786028150
    0.9952575849260560
    0.9952582120513410
    0.9952644630647960
    0.9952656079752800
    0.9952657707964560
    0.9952663031711500
    0.9952663187102120
    0.9952663204512280
    0.9952663224103980
    0.9952663241178770
    0.9952663267176720
    0.9952663367232270
    0.9952663856138370
    0.9952664062483210
    0.9952675506442930
    0.9952705425980870
    0.9952772755415720
    0.9952830377848440
    0.9952911696155990
    0.9953355148620810
    0.9953650333847810
    0.9953886051555940
    0.9954359600977390
    0.9954916839417580
    0.9955520609707690
    0.9955615338271210
    0.9956788591103430
    0.9958113961456320
    0.9959447137058080
    0.9960738534200410
    0.9961938569175050
    0.9962997658273710
    0.9963562473102310
    0.9963610359597270
    0.9963655368827820
    0.9963866217788100
    0.9963945853799850
    0.9963967351371410
    0.9963980415549880
    0.9963984171304990
    0.9963984350408260
    0.9963985809640760
    0.9963985812361070
    0.9963985922734820
    0.9963985930304680
    0.9963985930340760
    0.9963985930620590
    0.9963985930658510
    0.9963985930687440
    0.9963985930690390
    0.9963985930690410
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690510
    0.9963985930690560
    0.9963985930691580
    0.9963985930702380
    0.9963985930702520
    0.9963985930763370
    0.9963985930961580
    0.9963985931653340
    0.9963985970126850
    0.9963986364962110
    0.9963986399956720
    0.9963989888530730
    0.9963990590827560
    0.9964000504846140
    0.9964047572150280
    0.9964066114957530
    0.9964199420637680
    0.9964902766380520
    0.9965289305657840
    0.9966939828379370
    1.0000000000000000

  ]
  set not_available_aisle_and_not_filling [
    0.3923748708699550
    0.3952877904573790
    0.3986596394561770
    0.4006924849220200
    0.4040724466864010
    0.4077944726893930
    0.4108750421734790
    0.4145291895401740
    0.4200732026133680
    0.4256503916320670
    0.4320664829209640
    0.4385746772678500
    0.4444701116869040
    0.4478872694192800
    0.4543930146996560
    0.4610082833748240
    0.4667966434655960
    0.4750657293095560
    0.4825079065691210
    0.4874668087869540
    0.4932577181662690
    0.4990460782570410
    0.5056613469322090
    0.5122766156073770
    0.5188918842825450
    0.5279878787109010
    0.5354300559704650
    0.5424470940895710
    0.5472153001655520
    0.5526787832191550
    0.5569459144527360
    0.5599243375799010
    0.5620049056719550
    0.5649807541304180
    0.5679579131466320
    0.5697969964829730
    0.5729732770099390
    0.5761689458996910
    0.5792400635010430
    0.5836465180231370
    0.5908329311249980
    0.5966212912157700
    0.6047355286549840
    0.6148132800724820
    0.6206016401632540
    0.6305245431760060
    0.6396205376043620
    0.6445819891107380
    0.6520130310163500
    0.6594663436298670
    0.6658799458087530
    0.6751776067333910
    0.6823449133168200
    0.6892350526681230
    0.6950234127588950
    0.7031868378119750
    0.7123884930312110
    0.7189846425377910
    0.7258116986563700
    0.7329638601365710
    0.7354776446932500
    0.7405033849006750
    0.7447694017338160
    0.7487724707446360
    0.7545608308354080
    0.7620030080949720
    0.7686182767701400
    0.7735878623282710
    0.7818488141204760
    0.7876371742112480
    0.7934255343020200
    0.8008677115615840
    0.8041753458991680
    0.8099637059899400
    0.8140170045501250
    0.8145825235382790
    0.8185218441382970
    0.8227837131197350
    0.8261203840107100
    0.8299100027236380
    0.8369362542272520
    0.8380785978594050
    0.8446938665345730
    0.8481458996977330
    0.8543228002414850
    0.8586518768070330
    0.8631163752357550
    0.8680985663807370
    0.8723455279112750
    0.8766421272655620
    0.8797250978824150
    0.8829018833506390
    0.8847094541484590
    0.8866021027860210
    0.8885954978024350
    0.8901243079691760
    0.8911389405579650
    0.8921780179121470
    0.8939356089454200
    0.8947222164773440
    0.8955790373976160
    0.8966042303804740
    0.8981893417019410
    0.8990403114068460
    0.9000216982922610
    0.9012845918705400
    0.9024618061321590
    0.9036252348657370
    0.9048250980842490
    0.9059286945071010
    0.9068856433880040
    0.9081124121795340
    0.9081837533519460
    0.9086823481130590
    0.9113507895251600
    0.9125480110387110
    0.9149121414359640
    0.9149858111529110
    0.9160142212349720
    0.9170684157254070
    0.9182298242878500
    0.9192448475041240
    0.9207942078554520
    0.9227804112908110
    0.9240564833382830
    0.9250896195942360
    0.9262370867398780
    0.9282009009947570
    0.9290072692604940
    0.9307770184520180
    0.9318084404012250
    0.9336226651288930
    0.9353110052566810
    0.9363744121427300
    0.9385844831468180
    0.9401187591886750
    0.9420882892220230
    0.9472585593635400
    0.9533610958222210
    0.9592984355169170
    0.9634658760214830
    0.9674646332078850
    0.9696613954143540
    0.9702701147787040
    0.9722237048883060
    0.9734895837049610
    0.9737520175871040
    0.9745740457149480
    0.9753205752179390
    0.9761033110193970
    0.9771637815452990
    0.9782932894685060
    0.9783969917660590
    0.9793361379962130
    0.9805437125397340
    0.9805446688418690
    0.9806538259427450
    0.9812515539782450
    0.9827389466483630
    0.9828723212732520
    0.9848364824998880
    0.9851431691212790
    0.9859096860239490
    0.9872836291420530
    0.9873582143186670
    0.9875722918936880
    0.9883573504113370
    0.9884357579355040
    0.9895722735282120
    0.9896052422366850
    0.9896268962998210
    0.9913406846385200
    0.9916371789817480
    0.9918729998345350
    0.9918735719100640
    0.9943589157228750
    0.9951879170648970
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288946470
    0.9951912288951230
    0.9951912288951230
    0.9951912288951230
    0.9951912288951230
    0.9951912288951230
    0.9951912288951690
    0.9951912288951690
    0.9951912288951690
    0.9951912288951690
    0.9951912288951690
    0.9951912288951690
    0.9951912288951690
    0.9952077861443910
    0.9952750178368300
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9960181374790430
    0.9963952688232750
    0.9963955067767820
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9968450460634380
    0.9976719546478340
    0.9976719546478340
    0.9976719546478340
    0.9976719546478340
    1.0000000000000000
  ]
end

to setup_entrance_rate
  set entrances_rate [
    0.300466398
    0.302812699
    0.319295104
    0.335997863
    0.39163979
    0.467985589
    0.49135721
    0.553641718
    0.603049475
    0.636663009
    0.66365393
    0.712964348
    0.76533805
    0.78047067
    0.804601566
    0.81859888
    0.844507121
    0.8483624
    0.851697152
    0.860076157
    0.877400092
    0.880606966
    0.884351182
    0.893355658
    0.895996933
    0.899060325
    0.904177864
    0.926145029
    0.929558044
    0.935633545
    0.952668197
    0.960473838
    0.962876066
    0.973858484
    0.97832281
    0.9842078
    0.9889566
    0.992682209
    1
  ]
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
          ifelse(current_row > 1 and patch-at -1 0 != nobody and any? (turtles-on patch-at -1 0) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0  and abs(target_seat_col) > abs(current_seat_col) and stowing_time = 0]) [
            set transparent? true
            stop
          ]
          [
            set transparent? false
          ]
          if(count turtles-here > 1)[

            let my_patch (turtles-on patch-here) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0 and is_stowing? = false]
            let most_distant max-one-of my_patch [ abs(target_seat_col) ]
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
            ifelse(stop_moving = false)
            [
               fd (0 - patch_ticks_speed)
               set move_aisle? true
               set stop_moving true
            ]
            [
              set stop_moving false
            ]
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
              ifelse(stop_moving = false)
              [
                fd (0 - patch_ticks_speed)
                set move_aisle? true
                set stop_moving true
              ]
              [
                set stop_moving false
              ]

            ]
            set var true
          ]
        ]
        if var = true [stop]
      ]
    ]

    if(target_seat_row = (round aisle_row) + 1 and patch_ticks_speed > 1) [
      set patch_ticks_speed 1
    ]

    ifelse (patch-ahead 1 != nobody and ycor = 0 and ((any? (turtles-on patch-ahead 1) with [heading != 90 and transparent? = false]) or (any? (turtles-on patch-ahead 1) with [heading != 90 and analysed = true and not is_seated?] and stowing_time > 0)) and heading = 90)[
      set total_time_of_aisle_interferences total_time_of_aisle_interferences + 1
	    if on_aisle_interference? = false [
	      set number_of_aisle_interferences number_of_aisle_interferences + 1
	      set aisle_interferences aisle_interferences + 1
	      set on_aisle_interference? true
	    ]
	    stop
	   ]
	   [
      if (patch-ahead 1 != nobody and ycor = 0 and ((any? (turtles-on patch-ahead 1) with [heading = 90 and transparent? = false]) or (any? (turtles-on patch-ahead 1) with [heading = 90 and analysed = true] and stowing_time > 0)) and heading = 90)
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

      ifelse(stop_moving = false)
      [
        fd patch_ticks_speed
        if(heading = 90 or heading = 180)
        [
          set stop_moving true
        ]
      ]
      [
        set stop_moving false
      ]
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
      set move_aisle? false
   ]
   [
      if move_aisle? = true [stop]
      set total_time_of_seat_interferences total_time_of_seat_interferences + 1
      ifelse (count turtles-here = 1) [
        if ((patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1) with [analysed = true]) or (patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1))) [
          ifelse stop_moving = false [fd patch_ticks_speed set stop_moving true][set stop_moving false]
          stop
        ]
      ]
      [
        let my_patch (turtles-on patch-here) with [target_seat_row = current_row and target_seat_col * current_seat_col > 0 and is_stowing? = false]
        let most_distant max-one-of my_patch [ abs(target_seat_col) ]
        if (most_distant = self) [
          if (patch-ahead 1 != nobody and not any? (turtles-on patch-ahead 1)) [
            ifelse stop_moving = false [fd patch_ticks_speed set stop_moving true] [set stop_moving false]
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

to-report get_standard_deviation_satisfaction
  let satisfaction 0
  report standard-deviation get_all_satisfactions
end

to-report get_average_satisfaction_v2
  let satisfaction 0
  report mean get_all_satisfactions_v2
end

to-report get_standard_deviation_satisfaction_v2
  let satisfaction 0
  report standard-deviation get_all_satisfactions_v2
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

to-report get_average_aisle_interferences_per_person
  let total_interferences []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_aisle_interferences
  ]]

  report mean total_interferences
end

to-report get_standard_deviation_aisle_interferences_per_person
  let total_interferences []
   foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_aisle_interferences
  ]]

  report standard-deviation total_interferences
end

to-report get_median_seat_interferences_per_person
  let total_interferences []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_seat_interferences
  ]]

  report median total_interferences
end

to-report get_average_seat_interferences_per_person
  let total_interferences []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_seat_interferences
  ]]

  report mean total_interferences
end

to-report get_standard_deviation_seat_interferences_per_person
   let total_interferences []
  foreach boarded_agents [agent -> ask turtle agent [
    set total_interferences insert-item 0 total_interferences number_of_seat_interferences
  ]]

  report standard-deviation total_interferences
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
3

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
50.0
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

SLIDER
754
246
926
279
luggage_speed
luggage_speed
0.6
1
0.81
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
0
1
-1000

SWITCH
750
334
990
367
distributed_passenger_speed
distributed_passenger_speed
0
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
      <value value="0.81"/>
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
  <experiment name="human_steffen_0" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_kautzka_0_2" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_kautzka_0_3" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_block-back-to-front-0" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_back-to-front-0" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_random_0" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_wilma_0" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_steffen_50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_kautzka_50_2" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_kautzka_50_3" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_block-back-to-front-50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_back-to-front-50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_random_50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_wilma_50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_block-front-to-back-0" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_block-front-to-back-50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_front-to-back-0" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_front-to-back-50" repetitions="100" runMetricsEveryStep="false">
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_steffen_0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_kautzka_0_2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_kautzka_0_3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_block-back-to-front-0" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_back-to-front-0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_random_0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_wilma_0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_steffen_50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_kautzka_50_2" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_kautzka_50_3" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_block-back-to-front-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_back-to-front-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_random_50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
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
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_wilma_50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
    <metric>difference_time_with_luggage</metric>
    <metric>difference_time_without_luggage</metric>
    <metric>difference_average</metric>
    <metric>get_all_satisfactions</metric>
    <metric>get_all_boarding_times</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_block-front-to-back-0" repetitions="100" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_block-front-to-back-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_front-to-back-0" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="human_distributed_front-to-back-50" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>seat_interferences</metric>
    <metric>total_elapsed_time</metric>
    <metric>aisle_interferences</metric>
    <metric>get_average_satisfaction</metric>
    <metric>get_standard_deviation_satisfaction</metric>
    <metric>get_median_satisfaction</metric>
    <metric>get_average_satisfaction_v2</metric>
    <metric>get_standard_deviation_satisfaction_v2</metric>
    <metric>get_median_satisfaction_v2</metric>
    <metric>get_median_aisle_interferences_per_person</metric>
    <metric>get_median_seat_interferences_per_person</metric>
    <metric>get_average_aisle_interferences_per_person</metric>
    <metric>get_standard_deviation_aisle_interferences_per_person</metric>
    <metric>get_average_seat_interferences_per_person</metric>
    <metric>get_standard_deviation_seat_interferences_per_person</metric>
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
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="luggage_speed">
      <value value="0.81"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="family_size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distributed_passenger_speed">
      <value value="true"/>
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
