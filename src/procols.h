// The Santa Fe Stock Market -- Interface for Protocols class
// Copyright (C) The Santa Fe Institute, 1995.
// No warranty implied; see LICENSE for terms.

// These are method declarations for all the frontend methods that are
// called by the backend.  The frontend objects actually implement
// them (i.e., they "adopt" the protocols here).  The point of separating
// these out is so that the backend objects do not have to import the
// frontend interface files, to keep a clean separation.

// In the non-NEXTSTEP (gcc) version, which has no frontend, these
// protocols are not adopted at all.  But neither are they ever called.

#ifndef _Protocols_h
#define _Protocols_h

@protocol MarketInterface
- updateEnabledStatus:(int)idx;
- preEvolve;
- postEvolve;
- divParamsChanged:sender;
- updateSpecialistType;
- updateEtaFields;
@end

#endif /* _Protocols_h */
