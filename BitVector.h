#import <objectbase/SwarmObject.h>

@interface BitVector: SwarmObject
{
  unsigned int *conditions; 
  int condwords;
  int condbits;
}


- createEnd;

+ init;

-(void) setCondwords: (int) x;

-(void)  setCondbits: (int) x;

-(void) setConditions: (int *) x;

-(int *) getConditions;

-(void) setConditionsWord: (int) i To: (int) value;

-(int) getConditionsWord: (int) x;

-(void) setConditionsbit: (int) bit To: (int) x;

-(int) getConditionsbit: (int)bit;

-(void) setConditionsbitToThree: (int) bit;

-(void) switchConditionsbit: (int) bit;

-(void) setConditionsbit: (int) bit FromZeroTo: (int) x;

-(void) maskConditionsbit: (int) bit;

- (void) drop;

- printcond: (int) word;

@end
