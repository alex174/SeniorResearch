// The Santa Fe Stockmarket -- Front End Protocols

// These are method declarations for all frontend methods that are
// called by the backend.  The frontend objects actually implement
// them (i.e., they "adopt" the protocols here).  The point of separating
// these out is so that the backend objects do not have to import the
// frontend interface files, to keep a clean separation.

// In the non-NEXTSTEP (gcc) version, which has no frontend, these
// protocols are not adopted at all.  But neither are they ever called.


@protocol MarketInterface
- updateEnabledStatus:(int)idx;
- preEvolve;
- postEvolve;
- divParamsChanged:sender;
- updateSpecialistType;
- updateEtaFields;
@end
