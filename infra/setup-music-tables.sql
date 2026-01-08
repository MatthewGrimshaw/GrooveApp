-- Music Theory Database Setup
-- This script creates tables for music notes, scales, and intervals

-- Create Notes table with chromatic scale
IF OBJECT_ID('dbo.Notes', 'U') IS NOT NULL
    DROP TABLE dbo.Notes;

CREATE TABLE dbo.Notes
(
    NoteId INT PRIMARY KEY,
    NoteName NVARCHAR(10) NOT NULL,
    EnharmonicEquivalent NVARCHAR(10) NULL,
    SemitonesFromC INT NOT NULL,
    -- Number of semitones from C (for interval calculations)
    IsNatural BIT NOT NULL,
    IsSharp BIT NOT NULL,
    IsFlat BIT NOT NULL,
    CONSTRAINT UQ_Notes_NoteName UNIQUE (NoteName)
);
GO

-- Insert all chromatic notes (12 semitones)
INSERT INTO dbo.Notes
    (NoteId, NoteName, EnharmonicEquivalent, SemitonesFromC, IsNatural, IsSharp, IsFlat)
VALUES
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

CREATE TABLE dbo.Intervals
(
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
INSERT INTO dbo.Intervals
    (IntervalId, IntervalName, Semitones, ShortName, RomanNumeral, Description)
VALUES
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
IF OBJECT_ID('dbo.ScaleTypes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ScaleTypes
    (
        ScaleTypeId INT PRIMARY KEY,
        ScaleName NVARCHAR(50) NOT NULL,
        IntervalPattern NVARCHAR(50) NOT NULL,
        -- Pattern of semitones (e.g., '2,2,1,2,2,2,1' for major)
        Description NVARCHAR(200) NULL
    );
END
GO

-- Insert common scale types
IF NOT EXISTS (SELECT 1
FROM dbo.ScaleTypes
WHERE ScaleTypeId = 1)
BEGIN
    INSERT INTO dbo.ScaleTypes
        (ScaleTypeId, ScaleName, IntervalPattern, Description)
    VALUES
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
END
GO

-- Create KeySignatures table to define which accidentals to use for each scale
IF OBJECT_ID('dbo.KeySignatures', 'U') IS NOT NULL
    DROP TABLE dbo.KeySignatures;

CREATE TABLE dbo.KeySignatures
(
    KeySignatureId INT PRIMARY KEY IDENTITY(1,1),
    RootNote NVARCHAR(10) NOT NULL,
    ScaleTypeId INT NOT NULL,
    PreferredAccidental NVARCHAR(10) NOT NULL,
    -- 'sharp', 'flat', or 'natural'
    ScaleLetterSequence NVARCHAR(50) NOT NULL,
    -- e.g., 'C,D,E,F,G,A,B' for C major
    Description NVARCHAR(200) NULL,
    CONSTRAINT FK_KeySig_ScaleType FOREIGN KEY (ScaleTypeId) REFERENCES dbo.ScaleTypes(ScaleTypeId)
);
GO

-- Create ChordKeySignatures table for proper note spelling in arpeggios
IF OBJECT_ID('dbo.ChordKeySignatures', 'U') IS NOT NULL
    DROP TABLE dbo.ChordKeySignatures;

CREATE TABLE dbo.ChordKeySignatures
(
    ChordKeySignatureId INT PRIMARY KEY IDENTITY(1,1),
    RootNote NVARCHAR(10) NOT NULL,
    PreferredAccidental NVARCHAR(10) NOT NULL,
    -- 'sharp', 'flat', or 'natural'
    Description NVARCHAR(200) NULL
);
GO

-- Create Chord Types table for arpeggios
IF OBJECT_ID('dbo.ChordTypes', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChordTypes
    (
        ChordTypeId INT PRIMARY KEY,
        ChordName NVARCHAR(50) NOT NULL,
        ChordSymbol NVARCHAR(20) NOT NULL,
        IntervalPattern NVARCHAR(100) NOT NULL,
        -- Semitones from root (e.g., '0,4,7' for major triad)
        Description NVARCHAR(200) NULL
    );
END
GO

-- Insert common chord types with extensions
IF NOT EXISTS (SELECT 1
FROM dbo.ChordTypes
WHERE ChordTypeId = 1)
BEGIN
    INSERT INTO dbo.ChordTypes
        (ChordTypeId, ChordName, ChordSymbol, IntervalPattern, Description)
    VALUES
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
END
GO

-- Chord Extensions table for Jazz extensions
IF OBJECT_ID('dbo.ChordExtensions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ChordExtensions
    (
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
END
GO

-- Insert common Jazz chord extensions
IF NOT EXISTS (SELECT 1
FROM dbo.ChordExtensions
WHERE ChordTypeId = 5 AND ExtensionSymbol = '9')
BEGIN
    INSERT INTO dbo.ChordExtensions
        (ChordTypeId, ExtensionName, ExtensionSymbol, Semitones, Description, IsCommonInJazz, DisplayOrder)
    VALUES
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
END
GO

-- ============================================================================
-- Circle of Fifths Tables and Views
-- ============================================================================
-- Create DiatonicChordProgressions table for Circle of Fifths feature
IF OBJECT_ID('dbo.DiatonicChordProgressions', 'U') IS NOT NULL
    DROP TABLE dbo.DiatonicChordProgressions;

CREATE TABLE dbo.DiatonicChordProgressions
(
    ProgressionId INT PRIMARY KEY IDENTITY(1,1),
    KeyNote NVARCHAR(10) NOT NULL,
    ScaleTypeId INT NOT NULL,
    DegreeNumber INT NOT NULL,
    DegreeRomanNumeral NVARCHAR(10) NOT NULL,
    ChordRoot NVARCHAR(10) NOT NULL,
    ChordQuality NVARCHAR(20) NOT NULL,
    ChordSymbol NVARCHAR(20) NOT NULL,
    IntervalFromTonic INT NOT NULL,
    Description NVARCHAR(200) NULL,
    CONSTRAINT FK_DiatonicChord_ScaleType FOREIGN KEY (ScaleTypeId) REFERENCES ScaleTypes(ScaleTypeId)
);
GO

-- Insert Major Key Chord Progressions (I, ii, iii, IV, V, vi, vii°)
-- C Major
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('C', 1, 1, 'I', 'C', 'Major', 'C', 0, 'Tonic - Home chord'),
    ('C', 1, 2, 'ii', 'D', 'Minor', 'Dm', 2, 'Supertonic - Pre-dominant'),
    ('C', 1, 3, 'iii', 'E', 'Minor', 'Em', 4, 'Mediant - Tonic substitute'),
    ('C', 1, 4, 'IV', 'F', 'Major', 'F', 5, 'Subdominant - Pre-dominant'),
    ('C', 1, 5, 'V', 'G', 'Major', 'G', 7, 'Dominant - Tension and resolution'),
    ('C', 1, 6, 'vi', 'A', 'Minor', 'Am', 9, 'Submediant - Tonic substitute'),
    ('C', 1, 7, 'vii°', 'B', 'Diminished', 'B°', 11, 'Leading tone - Dominant function');
GO

-- G Major (1 sharp: F#)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('G', 1, 1, 'I', 'G', 'Major', 'G', 0, 'Tonic - Home chord'),
    ('G', 1, 2, 'ii', 'A', 'Minor', 'Am', 2, 'Supertonic - Pre-dominant'),
    ('G', 1, 3, 'iii', 'B', 'Minor', 'Bm', 4, 'Mediant - Tonic substitute'),
    ('G', 1, 4, 'IV', 'C', 'Major', 'C', 5, 'Subdominant - Pre-dominant'),
    ('G', 1, 5, 'V', 'D', 'Major', 'D', 7, 'Dominant - Tension and resolution'),
    ('G', 1, 6, 'vi', 'E', 'Minor', 'Em', 9, 'Submediant - Tonic substitute'),
    ('G', 1, 7, 'vii°', 'F#', 'Diminished', 'F#°', 11, 'Leading tone - Dominant function');
GO

-- D Major (2 sharps: F#, C#)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('D', 1, 1, 'I', 'D', 'Major', 'D', 0, 'Tonic - Home chord'),
    ('D', 1, 2, 'ii', 'E', 'Minor', 'Em', 2, 'Supertonic - Pre-dominant'),
    ('D', 1, 3, 'iii', 'F#', 'Minor', 'F#m', 4, 'Mediant - Tonic substitute'),
    ('D', 1, 4, 'IV', 'G', 'Major', 'G', 5, 'Subdominant - Pre-dominant'),
    ('D', 1, 5, 'V', 'A', 'Major', 'A', 7, 'Dominant - Tension and resolution'),
    ('D', 1, 6, 'vi', 'B', 'Minor', 'Bm', 9, 'Submediant - Tonic substitute'),
    ('D', 1, 7, 'vii°', 'C#', 'Diminished', 'C#°', 11, 'Leading tone - Dominant function');
GO

-- A Major (3 sharps: F#, C#, G#)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('A', 1, 1, 'I', 'A', 'Major', 'A', 0, 'Tonic - Home chord'),
    ('A', 1, 2, 'ii', 'B', 'Minor', 'Bm', 2, 'Supertonic - Pre-dominant'),
    ('A', 1, 3, 'iii', 'C#', 'Minor', 'C#m', 4, 'Mediant - Tonic substitute'),
    ('A', 1, 4, 'IV', 'D', 'Major', 'D', 5, 'Subdominant - Pre-dominant'),
    ('A', 1, 5, 'V', 'E', 'Major', 'E', 7, 'Dominant - Tension and resolution'),
    ('A', 1, 6, 'vi', 'F#', 'Minor', 'F#m', 9, 'Submediant - Tonic substitute'),
    ('A', 1, 7, 'vii°', 'G#', 'Diminished', 'G#°', 11, 'Leading tone - Dominant function');
GO

-- E Major (4 sharps: F#, C#, G#, D#)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('E', 1, 1, 'I', 'E', 'Major', 'E', 0, 'Tonic - Home chord'),
    ('E', 1, 2, 'ii', 'F#', 'Minor', 'F#m', 2, 'Supertonic - Pre-dominant'),
    ('E', 1, 3, 'iii', 'G#', 'Minor', 'G#m', 4, 'Mediant - Tonic substitute'),
    ('E', 1, 4, 'IV', 'A', 'Major', 'A', 5, 'Subdominant - Pre-dominant'),
    ('E', 1, 5, 'V', 'B', 'Major', 'B', 7, 'Dominant - Tension and resolution'),
    ('E', 1, 6, 'vi', 'C#', 'Minor', 'C#m', 9, 'Submediant - Tonic substitute'),
    ('E', 1, 7, 'vii°', 'D#', 'Diminished', 'D#°', 11, 'Leading tone - Dominant function');
GO

-- B Major (5 sharps: F#, C#, G#, D#, A#)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('B', 1, 1, 'I', 'B', 'Major', 'B', 0, 'Tonic - Home chord'),
    ('B', 1, 2, 'ii', 'C#', 'Minor', 'C#m', 2, 'Supertonic - Pre-dominant'),
    ('B', 1, 3, 'iii', 'D#', 'Minor', 'D#m', 4, 'Mediant - Tonic substitute'),
    ('B', 1, 4, 'IV', 'E', 'Major', 'E', 5, 'Subdominant - Pre-dominant'),
    ('B', 1, 5, 'V', 'F#', 'Major', 'F#', 7, 'Dominant - Tension and resolution'),
    ('B', 1, 6, 'vi', 'G#', 'Minor', 'G#m', 9, 'Submediant - Tonic substitute'),
    ('B', 1, 7, 'vii°', 'A#', 'Diminished', 'A#°', 11, 'Leading tone - Dominant function');
GO

-- F# Major (6 sharps: F#, C#, G#, D#, A#, E#)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('F#', 1, 1, 'I', 'F#', 'Major', 'F#', 0, 'Tonic - Home chord'),
    ('F#', 1, 2, 'ii', 'G#', 'Minor', 'G#m', 2, 'Supertonic - Pre-dominant'),
    ('F#', 1, 3, 'iii', 'A#', 'Minor', 'A#m', 4, 'Mediant - Tonic substitute'),
    ('F#', 1, 4, 'IV', 'B', 'Major', 'B', 5, 'Subdominant - Pre-dominant'),
    ('F#', 1, 5, 'V', 'C#', 'Major', 'C#', 7, 'Dominant - Tension and resolution'),
    ('F#', 1, 6, 'vi', 'D#', 'Minor', 'D#m', 9, 'Submediant - Tonic substitute'),
    ('F#', 1, 7, 'vii°', 'E#', 'Diminished', 'E#°', 11, 'Leading tone - Dominant function');
GO

-- F Major (1 flat: Bb)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('F', 1, 1, 'I', 'F', 'Major', 'F', 0, 'Tonic - Home chord'),
    ('F', 1, 2, 'ii', 'G', 'Minor', 'Gm', 2, 'Supertonic - Pre-dominant'),
    ('F', 1, 3, 'iii', 'A', 'Minor', 'Am', 4, 'Mediant - Tonic substitute'),
    ('F', 1, 4, 'IV', 'Bb', 'Major', 'Bb', 5, 'Subdominant - Pre-dominant'),
    ('F', 1, 5, 'V', 'C', 'Major', 'C', 7, 'Dominant - Tension and resolution'),
    ('F', 1, 6, 'vi', 'D', 'Minor', 'Dm', 9, 'Submediant - Tonic substitute'),
    ('F', 1, 7, 'vii°', 'E', 'Diminished', 'E°', 11, 'Leading tone - Dominant function');
GO

-- Bb Major (2 flats: Bb, Eb)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Bb', 1, 1, 'I', 'Bb', 'Major', 'Bb', 0, 'Tonic - Home chord'),
    ('Bb', 1, 2, 'ii', 'C', 'Minor', 'Cm', 2, 'Supertonic - Pre-dominant'),
    ('Bb', 1, 3, 'iii', 'D', 'Minor', 'Dm', 4, 'Mediant - Tonic substitute'),
    ('Bb', 1, 4, 'IV', 'Eb', 'Major', 'Eb', 5, 'Subdominant - Pre-dominant'),
    ('Bb', 1, 5, 'V', 'F', 'Major', 'F', 7, 'Dominant - Tension and resolution'),
    ('Bb', 1, 6, 'vi', 'G', 'Minor', 'Gm', 9, 'Submediant - Tonic substitute'),
    ('Bb', 1, 7, 'vii°', 'A', 'Diminished', 'A°', 11, 'Leading tone - Dominant function');
GO

-- Eb Major (3 flats: Bb, Eb, Ab)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Eb', 1, 1, 'I', 'Eb', 'Major', 'Eb', 0, 'Tonic - Home chord'),
    ('Eb', 1, 2, 'ii', 'F', 'Minor', 'Fm', 2, 'Supertonic - Pre-dominant'),
    ('Eb', 1, 3, 'iii', 'G', 'Minor', 'Gm', 4, 'Mediant - Tonic substitute'),
    ('Eb', 1, 4, 'IV', 'Ab', 'Major', 'Ab', 5, 'Subdominant - Pre-dominant'),
    ('Eb', 1, 5, 'V', 'Bb', 'Major', 'Bb', 7, 'Dominant - Tension and resolution'),
    ('Eb', 1, 6, 'vi', 'C', 'Minor', 'Cm', 9, 'Submediant - Tonic substitute'),
    ('Eb', 1, 7, 'vii°', 'D', 'Diminished', 'D°', 11, 'Leading tone - Dominant function');
GO

-- Ab Major (4 flats: Bb, Eb, Ab, Db)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Ab', 1, 1, 'I', 'Ab', 'Major', 'Ab', 0, 'Tonic - Home chord'),
    ('Ab', 1, 2, 'ii', 'Bb', 'Minor', 'Bbm', 2, 'Supertonic - Pre-dominant'),
    ('Ab', 1, 3, 'iii', 'C', 'Minor', 'Cm', 4, 'Mediant - Tonic substitute'),
    ('Ab', 1, 4, 'IV', 'Db', 'Major', 'Db', 5, 'Subdominant - Pre-dominant'),
    ('Ab', 1, 5, 'V', 'Eb', 'Major', 'Eb', 7, 'Dominant - Tension and resolution'),
    ('Ab', 1, 6, 'vi', 'F', 'Minor', 'Fm', 9, 'Submediant - Tonic substitute'),
    ('Ab', 1, 7, 'vii°', 'G', 'Diminished', 'G°', 11, 'Leading tone - Dominant function');
GO

-- Db Major (5 flats: Bb, Eb, Ab, Db, Gb)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Db', 1, 1, 'I', 'Db', 'Major', 'Db', 0, 'Tonic - Home chord'),
    ('Db', 1, 2, 'ii', 'Eb', 'Minor', 'Ebm', 2, 'Supertonic - Pre-dominant'),
    ('Db', 1, 3, 'iii', 'F', 'Minor', 'Fm', 4, 'Mediant - Tonic substitute'),
    ('Db', 1, 4, 'IV', 'Gb', 'Major', 'Gb', 5, 'Subdominant - Pre-dominant'),
    ('Db', 1, 5, 'V', 'Ab', 'Major', 'Ab', 7, 'Dominant - Tension and resolution'),
    ('Db', 1, 6, 'vi', 'Bb', 'Minor', 'Bbm', 9, 'Submediant - Tonic substitute'),
    ('Db', 1, 7, 'vii°', 'C', 'Diminished', 'C°', 11, 'Leading tone - Dominant function');
GO

-- Gb Major (6 flats: Bb, Eb, Ab, Db, Gb, Cb)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Gb', 1, 1, 'I', 'Gb', 'Major', 'Gb', 0, 'Tonic - Home chord'),
    ('Gb', 1, 2, 'ii', 'Ab', 'Minor', 'Abm', 2, 'Supertonic - Pre-dominant'),
    ('Gb', 1, 3, 'iii', 'Bb', 'Minor', 'Bbm', 4, 'Mediant - Tonic substitute'),
    ('Gb', 1, 4, 'IV', 'Cb', 'Major', 'Cb', 5, 'Subdominant - Pre-dominant'),
    ('Gb', 1, 5, 'V', 'Db', 'Major', 'Db', 7, 'Dominant - Tension and resolution'),
    ('Gb', 1, 6, 'vi', 'Eb', 'Minor', 'Ebm', 9, 'Submediant - Tonic substitute'),
    ('Gb', 1, 7, 'vii°', 'F', 'Diminished', 'F°', 11, 'Leading tone - Dominant function');
GO

-- Insert Minor Key Chord Progressions (i, ii°, III, iv, v, VI, VII)
-- A Minor (natural minor, relative to C Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('A', 2, 1, 'i', 'A', 'Minor', 'Am', 0, 'Tonic - Home chord'),
    ('A', 2, 2, 'ii°', 'B', 'Diminished', 'B°', 2, 'Supertonic - Diminished'),
    ('A', 2, 3, 'III', 'C', 'Major', 'C', 3, 'Mediant - Relative major'),
    ('A', 2, 4, 'iv', 'D', 'Minor', 'Dm', 5, 'Subdominant - Pre-dominant'),
    ('A', 2, 5, 'v', 'E', 'Minor', 'Em', 7, 'Dominant - Weaker resolution'),
    ('A', 2, 6, 'VI', 'F', 'Major', 'F', 8, 'Submediant - Strong consonance'),
    ('A', 2, 7, 'VII', 'G', 'Major', 'G', 10, 'Subtonic - Modal flavor');

-- E Minor (1 sharp: F#, relative to G Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('E', 2, 1, 'i', 'E', 'Minor', 'Em', 0, 'Tonic - Home chord'),
    ('E', 2, 2, 'ii°', 'F#', 'Diminished', 'F#°', 2, 'Supertonic - Diminished'),
    ('E', 2, 3, 'III', 'G', 'Major', 'G', 3, 'Mediant - Relative major'),
    ('E', 2, 4, 'iv', 'A', 'Minor', 'Am', 5, 'Subdominant - Pre-dominant'),
    ('E', 2, 5, 'v', 'B', 'Minor', 'Bm', 7, 'Dominant - Weaker resolution'),
    ('E', 2, 6, 'VI', 'C', 'Major', 'C', 8, 'Submediant - Strong consonance'),
    ('E', 2, 7, 'VII', 'D', 'Major', 'D', 10, 'Subtonic - Modal flavor');

-- D Minor (1 flat: Bb, relative to F Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('D', 2, 1, 'i', 'D', 'Minor', 'Dm', 0, 'Tonic - Home chord'),
    ('D', 2, 2, 'ii°', 'E', 'Diminished', 'E°', 2, 'Supertonic - Diminished'),
    ('D', 2, 3, 'III', 'F', 'Major', 'F', 3, 'Mediant - Relative major'),
    ('D', 2, 4, 'iv', 'G', 'Minor', 'Gm', 5, 'Subdominant - Pre-dominant'),
    ('D', 2, 5, 'v', 'A', 'Minor', 'Am', 7, 'Dominant - Weaker resolution'),
    ('D', 2, 6, 'VI', 'Bb', 'Major', 'Bb', 8, 'Submediant - Strong consonance'),
    ('D', 2, 7, 'VII', 'C', 'Major', 'C', 10, 'Subtonic - Modal flavor');
GO

-- B Minor (2 sharps: F#, C#, relative to D Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('B', 2, 1, 'i', 'B', 'Minor', 'Bm', 0, 'Tonic - Home chord'),
    ('B', 2, 2, 'ii°', 'C#', 'Diminished', 'C#°', 2, 'Supertonic - Diminished'),
    ('B', 2, 3, 'III', 'D', 'Major', 'D', 3, 'Mediant - Relative major'),
    ('B', 2, 4, 'iv', 'E', 'Minor', 'Em', 5, 'Subdominant - Pre-dominant'),
    ('B', 2, 5, 'v', 'F#', 'Minor', 'F#m', 7, 'Dominant - Weaker resolution'),
    ('B', 2, 6, 'VI', 'G', 'Major', 'G', 8, 'Submediant - Strong consonance'),
    ('B', 2, 7, 'VII', 'A', 'Major', 'A', 10, 'Subtonic - Modal flavor');
GO

-- F# Minor (3 sharps: F#, C#, G#, relative to A Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('F#', 2, 1, 'i', 'F#', 'Minor', 'F#m', 0, 'Tonic - Home chord'),
    ('F#', 2, 2, 'ii°', 'G#', 'Diminished', 'G#°', 2, 'Supertonic - Diminished'),
    ('F#', 2, 3, 'III', 'A', 'Major', 'A', 3, 'Mediant - Relative major'),
    ('F#', 2, 4, 'iv', 'B', 'Minor', 'Bm', 5, 'Subdominant - Pre-dominant'),
    ('F#', 2, 5, 'v', 'C#', 'Minor', 'C#m', 7, 'Dominant - Weaker resolution'),
    ('F#', 2, 6, 'VI', 'D', 'Major', 'D', 8, 'Submediant - Strong consonance'),
    ('F#', 2, 7, 'VII', 'E', 'Major', 'E', 10, 'Subtonic - Modal flavor');
GO

-- C# Minor (4 sharps: F#, C#, G#, D#, relative to E Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('C#', 2, 1, 'i', 'C#', 'Minor', 'C#m', 0, 'Tonic - Home chord'),
    ('C#', 2, 2, 'ii°', 'D#', 'Diminished', 'D#°', 2, 'Supertonic - Diminished'),
    ('C#', 2, 3, 'III', 'E', 'Major', 'E', 3, 'Mediant - Relative major'),
    ('C#', 2, 4, 'iv', 'F#', 'Minor', 'F#m', 5, 'Subdominant - Pre-dominant'),
    ('C#', 2, 5, 'v', 'G#', 'Minor', 'G#m', 7, 'Dominant - Weaker resolution'),
    ('C#', 2, 6, 'VI', 'A', 'Major', 'A', 8, 'Submediant - Strong consonance'),
    ('C#', 2, 7, 'VII', 'B', 'Major', 'B', 10, 'Subtonic - Modal flavor');
GO

-- G# Minor (5 sharps: F#, C#, G#, D#, A#, relative to B Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('G#', 2, 1, 'i', 'G#', 'Minor', 'G#m', 0, 'Tonic - Home chord'),
    ('G#', 2, 2, 'ii°', 'A#', 'Diminished', 'A#°', 2, 'Supertonic - Diminished'),
    ('G#', 2, 3, 'III', 'B', 'Major', 'B', 3, 'Mediant - Relative major'),
    ('G#', 2, 4, 'iv', 'C#', 'Minor', 'C#m', 5, 'Subdominant - Pre-dominant'),
    ('G#', 2, 5, 'v', 'D#', 'Minor', 'D#m', 7, 'Dominant - Weaker resolution'),
    ('G#', 2, 6, 'VI', 'E', 'Major', 'E', 8, 'Submediant - Strong consonance'),
    ('G#', 2, 7, 'VII', 'F#', 'Major', 'F#', 10, 'Subtonic - Modal flavor');
GO

-- D# Minor (6 sharps: F#, C#, G#, D#, A#, E#, relative to F# Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('D#', 2, 1, 'i', 'D#', 'Minor', 'D#m', 0, 'Tonic - Home chord'),
    ('D#', 2, 2, 'ii°', 'E#', 'Diminished', 'E#°', 2, 'Supertonic - Diminished'),
    ('D#', 2, 3, 'III', 'F#', 'Major', 'F#', 3, 'Mediant - Relative major'),
    ('D#', 2, 4, 'iv', 'G#', 'Minor', 'G#m', 5, 'Subdominant - Pre-dominant'),
    ('D#', 2, 5, 'v', 'A#', 'Minor', 'A#m', 7, 'Dominant - Weaker resolution'),
    ('D#', 2, 6, 'VI', 'B', 'Major', 'B', 8, 'Submediant - Strong consonance'),
    ('D#', 2, 7, 'VII', 'C#', 'Major', 'C#', 10, 'Subtonic - Modal flavor');
GO

-- A# Minor (7 sharps: all sharp, relative to C# Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('A#', 2, 1, 'i', 'A#', 'Minor', 'A#m', 0, 'Tonic - Home chord'),
    ('A#', 2, 2, 'ii°', 'B#', 'Diminished', 'B#°', 2, 'Supertonic - Diminished'),
    ('A#', 2, 3, 'III', 'C#', 'Major', 'C#', 3, 'Mediant - Relative major'),
    ('A#', 2, 4, 'iv', 'D#', 'Minor', 'D#m', 5, 'Subdominant - Pre-dominant'),
    ('A#', 2, 5, 'v', 'E#', 'Minor', 'E#m', 7, 'Dominant - Weaker resolution'),
    ('A#', 2, 6, 'VI', 'F#', 'Major', 'F#', 8, 'Submediant - Strong consonance'),
    ('A#', 2, 7, 'VII', 'G#', 'Major', 'G#', 10, 'Subtonic - Modal flavor');
GO

-- G Minor (2 flats: Bb, Eb, relative to Bb Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('G', 2, 1, 'i', 'G', 'Minor', 'Gm', 0, 'Tonic - Home chord'),
    ('G', 2, 2, 'ii°', 'A', 'Diminished', 'A°', 2, 'Supertonic - Diminished'),
    ('G', 2, 3, 'III', 'Bb', 'Major', 'Bb', 3, 'Mediant - Relative major'),
    ('G', 2, 4, 'iv', 'C', 'Minor', 'Cm', 5, 'Subdominant - Pre-dominant'),
    ('G', 2, 5, 'v', 'D', 'Minor', 'Dm', 7, 'Dominant - Weaker resolution'),
    ('G', 2, 6, 'VI', 'Eb', 'Major', 'Eb', 8, 'Submediant - Strong consonance'),
    ('G', 2, 7, 'VII', 'F', 'Major', 'F', 10, 'Subtonic - Modal flavor');
GO

-- C Minor (3 flats: Bb, Eb, Ab, relative to Eb Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('C', 2, 1, 'i', 'C', 'Minor', 'Cm', 0, 'Tonic - Home chord'),
    ('C', 2, 2, 'ii°', 'D', 'Diminished', 'D°', 2, 'Supertonic - Diminished'),
    ('C', 2, 3, 'III', 'Eb', 'Major', 'Eb', 3, 'Mediant - Relative major'),
    ('C', 2, 4, 'iv', 'F', 'Minor', 'Fm', 5, 'Subdominant - Pre-dominant'),
    ('C', 2, 5, 'v', 'G', 'Minor', 'Gm', 7, 'Dominant - Weaker resolution'),
    ('C', 2, 6, 'VI', 'Ab', 'Major', 'Ab', 8, 'Submediant - Strong consonance'),
    ('C', 2, 7, 'VII', 'Bb', 'Major', 'Bb', 10, 'Subtonic - Modal flavor');
GO

-- F Minor (4 flats: Bb, Eb, Ab, Db, relative to Ab Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('F', 2, 1, 'i', 'F', 'Minor', 'Fm', 0, 'Tonic - Home chord'),
    ('F', 2, 2, 'ii°', 'G', 'Diminished', 'G°', 2, 'Supertonic - Diminished'),
    ('F', 2, 3, 'III', 'Ab', 'Major', 'Ab', 3, 'Mediant - Relative major'),
    ('F', 2, 4, 'iv', 'Bb', 'Minor', 'Bbm', 5, 'Subdominant - Pre-dominant'),
    ('F', 2, 5, 'v', 'C', 'Minor', 'Cm', 7, 'Dominant - Weaker resolution'),
    ('F', 2, 6, 'VI', 'Db', 'Major', 'Db', 8, 'Submediant - Strong consonance'),
    ('F', 2, 7, 'VII', 'Eb', 'Major', 'Eb', 10, 'Subtonic - Modal flavor');
GO

-- Bb Minor (5 flats: Bb, Eb, Ab, Db, Gb, relative to Db Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Bb', 2, 1, 'i', 'Bb', 'Minor', 'Bbm', 0, 'Tonic - Home chord'),
    ('Bb', 2, 2, 'ii°', 'C', 'Diminished', 'C°', 2, 'Supertonic - Diminished'),
    ('Bb', 2, 3, 'III', 'Db', 'Major', 'Db', 3, 'Mediant - Relative major'),
    ('Bb', 2, 4, 'iv', 'Eb', 'Minor', 'Ebm', 5, 'Subdominant - Pre-dominant'),
    ('Bb', 2, 5, 'v', 'F', 'Minor', 'Fm', 7, 'Dominant - Weaker resolution'),
    ('Bb', 2, 6, 'VI', 'Gb', 'Major', 'Gb', 8, 'Submediant - Strong consonance'),
    ('Bb', 2, 7, 'VII', 'Ab', 'Major', 'Ab', 10, 'Subtonic - Modal flavor');
GO

-- Eb Minor (6 flats: Bb, Eb, Ab, Db, Gb, Cb, relative to Gb Major)
INSERT INTO dbo.DiatonicChordProgressions
    (KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral, ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description)
VALUES
    ('Eb', 2, 1, 'i', 'Eb', 'Minor', 'Ebm', 0, 'Tonic - Home chord'),
    ('Eb', 2, 2, 'ii°', 'F', 'Diminished', 'F°', 2, 'Supertonic - Diminished'),
    ('Eb', 2, 3, 'III', 'Gb', 'Major', 'Gb', 3, 'Mediant - Relative major'),
    ('Eb', 2, 4, 'iv', 'Ab', 'Minor', 'Abm', 5, 'Subdominant - Pre-dominant'),
    ('Eb', 2, 5, 'v', 'Bb', 'Minor', 'Bbm', 7, 'Dominant - Weaker resolution'),
    ('Eb', 2, 6, 'VI', 'Cb', 'Major', 'Cb', 8, 'Submediant - Strong consonance'),
    ('Eb', 2, 7, 'VII', 'Db', 'Major', 'Db', 10, 'Subtonic - Modal flavor');
GO

-- Create indexes for performance (early batch - also created later with full definitions)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_DiatonicChord_KeyNote' AND object_id = OBJECT_ID('dbo.DiatonicChordProgressions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DiatonicChord_KeyNote 
    ON dbo.DiatonicChordProgressions(KeyNote, ScaleTypeId);
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_DiatonicChord_ScaleTypeId' AND object_id = OBJECT_ID('dbo.DiatonicChordProgressions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DiatonicChord_ScaleTypeId 
    ON dbo.DiatonicChordProgressions(ScaleTypeId);
END
GO

-- Update statistics
UPDATE STATISTICS dbo.DiatonicChordProgressions;
GO

-- Create vw_CircleOfFifthsKeys view
IF OBJECT_ID('dbo.vw_CircleOfFifthsKeys', 'V') IS NOT NULL
    DROP VIEW dbo.vw_CircleOfFifthsKeys;
GO

CREATE VIEW dbo.vw_CircleOfFifthsKeys
AS
    SELECT
        ks.KeySignatureId,
        ks.RootNote,
        ks.ScaleTypeId,
        st.ScaleName,
        ks.PreferredAccidental,
        ks.Description,
        -- Calculate sharp/flat count from description
        CASE 
        WHEN ks.Description LIKE '%1 sharp%' THEN 1
        WHEN ks.Description LIKE '%2 sharp%' THEN 2
        WHEN ks.Description LIKE '%3 sharp%' THEN 3
        WHEN ks.Description LIKE '%4 sharp%' THEN 4
        WHEN ks.Description LIKE '%5 sharp%' THEN 5
        WHEN ks.Description LIKE '%6 sharp%' THEN 6
        WHEN ks.Description LIKE '%1 flat%' THEN 1
        WHEN ks.Description LIKE '%2 flat%' THEN 2
        WHEN ks.Description LIKE '%3 flat%' THEN 3
        WHEN ks.Description LIKE '%4 flat%' THEN 4
        WHEN ks.Description LIKE '%5 flat%' THEN 5
        WHEN ks.Description LIKE '%6 flat%' THEN 6
        ELSE 0
    END AS AccidentalCount,
        CASE 
        WHEN ks.PreferredAccidental = 'sharp' THEN 'Sharps'
        WHEN ks.PreferredAccidental = 'flat' THEN 'Flats'
        ELSE 'Natural'
    END AS AccidentalType,
        -- Position in Circle of Fifths (0-11, where C=0)
        CASE ks.RootNote
        WHEN 'C' THEN 0
        WHEN 'G' THEN 1
        WHEN 'D' THEN 2
        WHEN 'A' THEN 3
        WHEN 'E' THEN 4
        WHEN 'B' THEN 5
        WHEN 'F#' THEN 6
        WHEN 'C#' THEN 7
        WHEN 'G#' THEN 8
        WHEN 'D#' THEN 9
        WHEN 'A#' THEN 10
        WHEN 'Gb' THEN 6
        WHEN 'Db' THEN 7
        WHEN 'Ab' THEN 8
        WHEN 'Eb' THEN 9
        WHEN 'Bb' THEN 10
        WHEN 'F' THEN 11
        ELSE 0
    END AS CirclePosition,
        -- Relative major/minor
        CASE 
        WHEN ks.ScaleTypeId = 1 THEN  -- Major key, find relative minor
            CASE ks.RootNote
                WHEN 'C' THEN 'A'
                WHEN 'G' THEN 'E'
                WHEN 'D' THEN 'B'
                WHEN 'A' THEN 'F#'
                WHEN 'E' THEN 'C#'
                WHEN 'B' THEN 'G#'
                WHEN 'F#' THEN 'D#'
                WHEN 'Gb' THEN 'Eb'
                WHEN 'Db' THEN 'Bb'
                WHEN 'Ab' THEN 'F'
                WHEN 'Eb' THEN 'C'
                WHEN 'Bb' THEN 'G'
                WHEN 'F' THEN 'D'
                ELSE NULL
            END
        WHEN ks.ScaleTypeId = 2 THEN  -- Minor key, find relative major
            CASE ks.RootNote
                WHEN 'A' THEN 'C'
                WHEN 'E' THEN 'G'
                WHEN 'B' THEN 'D'
                WHEN 'F#' THEN 'A'
                WHEN 'C#' THEN 'E'
                WHEN 'G#' THEN 'B'
                WHEN 'D#' THEN 'F#'
                WHEN 'Eb' THEN 'Gb'
                WHEN 'Bb' THEN 'Db'
                WHEN 'F' THEN 'Ab'
                WHEN 'C' THEN 'Eb'
                WHEN 'G' THEN 'Bb'
                WHEN 'D' THEN 'F'
                ELSE NULL
            END
        ELSE NULL
    END AS RelativeKey
    FROM KeySignatures ks
        INNER JOIN ScaleTypes st ON ks.ScaleTypeId = st.ScaleTypeId
    WHERE ks.ScaleTypeId IN (1, 2);  -- Major and Natural Minor only
GO

-- ============================================================================
-- End Circle of Fifths Tables and Views
-- ============================================================================

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
    WITH
    ChordInfo
    AS
    (
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
    SplitSemitones
    AS
    (
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
INSERT INTO dbo.KeySignatures
    (RootNote, ScaleTypeId, PreferredAccidental, ScaleLetterSequence, Description)
VALUES
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
INSERT INTO dbo.ChordKeySignatures
    (RootNote, PreferredAccidental, Description)
VALUES
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

CREATE VIEW dbo.vw_NoteIntervals
AS
    SELECT
        n1.NoteName AS FromNote,
        n2.NoteName AS ToNote,
        ABS(n2.SemitonesFromC - n1.SemitonesFromC) AS Semitones,
        i.IntervalName,
        i.ShortName AS IntervalShortName
    FROM dbo.Notes n1
CROSS JOIN dbo.Notes n2
        LEFT JOIN dbo.Intervals i ON ABS(n2.SemitonesFromC - n1.SemitonesFromC) = i.Semitones
    WHERE n1.IsSharp = 1 OR n1.IsNatural = 1 -- Prefer sharps and naturals for FROM note
        AND n2.IsSharp = 1 OR n2.IsNatural = 1 -- Prefer sharps and naturals for TO note
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
    WITH
    RootInfo
    AS
    (
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
    SplitIntervals
    AS
    (
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
    IntervalSteps
    AS
    (
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
    LetterSequence
    AS
    (
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
            WHEN ls.StepNumber = 9 THEN '10'
            WHEN ls.StepNumber = 10 THEN '11'
            WHEN ls.StepNumber = 11 THEN '12'
            ELSE CAST(ls.StepNumber + 1 AS NVARCHAR(10))
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
SELECT *
FROM dbo.Notes
ORDER BY SemitonesFromC;

-- 2. View all intervals
SELECT *
FROM dbo.Intervals
ORDER BY Semitones;

-- 3. Generate C Major scale
SELECT *
FROM dbo.fn_GenerateScale('C', 1);

-- 4. Generate A Natural Minor scale
SELECT *
FROM dbo.fn_GenerateScale('A', 2);

-- 5. View intervals between all notes
SELECT *
FROM dbo.vw_NoteIntervals
WHERE FromNote = 'C'
ORDER BY Semitones;

-- 6. Find all major scales
SELECT st.ScaleName, n.NoteName AS RootNote, s.*
FROM dbo.ScaleTypes st
CROSS APPLY (
    SELECT NoteName
    FROM dbo.Notes
    WHERE IsSharp = 1 OR IsNatural = 1
) n
CROSS APPLY dbo.fn_GenerateScale(n.NoteName, st.ScaleTypeId) s
WHERE st.ScaleTypeId = 1
ORDER BY n.NoteName, s.DegreeNumber;

-- ====================================
-- Circle of Fifths Support Tables
-- ====================================
-- DiatonicChordProgressions table and data already created above
-- Duplicate INSERT section removed to prevent double-insertion


-- ====================================
-- Performance Optimization & Indexes
-- ====================================

-- Indexes for Notes table (frequently queried by name and semitones)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_Notes_SemitonesFromC' AND object_id = OBJECT_ID('dbo.Notes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notes_SemitonesFromC 
        ON dbo.Notes(SemitonesFromC)
        INCLUDE (NoteName, EnharmonicEquivalent);
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_Notes_NoteName' AND object_id = OBJECT_ID('dbo.Notes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notes_NoteName 
        ON dbo.Notes(NoteName)
        INCLUDE (SemitonesFromC, EnharmonicEquivalent);
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_Notes_EnharmonicEquivalent' AND object_id = OBJECT_ID('dbo.Notes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notes_EnharmonicEquivalent 
        ON dbo.Notes(EnharmonicEquivalent)
        WHERE EnharmonicEquivalent IS NOT NULL;
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_Notes_Flags' AND object_id = OBJECT_ID('dbo.Notes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Notes_Flags 
        ON dbo.Notes(IsNatural, IsSharp, IsFlat)
        INCLUDE (NoteName, SemitonesFromC);
END
GO

-- Indexes for Intervals table (queried by semitones)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_Intervals_Semitones' AND object_id = OBJECT_ID('dbo.Intervals'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Intervals_Semitones 
    ON dbo.Intervals(Semitones)
    INCLUDE (IntervalName, ShortName, RomanNumeral);
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_Intervals_ShortName' AND object_id = OBJECT_ID('dbo.Intervals'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_Intervals_ShortName 
        ON dbo.Intervals(ShortName)
        INCLUDE (Semitones, IntervalName);
END
GO

-- Indexes for ScaleTypes table (queried by name)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_ScaleTypes_ScaleName' AND object_id = OBJECT_ID('dbo.ScaleTypes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ScaleTypes_ScaleName 
        ON dbo.ScaleTypes(ScaleName)
        INCLUDE (IntervalPattern, Description);
END
GO

-- Indexes for KeySignatures table (frequently joined with ScaleTypes)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_KeySignatures_ScaleTypeId' AND object_id = OBJECT_ID('dbo.KeySignatures'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_KeySignatures_ScaleTypeId 
        ON dbo.KeySignatures(ScaleTypeId)
        INCLUDE (RootNote, PreferredAccidental);
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_KeySignatures_RootNote' AND object_id = OBJECT_ID('dbo.KeySignatures'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_KeySignatures_RootNote 
        ON dbo.KeySignatures(RootNote)
        INCLUDE (ScaleTypeId, PreferredAccidental);
END
GO

-- Indexes for ChordTypes table (queried by name and pattern)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_ChordTypes_ChordName' AND object_id = OBJECT_ID('dbo.ChordTypes'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ChordTypes_ChordName 
        ON dbo.ChordTypes(ChordName)
        INCLUDE (IntervalPattern, ChordSymbol);
END
GO

-- Indexes for ChordExtensions table (frequently joined with ChordTypes)
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_ChordExtensions_ChordTypeId' AND object_id = OBJECT_ID('dbo.ChordExtensions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ChordExtensions_ChordTypeId 
        ON dbo.ChordExtensions(ChordTypeId)
        INCLUDE (ExtensionName, ExtensionSymbol, Semitones);
END
GO

-- Indexes for ChordKeySignatures table
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_ChordKeySignatures_RootNote' AND object_id = OBJECT_ID('dbo.ChordKeySignatures'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_ChordKeySignatures_RootNote 
        ON dbo.ChordKeySignatures(RootNote)
    INCLUDE (PreferredAccidental);
END
GO

-- Indexes for DiatonicChordProgressions table
IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_DiatonicChord_KeyNote' AND object_id = OBJECT_ID('dbo.DiatonicChordProgressions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DiatonicChord_KeyNote 
        ON dbo.DiatonicChordProgressions(KeyNote, ScaleTypeId)
        INCLUDE (DegreeNumber, DegreeRomanNumeral, ChordSymbol);
END
GO

IF NOT EXISTS (SELECT 1
FROM sys.indexes
WHERE name = 'IX_DiatonicChord_ScaleTypeId' AND object_id = OBJECT_ID('dbo.DiatonicChordProgressions'))
BEGIN
    CREATE NONCLUSTERED INDEX IX_DiatonicChord_ScaleTypeId 
        ON dbo.DiatonicChordProgressions(ScaleTypeId)
        INCLUDE (KeyNote, DegreeNumber);
END
GO

-- ====================================
-- Statistics and Maintenance
-- ====================================

-- Update statistics for all tables to ensure optimal query plans
UPDATE STATISTICS dbo.Notes WITH FULLSCAN;
UPDATE STATISTICS dbo.Intervals WITH FULLSCAN;
UPDATE STATISTICS dbo.ScaleTypes WITH FULLSCAN;
UPDATE STATISTICS dbo.KeySignatures WITH FULLSCAN;
UPDATE STATISTICS dbo.ChordTypes WITH FULLSCAN;
UPDATE STATISTICS dbo.ChordExtensions WITH FULLSCAN;
UPDATE STATISTICS dbo.ChordKeySignatures WITH FULLSCAN;
UPDATE STATISTICS dbo.DiatonicChordProgressions WITH FULLSCAN;
GO

-- ====================================
-- Database Metadata & Documentation
-- ====================================

-- Add extended properties for documentation (with idempotency checks)
IF NOT EXISTS (
    SELECT 1
FROM sys.extended_properties
WHERE class = 3 AND major_id = SCHEMA_ID('dbo') AND minor_id = 0
    AND name = N'MS_Description'
)
BEGIN
    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'Music theory database containing notes, scales, intervals, and chord definitions',
        @level0type = N'SCHEMA', @level0name = 'dbo';
END
GO

IF NOT EXISTS (
    SELECT 1
FROM sys.extended_properties
WHERE class = 1 AND major_id = OBJECT_ID('dbo.Notes') AND minor_id = 0
    AND name = N'MS_Description'
)
BEGIN
    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'Chromatic scale notes with enharmonic equivalents',
        @level0type = N'SCHEMA', @level0name = 'dbo',
        @level1type = N'TABLE', @level1name = 'Notes';
END
GO

IF NOT EXISTS (
    SELECT 1
FROM sys.extended_properties
WHERE class = 1 AND major_id = OBJECT_ID('dbo.Intervals') AND minor_id = 0
    AND name = N'MS_Description'
)
BEGIN
    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'Musical intervals with semitone distances and roman numeral notation',
        @level0type = N'SCHEMA', @level0name = 'dbo',
        @level1type = N'TABLE', @level1name = 'Intervals';
END
GO

IF NOT EXISTS (
    SELECT 1
FROM sys.extended_properties
WHERE class = 1 AND major_id = OBJECT_ID('dbo.ScaleTypes') AND minor_id = 0
    AND name = N'MS_Description'
)
BEGIN
    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'Scale types with interval patterns (Major, Minor, Modal, etc.)',
        @level0type = N'SCHEMA', @level0name = 'dbo',
        @level1type = N'TABLE', @level1name = 'ScaleTypes';
END
GO

IF NOT EXISTS (
    SELECT 1
FROM sys.extended_properties
WHERE class = 1 AND major_id = OBJECT_ID('dbo.ChordTypes') AND minor_id = 0
    AND name = N'MS_Description'
)
BEGIN
    EXEC sys.sp_addextendedproperty 
        @name = N'MS_Description',
        @value = N'Chord types with interval patterns and quality classifications',
        @level0type = N'SCHEMA', @level0name = 'dbo',
        @level1type = N'TABLE', @level1name = 'ChordTypes';
END
GO

-- ====================================
-- Performance Validation
-- ====================================

-- Verify index fragmentation (should be 0% on fresh data)
SELECT
    OBJECT_NAME(ips.object_id) AS TableName,
    i.name AS IndexName,
    ips.avg_fragmentation_in_percent,
    ips.page_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'DETAILED') ips
    INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 0
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO

-- Display table sizes and row counts
SELECT
    t.name AS TableName,
    p.rows AS TotalRows,
    SUM(a.total_pages) * 8 AS TotalSpaceKB,
    SUM(a.used_pages) * 8 AS UsedSpaceKB,
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
FROM sys.tables t
    INNER JOIN sys.indexes i ON t.object_id = i.object_id
    INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
WHERE t.schema_id = SCHEMA_ID('dbo')
    AND t.name IN ('Notes', 'Intervals', 'ScaleTypes', 'KeySignatures', 'ChordTypes', 'ChordExtensions', 'ChordKeySignatures')
GROUP BY t.name, p.rows
ORDER BY p.rows DESC;
GO

PRINT '====================================';
PRINT 'Database Setup Complete!';
PRINT '====================================';
PRINT 'Performance optimizations applied:';
PRINT '  ✓ 13 indexes created for query optimization';
PRINT '  ✓ Statistics updated for all tables';
PRINT '  ✓ Extended properties added for documentation';
PRINT '  ✓ Fragmentation validation performed';
PRINT '';
GO

/*
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║                   DEVELOPER DATABASE ACCESS (LOCAL TESTING)                  ║
║                                                                              ║
║  Grant database access to developer accounts for local testing.             ║
║  Update @DeveloperEmail with your Azure AD email address.                   ║
║  Get your UPN: az ad signed-in-user show --query userPrincipalName -o tsv   ║
║  This section is idempotent and can be run multiple times safely.           ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
*/

-- Declare variable for developer email (modify this value for each developer)
-- IMPORTANT: Use the 'unique_name' from your token (check with: az account get-access-token --resource https://database.windows.net/)
-- SQL Server matches database users against the token's unique_name claim, not the UPN
DECLARE @DeveloperEmail NVARCHAR(100) = 'matgri@microsoft.com';
DECLARE @OldDeveloperEmail NVARCHAR(100) = 'matgri_microsoft.com#EXT#@MngEnvMCAP979769.onmicrosoft.com';
-- Guest UPN (not used for SQL auth)

PRINT '';
PRINT '====================================';
PRINT 'Adding Developer Database Access';
PRINT '====================================';
PRINT 'Developer UPN: ' + ISNULL(@DeveloperEmail, 'NOT SET');
PRINT '';

-- Only create developer access if email is specified
IF @DeveloperEmail IS NOT NULL
BEGIN
    -- Clean up: Drop old user if it exists with wrong name format
    IF EXISTS (
        SELECT 1
    FROM sys.database_principals
    WHERE name = @OldDeveloperEmail
        AND type IN ('E', 'X')
    )
    BEGIN
        BEGIN TRY
            DECLARE @DropOldUserSql NVARCHAR(500) = N'DROP USER [' + @OldDeveloperEmail + N'];';
            EXEC sp_executesql @DropOldUserSql;
            PRINT '✓ Removed old user: ' + @OldDeveloperEmail;
        END TRY
        BEGIN CATCH
            PRINT '⚠ Could not drop old user: ' + ERROR_MESSAGE();
        END CATCH
    END

    -- Check if user already exists with correct name
    IF NOT EXISTS (
        SELECT 1
    FROM sys.database_principals
    WHERE name = @DeveloperEmail
        AND type IN ('E', 'X') -- E = External user, X = External group
    )
    BEGIN
        -- Create user from Azure AD
        DECLARE @CreateUserSql NVARCHAR(500) = N'CREATE USER [' + @DeveloperEmail + N'] FROM EXTERNAL PROVIDER;';

        BEGIN TRY
            EXEC sp_executesql @CreateUserSql;
            PRINT '✓ Created database user: ' + @DeveloperEmail;
        END TRY
        BEGIN CATCH
            PRINT '✗ Failed to create user: ' + ERROR_MESSAGE();
            PRINT '  Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(10));
            PRINT '';
            PRINT '  Common causes:';
            PRINT '  - UPN format is incorrect (use exact value from az ad signed-in-user show)';
            PRINT '  - User already exists with a different name';
            PRINT '  - Network connectivity issue';
            THROW;
        END CATCH
    END
    ELSE
    BEGIN
        PRINT '✓ User already exists: ' + @DeveloperEmail;
    END

    -- Grant db_datareader role
    IF NOT IS_ROLEMEMBER('db_datareader', @DeveloperEmail) = 1
    BEGIN
        DECLARE @GrantReaderSql NVARCHAR(500) = N'ALTER ROLE db_datareader ADD MEMBER [' + @DeveloperEmail + N'];';
        EXEC sp_executesql @GrantReaderSql;
        PRINT '✓ Granted db_datareader role';
    END
    ELSE
    BEGIN
        PRINT '✓ Already has db_datareader role';
    END

    -- Grant db_datawriter role
    IF NOT IS_ROLEMEMBER('db_datawriter', @DeveloperEmail) = 1
    BEGIN
        DECLARE @GrantWriterSql NVARCHAR(500) = N'ALTER ROLE db_datawriter ADD MEMBER [' + @DeveloperEmail + N'];';
        EXEC sp_executesql @GrantWriterSql;
        PRINT '✓ Granted db_datawriter role';
    END
    ELSE
    BEGIN
        PRINT '✓ Already has db_datawriter role';
    END

    -- Grant db_ddladmin role
    IF NOT IS_ROLEMEMBER('db_ddladmin', @DeveloperEmail) = 1
    BEGIN
        DECLARE @GrantDdlAdminSql NVARCHAR(500) = N'ALTER ROLE db_ddladmin ADD MEMBER [' + @DeveloperEmail + N'];';
        EXEC sp_executesql @GrantDdlAdminSql;
        PRINT '✓ Granted db_ddladmin role';
    END
    ELSE
    BEGIN
        PRINT '✓ Already has db_ddladmin role';
    END

    -- Grant EXECUTE permission
    DECLARE @GrantExecuteSql NVARCHAR(500) = N'GRANT EXECUTE TO [' + @DeveloperEmail + N'];';
    EXEC sp_executesql @GrantExecuteSql;
    PRINT '✓ Granted EXECUTE permission';

    PRINT '';
    PRINT '====================================';
    PRINT 'Developer Access Configured';
    PRINT '====================================';

    -- Verify permissions
    SELECT
        dp.name AS [User],
        dp.type_desc AS [Type],
        dp.authentication_type_desc AS [Auth Type],
        STRING_AGG(drole.name, ', ') AS [Database Roles]
    FROM sys.database_principals dp
        LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
        LEFT JOIN sys.database_principals drole ON drm.role_principal_id = drole.principal_id
    WHERE dp.name = @DeveloperEmail
    GROUP BY dp.name, dp.type_desc, dp.authentication_type_desc;

    PRINT '';
    PRINT '✓ Developer access setup complete!';
    PRINT '';
END
ELSE
BEGIN
    PRINT '';
    PRINT '====================================';
    PRINT 'DEVELOPER ACCESS NOT CONFIGURED';
    PRINT '====================================';
    PRINT 'To grant database access for local testing:';
    PRINT '1. Get your email: az ad signed-in-user show --query userPrincipalName -o tsv';
    PRINT '2. Update @DeveloperEmail variable at the top of this section';
    PRINT '3. Re-run this script';
    PRINT '';
END
GO

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║                                                                              ║
-- ║                   MANAGED IDENTITY DATABASE ACCESS                           ║
-- ║                   (COMMENTED OUT - Setup separately if needed)               ║
-- ║                                                                              ║
-- ║  The following SQL statements are for granting database access to the        ║
-- ║  API Web App's managed identity. These have been commented out to avoid      ║
-- ║  deployment errors. Run separately using deploy-sql-schema.ps1 if needed.   ║
-- ║                                                                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Uncomment and modify the following section if you need to grant managed identity access:

/*
-- Declare variable for Web App name (modify this value as needed)
DECLARE @WebAppName NVARCHAR(100) = 'app-grooveapp-dev-api';

-- Check if user exists without requiring token validation
IF NOT EXISTS (
    SELECT 1
FROM sys.database_principals
WHERE name = @WebAppName
    AND type IN ('E', 'X') -- E = External user, X = External group
)
BEGIN
    -- Create user for managed identity
    BEGIN TRY
        DECLARE @CreateUserSql NVARCHAR(500) = N'CREATE USER [' + @WebAppName + N'] FROM EXTERNAL PROVIDER;';
        EXEC sp_executesql @CreateUserSql;
        PRINT 'Created user for managed identity: ' + @WebAppName;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 15023 -- User already exists
            PRINT 'User already exists: ' + @WebAppName;
        ELSE
            THROW;
    END CATCH
END
ELSE
BEGIN
    PRINT 'User already exists: ' + @WebAppName;
END

-- Grant data access permissions
DECLARE @GrantReaderSql NVARCHAR(500) = N'ALTER ROLE db_datareader ADD MEMBER [' + @WebAppName + N'];';
DECLARE @GrantWriterSql NVARCHAR(500) = N'ALTER ROLE db_datawriter ADD MEMBER [' + @WebAppName + N'];';
DECLARE @GrantDdlAdminSql NVARCHAR(500) = N'ALTER ROLE db_ddladmin ADD MEMBER [' + @WebAppName + N'];';

EXEC sp_executesql @GrantReaderSql;
EXEC sp_executesql @GrantWriterSql;
EXEC sp_executesql @GrantDdlAdminSql;

PRINT 'Granted db_datareader, db_datawriter, and db_ddladmin roles to ' + @WebAppName;

-- Grant execute permissions on all stored procedures and functions
DECLARE @GrantExecuteSql NVARCHAR(500) = N'GRANT EXECUTE TO [' + @WebAppName + N'];';
EXEC sp_executesql @GrantExecuteSql;
PRINT 'Granted EXECUTE permission to ' + @WebAppName;

-- Verify permissions granted to managed identity
DECLARE @VerifySql NVARCHAR(1000) = N'
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    dp.authentication_type_desc AS AuthenticationType,
    r.name AS RoleName,
    CASE 
        WHEN r.name = ''db_datareader'' THEN ''Read all data from database tables''
        WHEN r.name = ''db_datawriter'' THEN ''Insert, update, delete data in database tables''
        WHEN r.name = ''db_ddladmin'' THEN ''Run DDL commands (CREATE, ALTER, DROP)''
        ELSE ''Other permissions''
    END AS PermissionDescription
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = @WebAppName
ORDER BY dp.name, r.name;';

EXEC sp_executesql @VerifySql, N'@WebAppName NVARCHAR(100)', @WebAppName;

PRINT '';
PRINT '====================================';
PRINT 'Managed Identity Access Configured';
PRINT '====================================';
PRINT 'Database user created for Web App managed identity';
PRINT 'Permissions granted:';
PRINT '  ✓ db_datareader (read all tables)';
PRINT '  ✓ db_datawriter (insert/update/delete)';
PRINT '  ✓ db_ddladmin (DDL operations)';
PRINT '  ✓ EXECUTE (stored procedures and functions)';
PRINT '';
*/
GO

