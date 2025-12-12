-- Music Theory Database Setup
-- This script creates tables for music notes, scales, and intervals

-- Create Notes table with chromatic scale
IF OBJECT_ID('dbo.Notes', 'U') IS NOT NULL
    DROP TABLE dbo.Notes;

CREATE TABLE dbo.Notes (
    NoteId INT PRIMARY KEY,
    NoteName NVARCHAR(10) NOT NULL,
    EnharmonicEquivalent NVARCHAR(10) NULL,
    SemitonesFromC INT NOT NULL,  -- Number of semitones from C (for interval calculations)
    IsNatural BIT NOT NULL,
    IsSharp BIT NOT NULL,
    IsFlat BIT NOT NULL,
    CONSTRAINT UQ_Notes_NoteName UNIQUE (NoteName)
);
GO

-- Insert all chromatic notes (12 semitones)
INSERT INTO dbo.Notes (NoteId, NoteName, EnharmonicEquivalent, SemitonesFromC, IsNatural, IsSharp, IsFlat) VALUES
-- Natural notes
(1, 'C', NULL, 0, 1, 0, 0),
(2, 'C#', 'Db', 1, 0, 1, 0),
(3, 'D', NULL, 2, 1, 0, 0),
(4, 'D#', 'Eb', 3, 0, 1, 0),
(5, 'E', NULL, 4, 1, 0, 0),
(6, 'F', NULL, 5, 1, 0, 0),
(7, 'F#', 'Gb', 6, 0, 1, 0),
(8, 'G', NULL, 7, 1, 0, 0),
(9, 'G#', 'Ab', 8, 0, 1, 0),
(10, 'A', NULL, 9, 1, 0, 0),
(11, 'A#', 'Bb', 10, 0, 1, 0),
(12, 'B', NULL, 11, 1, 0, 0),
-- Enharmonic flat equivalents (for completeness)
(13, 'Db', 'C#', 1, 0, 0, 1),
(14, 'Eb', 'D#', 3, 0, 0, 1),
(15, 'Gb', 'F#', 6, 0, 0, 1),
(16, 'Ab', 'G#', 8, 0, 0, 1),
(17, 'Bb', 'A#', 10, 0, 0, 1);
GO

-- Create Intervals table for music theory
IF OBJECT_ID('dbo.Intervals', 'U') IS NOT NULL
    DROP TABLE dbo.Intervals;

CREATE TABLE dbo.Intervals (
    IntervalId INT PRIMARY KEY,
    IntervalName NVARCHAR(50) NOT NULL,
    Semitones INT NOT NULL,
    ShortName NVARCHAR(10) NOT NULL,
    RomanNumeral NVARCHAR(10) NOT NULL,
    Description NVARCHAR(200) NULL
);
GO

-- Insert standard intervals with roman numerals
-- Using ♭ (U+266D) for flat, ♯ (U+266F) for sharp
INSERT INTO dbo.Intervals (IntervalId, IntervalName, Semitones, ShortName, RomanNumeral, Description) VALUES
(1, 'Unison', 0, 'P1', 'I', 'Perfect Unison - Same note'),
(2, 'Minor Second', 1, 'min2', '♭II', 'Half step'),
(3, 'Major Second', 2, 'maj2', 'II', 'Whole step'),
(4, 'Minor Third', 3, 'min3', '♭III', 'Three semitones'),
(5, 'Major Third', 4, 'maj3', 'III', 'Four semitones'),
(6, 'Perfect Fourth', 5, 'P4', 'IV', 'Five semitones'),
(7, 'Tritone', 6, 'TT', '♭V', 'Augmented 4th / Diminished 5th'),
(8, 'Perfect Fifth', 7, 'P5', 'V', 'Seven semitones'),
(9, 'Minor Sixth', 8, 'min6', '♭VI', 'Eight semitones'),
(10, 'Major Sixth', 9, 'maj6', 'VI', 'Nine semitones'),
(11, 'Minor Seventh', 10, 'min7', '♭VII', 'Ten semitones'),
(12, 'Major Seventh', 11, 'maj7', 'VII', 'Eleven semitones'),
(13, 'Octave', 12, 'P8', 'VIII', 'Perfect Octave - Twelve semitones');
GO

-- Create Scale Types table
IF OBJECT_ID('dbo.ScaleTypes', 'U') IS NOT NULL
    DROP TABLE dbo.ScaleTypes;

CREATE TABLE dbo.ScaleTypes (
    ScaleTypeId INT PRIMARY KEY,
    ScaleName NVARCHAR(50) NOT NULL,
    IntervalPattern NVARCHAR(50) NOT NULL,  -- Pattern of semitones (e.g., '2,2,1,2,2,2,1' for major)
    Description NVARCHAR(200) NULL
);
GO

