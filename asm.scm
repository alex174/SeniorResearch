(list

 (cons 'bfParams
  (make-instance 'BFParams
  #:numfcasts 100
  #:tauv  75.0D0
  #:lambda  0.5D0 
  #:maxbid  10.0D0
  #:mincount  2
  #:subrange   1  
  #:gafrequency   1000 
  #:firstgatime   100
  #:longtime   4000
  #:individual   1
  #:a_min   0.7D0
  #:a_max   1.2D0
  #:b_min   0D0
  #:b_max   0D0
  #:c_min   -10D0
  #:c_max   19.002D0
  #:newfcastvar   4.0D0 
  #:initvar   4.0D0
  #:bitcost   0.005D0
  #:maxdev   500D0 
  #:bitprob   0.1D0 
  #:poolfrac   0.2D0
  #:newfrac   0.2D0
  #:pcrossover   0.1D0
  #:psocial   0.0D0
  #:startsocial   100000
  #:plinear   0.333D0
  #:prandom   0.333D0
  #:pmutation   0.03D0
  #:plong   0.2D0
  #:pshort   0.2D0
  #:nhood   0.05D0
  #:genfrac   0.25D0 
  #:nnulls  4
  #:condbits 12
  #:npoolmax -1
  #:nnewmax -1
  #:ncondmax -1
))
  (cons 'asmModelParams
	(make-instance 'ASMModelParams	 
  #:numBFagents 25
  #:initholding 1D0
  #:initialcash 20000D0
  #:minholding -5D0
  #:mincash -2000D0
  #:intrate 0.1D0
  #:baseline 10D0  
  #:mindividend 0.00005D0
  #:maxdividend 100D0
  #:amplitude 0.0873D0
  #:period 19.5D0
  #:maxprice 99999D0
  #:minprice 0.001D0
  #:taup 50.0D0
  #:sptype 1
  #:maxiterations 20 
  #:minexcess 0.01D0
  #:eta 0.0005D0
  #:etamax 0.05D0
  #:etamin 0.00001D0
  #:rea 6.333D0
  #:reb 16.6882D0
  #:randomSeed 0
  #:maxbid  10.0D0
  #:maxdev  500D0
  #:exponentialMAs 1 
))

  (cons 'asmBatchSwarm
	(make-instance 'ASMBatchSwarm
  #:loggingFrequency 1000 
  #:experimentDuration 350000
 ))
)




