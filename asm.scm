(list

 (cons 'bfParams
  (make-instance 'BFParams
  #:numfcasts 60
  #:tauv  50.0
  #:lambda  0.3 
  #:maxbid  10.0
  #:mincount  5
  #:subrange   0.5  
  #:gafrequency   100 
  #:firstgatime   100
  #:longtime   2000
  #:individual   0
  #:a_min   0.0D0
  #:a_max   1.98D0
  #:b_min   0D0
  #:b_max   0D0
  #:c_min   -10D0
  #:c_max   11.799979D0
  #:newfcastvar   4.000212D0 
  #:initvar   4.000212D0
  #:bitcost   0.01D0
  #:maxdev   100D0 
  #:bitprob   0.1D0 
  #:poolfrac   0.1D0
  #:newfrac   0.05D0
  #:pcrossover   0.3D0
  #:plinear   0.333D0
  #:prandom   0.333D0
  #:pmutation   0.01D0
  #:plong   0.05D0
  #:pshort   0.2D0
  #:nhood   0.05D0
  #:genfrac   0.10D0 
  #:nnulls  0
  #:lastgatime 1
  #:condbits 16
  #:npoolmax -1
  #:nnewmax -1
  #:ncondmax -1
))
  (cons 'asmModelParams
	(make-instance 'ASMModelParams	 
  #:numBFagents 30
  #:initholding 1F0
  #:initialcash 10000D0
  #:minholding 0D0
  #:mincash 0D0
  #:intrate 0.1D0
  #:baseline 10D0  
  #:mindividend 0.00005D0
  #:maxdividend 100D0
  #:amplitude 0.14178D0
  #:period 1.0
  #:maxprice 500D0
  #:minprice 0.001D0
  #:taup 50.0D0
  #:sptype 2
  #:maxiterations 10 
  #:minexcess 0.01
  #:eta 0.0005D0
  #:etamax 0.05D0
  #:etamin 0.00001D0
  #:rea 9.0D0
  #:reb 2.0D0
  #:randomSeed 0  
  #:tauv  50.0D0         
  #:lambda 0.3D0
  #:maxbid  10.0D0
  #:initvar 0.4000212D0
  #:maxdev  100D0
  #:exponentialMAs 1 
))


  (cons 'asmBatchParams
	(make-instance 'ASMModelParams	 
  #:numBFagents 30
  #:initholding 1F0
  #:initialcash 10000D0
  #:minholding 0D0
  #:mincash 0D0
  #:intrate 0.1D0
  #:baseline 10D0  
  #:mindividend 0.00005D0
  #:maxdividend 100D0
  #:amplitude 0.14178D0
  #:period 1.0
  #:maxprice 500D0
  #:minprice 0.001D0
  #:taup 50.0D0
  #:sptype 2
  #:maxiterations 10 
  #:minexcess 0.01
  #:eta 0.0005D0
  #:etamax 0.05D0
  #:etamin 0.00001D0
  #:rea 9.0D0
  #:reb 2.0D0
  #:randomSeed 0  
  #:tauv  50.0D0         
  #:lambda 0.3D0
  #:maxbid  10.0D0
  #:initvar 0.4000212D0
  #:maxdev  100D0
  #:exponentialMAs 1 
  #:setOutputForData 1
))

  (cons 'asmBatchSwarm
	(make-instance 'ASMBatchSwarm
  #:loggingFrequency 1
  #:experimentDuration 500
))
)