-- Insert common scale types
INSERT INTO dbo.ScaleTypes (ScaleTypeId, ScaleName, IntervalPattern, Description) VALUES
(1, 'Major', '2,2,1,2,2,2,1', 'Ionian mode - Happy, bright sound'),
(2, 'Natural Minor', '2,1,2,2,1,2,2', 'Aeolian mode - Sad, dark sound'),
(3, 'Harmonic Minor', '2,1,2,2,1,3,1', 'Minor with raised 7th'),
(4, 'Melodic Minor', '2,1,2,2,2,2,1', 'Minor with raised 6th and 7th (ascending)'),
(5, 'Dorian', '2,1,2,2,2,1,2', 'Minor with raised 6th'),
(6, 'Phrygian', '1,2,2,2,1,2,2', 'Minor with lowered 2nd'),
(7, 'Lydian', '2,2,2,1,2,2,1', 'Major with raised 4th'),
(8, 'Mixolydian', '2,2,1,2,2,1,2', 'Major with lowered 7th'),
(9, 'Locrian', '1,2,2,1,2,2,2', 'Diminished scale'),
(10, 'Pentatonic Major', '2,2,3,2,3', 'Five-note major scale'),
(11, 'Pentatonic Minor', '3,2,2,3,2', 'Five-note minor scale'),
(12, 'Blues', '3,2,1,1,3,2', 'Blues scale with blue notes'),
(13, 'Chromatic', '1,1,1,1,1,1,1,1,1,1,1,1', 'All twelve notes'),
(14, 'Altered', '1,2,1,2,2,2,2', 'Super Locrian - 7th mode of melodic minor');
GO

-- Create KeySignatures table to define which accidentals to use for each scale
IF OBJECT_ID('dbo.KeySignatures', 'U') IS NOT NULL
    DROP TABLE dbo.KeySignatures;

CREATE TABLE dbo.KeySignatures (
    KeySignatureId INT PRIMARY KEY IDENTITY(1,1),
    RootNote NVARCHAR(10) NOT NULL,
    ScaleTypeId INT NOT NULL,
    PreferredAccidental NVARCHAR(10) NOT NULL, -- 'sharp', 'flat', or 'natural'
    ScaleLetterSequence NVARCHAR(50) NOT NULL, -- e.g., 'C,D,E,F,G,A,B' for C major
    Description NVARCHAR(200) NULL,
    CONSTRAINT FK_KeySig_ScaleType FOREIGN KEY (ScaleTypeId) REFERENCES dbo.ScaleTypes(ScaleTypeId)
);
GO

-- Create ChordKeySignatures table for proper note spelling in arpeggios
IF OBJECT_ID('dbo.ChordKeySignatures', 'U') IS NOT NULL
    DROP TABLE dbo.ChordKeySignatures;

CREATE TABLE dbo.ChordKeySignatures (
    ChordKeySignatureId INT PRIMARY KEY IDENTITY(1,1),
    RootNote NVARCHAR(10) NOT NULL,
    PreferredAccidental NVARCHAR(10) NOT NULL, -- 'sharp', 'flat', or 'natural'
    Description NVARCHAR(200) NULL
);
GO

-- Create Chord Types table for arpeggios
IF OBJECT_ID('dbo.ChordTypes', 'U') IS NOT NULL
    DROP TABLE dbo.ChordTypes;

CREATE TABLE dbo.ChordTypes (
    ChordTypeId INT PRIMARY KEY,
    ChordName NVARCHAR(50) NOT NULL,
    ChordSymbol NVARCHAR(20) NOT NULL,
    IntervalPattern NVARCHAR(100) NOT NULL,  -- Semitones from root (e.g., '0,4,7' for major triad)
    Description NVARCHAR(200) NULL
);
GO

-- Insert common chord types with extensions
INSERT INTO dbo.ChordTypes (ChordTypeId, ChordName, ChordSymbol, IntervalPattern, Description) VALUES
-- Triads
(1, 'Major', 'maj', '0,4,7', 'Major triad - 1, 3, 5'),
(2, 'Minor', 'min', '0,3,7', 'Minor triad - 1, b3, 5'),
(3, 'Diminished', 'dim', '0,3,6', 'Diminished triad - 1, b3, b5'),
(4, 'Augmented', 'aug', '0,4,8', 'Augmented triad - 1, 3, #5'),

-- Seventh chords
(5, 'Major 7', 'maj7', '0,4,7,11', 'Major seventh - 1, 3, 5, 7'),
(6, 'Minor 7', 'min7', '0,3,7,10', 'Minor seventh - 1, b3, 5, b7'),
(7, 'Dominant 7', '7', '0,4,7,10', 'Dominant seventh - 1, 3, 5, b7'),
(8, 'Half Diminished', 'm7b5', '0,3,6,10', 'Half diminished - 1, b3, b5, b7'),
(9, 'Diminished 7', 'dim7', '0,3,6,9', 'Diminished seventh - 1, b3, b5, bb7'),
(10, 'Minor Major 7', 'mMaj7', '0,3,7,11', 'Minor major seventh - 1, b3, 5, 7'),

