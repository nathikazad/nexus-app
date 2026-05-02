/// KGQL / attribute keys for Daily Log rows — only the data layer imports these.
library;

const String kDailyLogModelTypeName = 'Daily Log';

const String kDailyLogAttrLoggedAt = 'logged_at';
const String kDailyLogAttrEntry = 'entry';

/// Tag system on Daily Log used for feeling assignments (flat, multiple).
const String kDailyLogFeelingTagSystemName = 'Feeling';
