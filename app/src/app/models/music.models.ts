// API Response Models (PascalCase to match FastAPI responses)
export interface Note {
  NoteId: number;
  NoteName: string;
  EnharmonicEquivalent?: string;
  SemitonesFromC: number;
  IsNatural: boolean;
  IsSharp: boolean;
  IsFlat: boolean;
}

export interface Interval {
  IntervalId: number;
  IntervalName: string;
  Semitones: number;
  IntervalShortName?: string;
}

export interface IntervalFromNote {
  FromNote: string;
  ToNote: string;
  IntervalName: string;
  Semitones: number;
}

export interface ScaleType {
  ScaleTypeId: number;
  ScaleName: string;
  IntervalPattern: string;
  Description?: string;
}

export interface ScaleDegree {
  DegreeNumber: number;
  ScaleDegree: string;
  Note: string;
  SemitonesFromRoot: number;
  IntervalName: string;
  RomanNumeral?: string;
  ScaleName: string;
}

export interface Scale {
  ScaleTypeId: number;
  ScaleName: string;
  RootNote: string;
  Notes: string[];
  RomanNumerals: string[];
  IntervalPattern: string;
}

export interface ChordType {
  ChordTypeId: number;
  ChordName: string;
  ChordSymbol?: string;
  IntervalPattern: string;
  Description?: string;
}

export interface ArpeggioDegree {
  NotePosition: number;
  ChordTone: string;
  Note: string;
  SemitonesFromRoot: number;
  IntervalName: string;
  RomanNumeral?: string;
  ChordName: string;
  ChordSymbol: string;
  FullChordSymbol: string;
}

export interface Arpeggio {
  ChordTypeId: number;
  ChordName: string;
  RootNote: string;
  Notes: string[];
  RomanNumerals: string[];
  IntervalPattern: string;
}

export interface ChordExtension {
  ExtensionId: number;
  ChordTypeId: number;
  ExtensionName: string;
  ExtensionSymbol: string;
  Semitones: number;
  Description: string | null;
  IsCommonInJazz: boolean;
  DisplayOrder: number;
  Note: string | null;
}

export interface HealthCheck {
  status: string;
  database: string;
  timestamp: string;
  responseTimeMs: number;
  checks: {
    database?: {
      status: string;
      responseTimeMs?: number;
      error?: string;
      errorType?: string;
    };
    authentication?: {
      status: string;
      method?: string;
      note?: string;
      error?: string;
    };
  };
}