-- Sixth chords
(11, 'Major 6', '6', '0,4,7,9', 'Major sixth - 1, 3, 5, 6'),
(12, 'Minor 6', 'min6', '0,3,7,9', 'Minor sixth - 1, b3, 5, 6'),

-- Ninth chords
(13, 'Major 9', 'maj9', '0,4,7,11,14', 'Major ninth - 1, 3, 5, 7, 9'),
(14, 'Minor 9', 'min9', '0,3,7,10,14', 'Minor ninth - 1, b3, 5, b7, 9'),
(15, 'Dominant 9', '9', '0,4,7,10,14', 'Dominant ninth - 1, 3, 5, b7, 9'),
(16, 'Dominant 7b9', '7b9', '0,4,7,10,13', 'Dominant flat nine - 1, 3, 5, b7, b9'),
(17, 'Dominant 7#9', '7#9', '0,4,7,10,15', 'Dominant sharp nine - 1, 3, 5, b7, #9'),

-- Eleventh chords
(18, 'Minor 11', 'min11', '0,3,7,10,14,17', 'Minor eleventh - 1, b3, 5, b7, 9, 11'),
(19, 'Dominant 11', '11', '0,4,7,10,14,17', 'Dominant eleventh - 1, 3, 5, b7, 9, 11'),

-- Thirteenth chords
(20, 'Major 13', 'maj13', '0,4,7,11,14,21', 'Major thirteenth - 1, 3, 5, 7, 9, 13'),
(21, 'Minor 13', 'min13', '0,3,7,10,14,21', 'Minor thirteenth - 1, b3, 5, b7, 9, 13'),
(22, 'Dominant 13', '13', '0,4,7,10,14,21', 'Dominant thirteenth - 1, 3, 5, b7, 9, 13'),

-- Suspended chords
(23, 'Sus2', 'sus2', '0,2,7', 'Suspended second - 1, 2, 5'),
(24, 'Sus4', 'sus4', '0,5,7', 'Suspended fourth - 1, 4, 5'),
(25, 'Dom7Sus4', '7sus4', '0,5,7,10', 'Dominant seventh suspended fourth - 1, 4, 5, b7'),

-- Altered extensions
(26, 'Dominant 7#11', '7#11', '0,4,7,10,18', 'Dominant sharp eleven - 1, 3, 5, b7, #11'),
(27, 'Dominant 7b13', '7b13', '0,4,7,10,20', 'Dominant flat thirteen - 1, 3, 5, b7, b13'),
(28, 'Dominant 7#9#11', '7#9#11', '0,4,7,10,15,18', 'Dominant altered - 1, 3, 5, b7, #9, #11');
GO

-- Chord Extensions table for Jazz extensions
IF OBJECT_ID('dbo.ChordExtensions', 'U') IS NOT NULL
    DROP TABLE dbo.ChordExtensions;

CREATE TABLE dbo.ChordExtensions (
    ExtensionId INT PRIMARY KEY IDENTITY(1,1),
    ChordTypeId INT NOT NULL,
    ExtensionName NVARCHAR(50) NOT NULL,
    ExtensionSymbol NVARCHAR(20) NOT NULL,
    Semitones INT NOT NULL,
    Description NVARCHAR(200) NULL,
    IsCommonInJazz BIT NOT NULL DEFAULT 1,
    DisplayOrder INT NOT NULL DEFAULT 0,
    CONSTRAINT FK_ChordExtensions_ChordTypes FOREIGN KEY (ChordTypeId) 
        REFERENCES dbo.ChordTypes(ChordTypeId)
);
GO

-- Insert common Jazz chord extensions
INSERT INTO dbo.ChordExtensions (ChordTypeId, ExtensionName, ExtensionSymbol, Semitones, Description, IsCommonInJazz, DisplayOrder) VALUES
-- Major chord extensions (ChordTypeId 5 = Major 7)
(5, 'Major 9', '9', 14, 'Natural 9th - adds warmth', 1, 1),
(5, 'Major 11', '11', 17, 'Natural 11th - use with caution', 0, 2),
(5, 'Major 13', '13', 21, 'Natural 13th - lush sound', 1, 3),

-- Minor chord extensions (ChordTypeId 6 = Minor 7)
(6, 'Minor 9', '9', 14, 'Natural 9th - smooth extension', 1, 1),
(6, 'Minor 11', '11', 17, 'Natural 11th - common in jazz', 1, 2),
(6, 'Minor flat 13', 'b13', 20, 'Flat 13th - darker color', 1, 3),

