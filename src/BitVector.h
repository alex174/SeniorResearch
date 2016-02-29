#import <objectbase/SwarmObject.h>

@interface BitVector: SwarmObject
{
  int condwords; /*"Number of words of memory required to hold bits in this model"*/
  int condbits;  /*"The number of conditions bits we expect to actually use"*/
  unsigned int *conditions; /*points to a dynamically allocated array of "condwords" elements"*/
}


- init;

+ init;

- (void)setCondwords: (int)x;

- (void)setCondbits: (int)x;

- (void)setConditions: (int *)x;

- (int *)getConditions;

- (void)setConditionsWord: (int)i To: (int)value;

- (int)getConditionsWord: (int)i;

- (void)setConditionsbit: (int)bit To: (int)x;

- (int)getConditionsbit: (int)bit;

- (void)setConditionsbitToThree: (int)bit;

- (void)switchConditionsbit: (int)bit;

- (void)setConditionsbit: (int)bit FromZeroTo: (int)x;

- (void)maskConditionsbit: (int)bit;

- (void)drop;

- printcond: (int)word;

- (void)lispOutDeep: stream;

@end