-- Dominant chord extensions (ChordTypeId 7 = Dominant 7)
(7, 'Dominant 9', '9', 14, 'Natural 9th - standard extension', 1, 1),
(7, 'Dominant flat 9', 'b9', 13, 'Flat 9th - tension and resolution', 1, 2),
(7, 'Dominant sharp 9', '#9', 15, 'Sharp 9th - Hendrix chord', 1, 3),
(7, 'Dominant sharp 11', '#11', 18, 'Sharp 11th - Lydian dominant', 1, 4),
(7, 'Dominant flat 13', 'b13', 20, 'Flat 13th - altered sound', 1, 5),
(7, 'Dominant 13', '13', 21, 'Natural 13th - full extension', 1, 6),
(7, 'Augmented 5th', '#5', 8, 'Sharp 5th - altered dominant', 1, 7),

-- Half Diminished extensions (ChordTypeId 8 = Half Diminished)
(8, 'Minor 9', '9', 14, 'Natural 9th - softens the sound', 1, 1),
(8, 'Minor 11', '11', 17, 'Natural 11th - adds color', 1, 2),

-- Minor Major 7 extensions (ChordTypeId 10 = Minor Major 7)
(10, 'Minor Major 9', '9', 14, 'Natural 9th - exotic sound', 1, 1),

-- Dominant 9 extensions (ChordTypeId 15 = Dominant 9)
(15, 'Sharp 11', '#11', 18, 'Sharp 11th - Lydian b7', 1, 1),
(15, 'Flat 13', 'b13', 20, 'Flat 13th - altered extension', 1, 2);
GO

-- Enhanced Arpeggio Generation Function with Proper Note Spelling
-- Drop function regardless of type (IF = inline, TF = multi-statement)
IF OBJECT_ID('dbo.fn_GenerateArpeggio', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GenerateArpeggio;
IF OBJECT_ID('dbo.fn_GenerateArpeggio', 'TF') IS NOT NULL
    DROP FUNCTION dbo.fn_GenerateArpeggio;
GO

CREATE FUNCTION dbo.fn_GenerateArpeggio
(
    @RootNote NVARCHAR(10),
    @ChordTypeId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH ChordInfo AS (
        SELECT 
            n.NoteName,
            n.SemitonesFromC,
            ct.ChordName,
            ct.ChordSymbol,
            ct.IntervalPattern,
            COALESCE(cks.PreferredAccidental, 
                     CASE WHEN n.IsFlat = 1 THEN 'flat' ELSE 'sharp' END) AS PreferredAccidental
        FROM dbo.Notes n
        CROSS JOIN dbo.ChordTypes ct
        LEFT JOIN dbo.ChordKeySignatures cks ON cks.RootNote = n.NoteName
        WHERE n.NoteName = @RootNote
          AND ct.ChordTypeId = @ChordTypeId
    ),
    SplitSemitones AS (
        SELECT 
            ci.NoteName AS RootNote,
            ci.SemitonesFromC AS RootSemitone,
            ci.ChordName,
            ci.ChordSymbol,
            ci.PreferredAccidental,
            CAST(value AS INT) AS Semitones,
            ROW_NUMBER() OVER (ORDER BY CAST(value AS INT)) AS NotePosition
        FROM ChordInfo ci
        CROSS APPLY STRING_SPLIT(ci.IntervalPattern, ',')
    )
    SELECT 
        ss.NotePosition,
        CASE 
            WHEN ss.Semitones = 0 THEN 'Root'
            WHEN ss.Semitones = 1 THEN 'b9'
            WHEN ss.Semitones = 2 THEN '9/2'
            WHEN ss.Semitones = 3 THEN 'b3/#9'
            WHEN ss.Semitones = 4 THEN '3'
            WHEN ss.Semitones = 5 THEN '4/11'
            WHEN ss.Semitones = 6 THEN 'b5/#11'
            WHEN ss.Semitones = 7 THEN '5'
            WHEN ss.Semitones = 8 THEN '#5/b13'
            WHEN ss.Semitones = 9 THEN '6/bb7'
            WHEN ss.Semitones = 10 THEN 'b7'
            WHEN ss.Semitones = 11 THEN '7'
            WHEN ss.Semitones = 12 THEN 'Root (8ve)'
            WHEN ss.Semitones = 13 THEN 'b9 (8ve)'
            WHEN ss.Semitones = 14 THEN '9'
            WHEN ss.Semitones = 15 THEN '#9'
            WHEN ss.Semitones = 16 THEN '3 (8ve)'
            WHEN ss.Semitones = 17 THEN '11'
            WHEN ss.Semitones = 18 THEN '#11'
            WHEN ss.Semitones = 19 THEN '5 (8ve)'
            WHEN ss.Semitones = 20 THEN 'b13'
            WHEN ss.Semitones = 21 THEN '13'
            WHEN ss.Semitones = 22 THEN 'b7 (8ve)'
            WHEN ss.Semitones = 23 THEN '7 (8ve)'
            WHEN ss.Semitones = 24 THEN 'Root (2 8ve)'
            ELSE CAST(ss.Semitones AS NVARCHAR(10))
        END AS ChordTone,
        -- Select the correct note based on chord's preferred accidental
        -- Always return a note (fallback to any note if preferred not found)
        COALESCE(
            (SELECT TOP 1 NoteName
             FROM dbo.Notes
             WHERE SemitonesFromC = (ss.RootSemitone + ss.Semitones) % 12
               AND (
                   -- Prefer the accidental type based on chord root
                   (ss.PreferredAccidental = 'sharp' AND (IsSharp = 1 OR IsNatural = 1)) OR
                   (ss.PreferredAccidental = 'flat' AND (IsFlat = 1 OR IsNatural = 1)) OR
                   (ss.PreferredAccidental = 'natural' AND IsNatural = 1)
               )
             ORDER BY 
                 IsNatural DESC,
                 CASE WHEN ss.PreferredAccidental = 'flat' THEN IsFlat ELSE IsSharp END DESC
            ),
            -- Fallback: get any note with the correct semitone
            (SELECT TOP 1 NoteName
             FROM dbo.Notes
             WHERE SemitonesFromC = (ss.RootSemitone + ss.Semitones) % 12
             ORDER BY IsNatural DESC, IsFlat DESC
            )
        ) AS Note,
        ss.Semitones AS SemitonesFromRoot,
        i.IntervalName,
        i.RomanNumeral,
        ss.ChordName,
        ss.ChordSymbol,
        ss.RootNote + ss.ChordSymbol AS FullChordSymbol
    FROM SplitSemitones ss
    LEFT JOIN dbo.Intervals i ON i.Semitones = (ss.Semitones % 12)
);
GO

-- Insert key signatures for all Major scales (following circle of fifths)
INSERT INTO dbo.KeySignatures (RootNote, ScaleTypeId, PreferredAccidental, ScaleLetterSequence, Description) VALUES
-- Major scales
('C', 1, 'natural', 'C,D,E,F,G,A,B', 'C Major - No sharps or flats'),
('G', 1, 'sharp', 'G,A,B,C,D,E,F', 'G Major - 1 sharp (F#)'),
('D', 1, 'sharp', 'D,E,F,G,A,B,C', 'D Major - 2 sharps (F#, C#)'),
('A', 1, 'sharp', 'A,B,C,D,E,F,G', 'A Major - 3 sharps (F#, C#, G#)'),
('E', 1, 'sharp', 'E,F,G,A,B,C,D', 'E Major - 4 sharps (F#, C#, G#, D#)'),
('B', 1, 'sharp', 'B,C,D,E,F,G,A', 'B Major - 5 sharps (F#, C#, G#, D#, A#)'),
('F#', 1, 'sharp', 'F,G,A,B,C,D,E', 'F# Major - 6 sharps (F#, C#, G#, D#, A#, E#)'),
('C#', 1, 'sharp', 'C,D,E,F,G,A,B', 'C# Major - 7 sharps (all notes sharp)'),
('F', 1, 'flat', 'F,G,A,B,C,D,E', 'F Major - 1 flat (Bb)'),
('Bb', 1, 'flat', 'B,C,D,E,F,G,A', 'Bb Major - 2 flats (Bb, Eb)'),
('Eb', 1, 'flat', 'E,F,G,A,B,C,D', 'Eb Major - 3 flats (Bb, Eb, Ab)'),
('Ab', 1, 'flat', 'A,B,C,D,E,F,G', 'Ab Major - 4 flats (Bb, Eb, Ab, Db)'),
('Db', 1, 'flat', 'D,E,F,G,A,B,C', 'Db Major - 5 flats (Bb, Eb, Ab, Db, Gb)'),
('Gb', 1, 'flat', 'G,A,B,C,D,E,F', 'Gb Major - 6 flats (Bb, Eb, Ab, Db, Gb, Cb)'),
-- Natural Minor scales (relative minors)
('A', 2, 'natural', 'A,B,C,D,E,F,G', 'A Natural Minor - No sharps or flats (relative to C Major)'),
('E', 2, 'sharp', 'E,F,G,A,B,C,D', 'E Natural Minor - 1 sharp (F#) (relative to G Major)'),
('B', 2, 'sharp', 'B,C,D,E,F,G,A', 'B Natural Minor - 2 sharps (F#, C#) (relative to D Major)'),
('F#', 2, 'sharp', 'F,G,A,B,C,D,E', 'F# Natural Minor - 3 sharps (F#, C#, G#) (relative to A Major)'),
('C#', 2, 'sharp', 'C,D,E,F,G,A,B', 'C# Natural Minor - 4 sharps (F#, C#, G#, D#) (relative to E Major)'),
('G#', 2, 'sharp', 'G,A,B,C,D,E,F', 'G# Natural Minor - 5 sharps (F#, C#, G#, D#, A#) (relative to B Major)'),
('D#', 2, 'sharp', 'D,E,F,G,A,B,C', 'D# Natural Minor - 6 sharps (relative to F# Major)'),
('A#', 2, 'sharp', 'A,B,C,D,E,F,G', 'A# Natural Minor - 7 sharps (relative to C# Major)'),
('D', 2, 'flat', 'D,E,F,G,A,B,C', 'D Natural Minor - 1 flat (Bb) (relative to F Major)'),
('G', 2, 'flat', 'G,A,B,C,D,E,F', 'G Natural Minor - 2 flats (Bb, Eb) (relative to Bb Major)'),
('C', 2, 'flat', 'C,D,E,F,G,A,B', 'C Natural Minor - 3 flats (Bb, Eb, Ab) (relative to Eb Major)'),
('F', 2, 'flat', 'F,G,A,B,C,D,E', 'F Natural Minor - 4 flats (Bb, Eb, Ab, Db) (relative to Ab Major)'),
('Bb', 2, 'flat', 'B,C,D,E,F,G,A', 'Bb Natural Minor - 5 flats (Bb, Eb, Ab, Db, Gb) (relative to Db Major)'),
('Eb', 2, 'flat', 'E,F,G,A,B,C,D', 'Eb Natural Minor - 6 flats (relative to Gb Major)'),
-- Harmonic Minor scales
('A', 3, 'natural', 'A,B,C,D,E,F,G', 'A Harmonic Minor'),
('E', 3, 'sharp', 'E,F,G,A,B,C,D', 'E Harmonic Minor'),
('B', 3, 'sharp', 'B,C,D,E,F,G,A', 'B Harmonic Minor'),
('F#', 3, 'sharp', 'F,G,A,B,C,D,E', 'F# Harmonic Minor'),
('C#', 3, 'sharp', 'C,D,E,F,G,A,B', 'C# Harmonic Minor'),
('G#', 3, 'sharp', 'G,A,B,C,D,E,F', 'G# Harmonic Minor'),
('D', 3, 'flat', 'D,E,F,G,A,B,C', 'D Harmonic Minor'),
('G', 3, 'flat', 'G,A,B,C,D,E,F', 'G Harmonic Minor'),
('C', 3, 'flat', 'C,D,E,F,G,A,B', 'C Harmonic Minor'),
('F', 3, 'flat', 'F,G,A,B,C,D,E', 'F Harmonic Minor'),
('Bb', 3, 'flat', 'B,C,D,E,F,G,A', 'Bb Harmonic Minor'),
('Eb', 3, 'flat', 'E,F,G,A,B,C,D', 'Eb Harmonic Minor'),
-- Melodic Minor scales
('A', 4, 'natural', 'A,B,C,D,E,F,G', 'A Melodic Minor'),
('E', 4, 'sharp', 'E,F,G,A,B,C,D', 'E Melodic Minor'),
('B', 4, 'sharp', 'B,C,D,E,F,G,A', 'B Melodic Minor'),
('D', 4, 'flat', 'D,E,F,G,A,B,C', 'D Melodic Minor'),
('G', 4, 'flat', 'G,A,B,C,D,E,F', 'G Melodic Minor'),
('C', 4, 'flat', 'C,D,E,F,G,A,B', 'C Melodic Minor'),
-- Modes
('D', 5, 'natural', 'D,E,F,G,A,B,C', 'D Dorian (C Major parent)'),
('G', 5, 'sharp', 'G,A,B,C,D,E,F', 'G Dorian (F Major parent)'),
('E', 6, 'natural', 'E,F,G,A,B,C,D', 'E Phrygian (C Major parent)'),
('A', 6, 'sharp', 'A,B,C,D,E,F,G', 'A Phrygian (F Major parent)'),
('F', 7, 'natural', 'F,G,A,B,C,D,E', 'F Lydian (C Major parent)'),
('C', 7, 'sharp', 'C,D,E,F,G,A,B', 'C Lydian (G Major parent)'),
('G', 8, 'natural', 'G,A,B,C,D,E,F', 'G Mixolydian (C Major parent)'),
('D', 8, 'sharp', 'D,E,F,G,A,B,C', 'D Mixolydian (G Major parent)'),
('B', 9, 'natural', 'B,C,D,E,F,G,A', 'B Locrian (C Major parent)'),
-- Pentatonic scales
('C', 10, 'natural', 'C,D,E,G,A', 'C Major Pentatonic'),
('G', 10, 'sharp', 'G,A,B,D,E', 'G Major Pentatonic'),
('A', 11, 'natural', 'A,C,D,E,G', 'A Minor Pentatonic'),
('C', 11, 'flat', 'C,E,F,G,B', 'C Minor Pentatonic - uses flats (Eb, Bb)'),
('E', 11, 'sharp', 'E,G,A,B,D', 'E Minor Pentatonic'),
-- Blues scales
('C', 12, 'flat', 'C,E,F,G,G,B', 'C Blues - C, Eb, F, Gb, G, Bb'),
('A', 12, 'flat', 'A,C,D,E,E,G', 'A Blues - A, C, D, Eb, E, G');
GO

-- Insert preferred accidentals for chord roots
INSERT INTO dbo.ChordKeySignatures (RootNote, PreferredAccidental, Description) VALUES
('C', 'natural', 'C - Natural notes'),
('G', 'sharp', 'G - Sharp key'),
('D', 'sharp', 'D - Sharp key'),
('A', 'sharp', 'A - Sharp key'),
('E', 'sharp', 'E - Sharp key'),
('B', 'sharp', 'B - Sharp key'),
('F#', 'sharp', 'F# - Sharp key'),
('C#', 'sharp', 'C# - Sharp key'),
('G#', 'sharp', 'G# - Sharp key'),
('D#', 'sharp', 'D# - Sharp key'),
('A#', 'sharp', 'A# - Sharp key'),
('F', 'flat', 'F - Flat key'),
('Bb', 'flat', 'Bb - Flat key'),
('Eb', 'flat', 'Eb - Flat key'),
('Ab', 'flat', 'Ab - Flat key'),
('Db', 'flat', 'Db - Flat key'),
('Gb', 'flat', 'Gb - Flat key');
GO

-- Create a view to calculate intervals between any two notes
IF OBJECT_ID('dbo.vw_NoteIntervals', 'V') IS NOT NULL
    DROP VIEW dbo.vw_NoteIntervals;
GO

CREATE VIEW dbo.vw_NoteIntervals AS
SELECT 
    n1.NoteName AS FromNote,
    n2.NoteName AS ToNote,
    ABS(n2.SemitonesFromC - n1.SemitonesFromC) AS Semitones,
    i.IntervalName,
    i.ShortName AS IntervalShortName
FROM dbo.Notes n1
CROSS JOIN dbo.Notes n2
LEFT JOIN dbo.Intervals i ON ABS(n2.SemitonesFromC - n1.SemitonesFromC) = i.Semitones
WHERE n1.IsSharp = 1 OR n1.IsNatural = 1  -- Prefer sharps and naturals for FROM note
  AND n2.IsSharp = 1 OR n2.IsNatural = 1  -- Prefer sharps and naturals for TO note
  AND ABS(n2.SemitonesFromC - n1.SemitonesFromC) <= 12;
GO

-- Create a function to generate scales
GO

-- Enhanced Scale Generation Function with Proper Note Spelling
-- Drop function regardless of type (IF = inline, TF = multi-statement)
IF OBJECT_ID('dbo.fn_GenerateScale', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GenerateScale;
IF OBJECT_ID('dbo.fn_GenerateScale', 'TF') IS NOT NULL
    DROP FUNCTION dbo.fn_GenerateScale;
GO

CREATE FUNCTION dbo.fn_GenerateScale
(
    @RootNote NVARCHAR(10),
    @ScaleTypeId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH RootInfo AS (
        SELECT 
            n.NoteName,
            n.SemitonesFromC,
            st.ScaleName,
            st.IntervalPattern,
            ks.ScaleLetterSequence,
            ks.PreferredAccidental
        FROM dbo.Notes n
        CROSS JOIN dbo.ScaleTypes st
        LEFT JOIN dbo.KeySignatures ks 
            ON ks.RootNote = n.NoteName 
            AND ks.ScaleTypeId = st.ScaleTypeId
        WHERE n.NoteName = @RootNote
          AND st.ScaleTypeId = @ScaleTypeId
    ),
    SplitIntervals AS (
        SELECT 
            ri.NoteName AS RootNote,
            ri.SemitonesFromC AS RootSemitone,
            ri.ScaleName,
            ri.ScaleLetterSequence,
            ri.PreferredAccidental,
            CAST(value AS INT) AS IntervalStep,
            ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS StepOrder
        FROM RootInfo ri
        CROSS APPLY STRING_SPLIT(ri.IntervalPattern, ',')
    ),
    IntervalSteps AS (
        SELECT 
            ri.NoteName AS RootNote,
            ri.SemitonesFromC AS RootSemitone,
            ri.ScaleName,
            ri.ScaleLetterSequence,
            ri.PreferredAccidental,
            0 AS StepNumber,
            0 AS CumulativeSemitones
        FROM RootInfo ri
        
        UNION ALL
        
        SELECT 
            si.RootNote,
            si.RootSemitone,
            si.ScaleName,
            si.ScaleLetterSequence,
            si.PreferredAccidental,
            si.StepOrder AS StepNumber,
            (SELECT SUM(IntervalStep) 
             FROM SplitIntervals si2 
             WHERE si2.StepOrder <= si.StepOrder) AS CumulativeSemitones
        FROM SplitIntervals si
    ),
    LetterSequence AS (
        -- For scales WITH key signatures
        SELECT 
            ist.*,
            TRIM(value) AS RequiredLetter,
            ROW_NUMBER() OVER (PARTITION BY ist.StepNumber ORDER BY (SELECT NULL)) AS LetterOrder
        FROM IntervalSteps ist
        CROSS APPLY STRING_SPLIT(ist.ScaleLetterSequence, ',')
        WHERE ist.ScaleLetterSequence IS NOT NULL
        
        UNION ALL
        
        -- For scales WITHOUT key signatures (fallback)
        SELECT 
            ist.*,
            NULL AS RequiredLetter,
            ist.StepNumber + 1 AS LetterOrder
        FROM IntervalSteps ist
        WHERE ist.ScaleLetterSequence IS NULL
    )
    SELECT 
        ls.StepNumber + 1 AS DegreeNumber,
        CASE 
            WHEN ls.StepNumber = 0 THEN '1 (Root)'
            WHEN ls.StepNumber = 1 THEN '2'
            WHEN ls.StepNumber = 2 THEN '3'
            WHEN ls.StepNumber = 3 THEN '4'
            WHEN ls.StepNumber = 4 THEN '5'
            WHEN ls.StepNumber = 5 THEN '6'
            WHEN ls.StepNumber = 6 THEN '7'
            WHEN ls.StepNumber = 7 THEN '8 (Octave)'
            WHEN ls.StepNumber = 8 THEN '9'
        END AS ScaleDegree,
        -- Select the correct note based on key signature and required letter
        -- Always return a note (multiple fallbacks)
        COALESCE(
            -- First, try to find the note with the correct letter from key signature (if RequiredLetter is provided)
            (SELECT TOP 1 NoteName
             FROM dbo.Notes
             WHERE SemitonesFromC = (ls.RootSemitone + ls.CumulativeSemitones) % 12
               AND ls.RequiredLetter IS NOT NULL
               AND LEFT(NoteName, 1) = ls.RequiredLetter
               AND (
                   -- Prefer the accidental type from key signature
                   (ls.PreferredAccidental = 'sharp' AND (IsSharp = 1 OR IsNatural = 1)) OR
                   (ls.PreferredAccidental = 'flat' AND (IsFlat = 1 OR IsNatural = 1)) OR
                   (ls.PreferredAccidental = 'natural' AND IsNatural = 1)
               )
             ORDER BY IsNatural DESC),
            -- Fallback: if no key signature, prefer flats if root is flat, otherwise prefer sharps
            (SELECT TOP 1 NoteName
             FROM dbo.Notes n2
             CROSS APPLY (SELECT TOP 1 IsFlat FROM dbo.Notes WHERE NoteName = ls.RootNote) AS root
             WHERE n2.SemitonesFromC = (ls.RootSemitone + ls.CumulativeSemitones) % 12
               AND (
                   (root.IsFlat = 1 AND (n2.IsFlat = 1 OR n2.IsNatural = 1)) OR
                   (root.IsFlat = 0 AND (n2.IsSharp = 1 OR n2.IsNatural = 1))
               )
             ORDER BY n2.IsNatural DESC, 
                      CASE WHEN root.IsFlat = 1 THEN n2.IsFlat ELSE n2.IsSharp END DESC),
            -- Ultimate fallback: get any note with the correct semitone (prefer flats over sharps)
            (SELECT TOP 1 NoteName
             FROM dbo.Notes
             WHERE SemitonesFromC = (ls.RootSemitone + ls.CumulativeSemitones) % 12
             ORDER BY IsNatural DESC, IsFlat DESC)
        ) AS Note,
        ls.CumulativeSemitones AS SemitonesFromRoot,
        i.IntervalName,
        i.RomanNumeral,
        ls.ScaleName
    FROM LetterSequence ls
    LEFT JOIN dbo.Intervals i ON i.Semitones = ls.CumulativeSemitones
    WHERE ls.CumulativeSemitones < 13
      AND ls.LetterOrder = ls.StepNumber + 1  -- Match letter to degree number
);
GO

-- Example queries to demonstrate usage:

-- 1. View all notes
SELECT * FROM dbo.Notes ORDER BY SemitonesFromC;

-- 2. View all intervals
SELECT * FROM dbo.Intervals ORDER BY Semitones;

-- 3. Generate C Major scale
SELECT * FROM dbo.fn_GenerateScale('C', 1);

-- 4. Generate A Natural Minor scale
SELECT * FROM dbo.fn_GenerateScale('A', 2);

-- 5. View intervals between all notes
SELECT * FROM dbo.vw_NoteIntervals WHERE FromNote = 'C' ORDER BY Semitones;

-- 6. Find all major scales
SELECT st.ScaleName, n.NoteName AS RootNote, s.*
FROM dbo.ScaleTypes st
CROSS APPLY (
    SELECT NoteName FROM dbo.Notes 
    WHERE IsSharp = 1 OR IsNatural = 1
) n
CROSS APPLY dbo.fn_GenerateScale(n.NoteName, st.ScaleTypeId) s
WHERE st.ScaleTypeId = 1
ORDER BY n.NoteName, s.DegreeNumber;
