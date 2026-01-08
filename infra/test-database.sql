-- Database Comprehensive Test Suite
-- Tests all tables, views, and functions to verify successful deployment

PRINT '========================================';
PRINT 'Starting Database Validation Tests';
PRINT '========================================';
PRINT '';

-- Test 1: Verify Notes Table
PRINT 'Test 1: Verifying Notes table...';
DECLARE @noteCount INT;
SELECT @noteCount = COUNT(*)
FROM dbo.Notes;
IF @noteCount = 17
    PRINT '  ✓ Notes table contains correct count (17 notes)';
ELSE
    RAISERROR('  ✗ FAILED: Notes table has %d notes, expected 17', 16, 1, @noteCount);

-- Show sample notes
SELECT TOP 5
    NoteId, NoteName, EnharmonicEquivalent, SemitonesFromC
FROM dbo.Notes
ORDER BY SemitonesFromC;
PRINT '';
GO

-- Test 2: Verify Intervals Table
PRINT 'Test 2: Verifying Intervals table...';
DECLARE @intervalCount INT;
SELECT @intervalCount = COUNT(*)
FROM dbo.Intervals;
IF @intervalCount = 13
    PRINT '  ✓ Intervals table contains correct count (13 intervals)';
ELSE
    RAISERROR('  ✗ FAILED: Intervals table has %d intervals, expected 13', 16, 1, @intervalCount);

-- Show sample intervals
SELECT TOP 5
    IntervalId, IntervalName, Semitones, ShortName, RomanNumeral
FROM dbo.Intervals
ORDER BY Semitones;
PRINT '';
GO

-- Test 3: Verify ScaleTypes Table
PRINT 'Test 3: Verifying ScaleTypes table...';
DECLARE @scaleTypeCount INT;
SELECT @scaleTypeCount = COUNT(*)
FROM dbo.ScaleTypes;
IF @scaleTypeCount = 14
    PRINT '  ✓ ScaleTypes table contains correct count (14 scale types)';
ELSE
    RAISERROR('  ✗ FAILED: ScaleTypes table has %d scale types, expected 14', 16, 1, @scaleTypeCount);

-- Show sample scale types
SELECT TOP 5
    ScaleTypeId, ScaleName, IntervalPattern, Description
FROM dbo.ScaleTypes
ORDER BY ScaleTypeId;
PRINT '';
GO

-- Test 4: Verify ChordTypes Table
PRINT 'Test 4: Verifying ChordTypes table...';
DECLARE @chordTypeCount INT;
SELECT @chordTypeCount = COUNT(*)
FROM dbo.ChordTypes;
IF @chordTypeCount = 28
    PRINT '  ✓ ChordTypes table contains correct count (28 chord types)';
ELSE
    RAISERROR('  ✗ FAILED: ChordTypes table has %d chord types, expected 28', 16, 1, @chordTypeCount);

-- Show sample chord types
SELECT TOP 5
    ChordTypeId, ChordName, ChordSymbol, IntervalPattern, Description
FROM dbo.ChordTypes
ORDER BY ChordTypeId;
PRINT '';
GO

-- Test 5: Verify KeySignatures Table
PRINT 'Test 5: Verifying KeySignatures table...';
DECLARE @keySignatureCount INT;
SELECT @keySignatureCount = COUNT(*)
FROM dbo.KeySignatures;

IF @keySignatureCount > 0
    PRINT '  ✓ KeySignatures table contains data (' + CAST(@keySignatureCount AS VARCHAR) + ' entries)';
ELSE
    RAISERROR('  ✗ FAILED: KeySignatures table is empty', 16, 1);

-- Show sample key signatures
SELECT TOP 5
    KeySignatureId, RootNote, ScaleTypeId, PreferredAccidental, ScaleLetterSequence
FROM dbo.KeySignatures
ORDER BY KeySignatureId;
PRINT '';
GO

-- Test 6: Verify ChordKeySignatures Table
PRINT 'Test 6: Verifying ChordKeySignatures table...';
DECLARE @chordKeySignatureCount INT;
SELECT @chordKeySignatureCount = COUNT(*)
FROM dbo.ChordKeySignatures;

IF @chordKeySignatureCount > 0
    PRINT '  ✓ ChordKeySignatures table contains data (' + CAST(@chordKeySignatureCount AS VARCHAR) + ' entries)';
ELSE
    RAISERROR('  ✗ FAILED: ChordKeySignatures table is empty', 16, 1);

-- Show sample chord key signatures
SELECT TOP 5
    ChordKeySignatureId, RootNote, PreferredAccidental, Description
FROM dbo.ChordKeySignatures
ORDER BY ChordKeySignatureId;
PRINT '';
GO

-- Test 7: Verify ChordExtensions Table
PRINT 'Test 7: Verifying ChordExtensions table...';
DECLARE @chordExtensionCount INT;
SELECT @chordExtensionCount = COUNT(*)
FROM dbo.ChordExtensions;

IF @chordExtensionCount > 0
    PRINT '  ✓ ChordExtensions table contains data (' + CAST(@chordExtensionCount AS VARCHAR) + ' extensions)';
ELSE
    RAISERROR('  ✗ FAILED: ChordExtensions table is empty', 16, 1);

-- Show sample chord extensions
SELECT TOP 5
    ExtensionId, ChordTypeId, ExtensionName, ExtensionSymbol, Semitones, IsCommonInJazz
FROM dbo.ChordExtensions
ORDER BY ChordTypeId, DisplayOrder;
PRINT '';
GO

-- Test 8: Verify DiatonicChordProgressions Table
PRINT 'Test 8: Verifying DiatonicChordProgressions table...';
DECLARE @diatonicCount INT;
SELECT @diatonicCount = COUNT(*)
FROM dbo.DiatonicChordProgressions;

IF @diatonicCount > 100
    PRINT '  ✓ DiatonicChordProgressions table contains data (' + CAST(@diatonicCount AS VARCHAR) + ' chord progressions)';
ELSE
    RAISERROR('  ✗ FAILED: DiatonicChordProgressions table has insufficient data (%d rows)', 16, 1, @diatonicCount);

-- Show sample chord progressions
PRINT '  Sample: C Major diatonic chords:';
SELECT DegreeNumber, DegreeRomanNumeral, ChordSymbol, ChordQuality
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'C' AND ScaleTypeId = 1
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 9: Test fn_GenerateScale Function - C Major
PRINT 'Test 9: Testing fn_GenerateScale function (C Major)...';
DECLARE @cMajorDegrees INT;
SELECT @cMajorDegrees = COUNT(*)
FROM dbo.fn_GenerateScale('C', 1);

IF @cMajorDegrees = 7
    PRINT '  ✓ C Major scale generates correct number of degrees (7)';
ELSE
    RAISERROR('  ✗ FAILED: C Major scale has %d degrees, expected 7', 16, 1, @cMajorDegrees);

-- Show C Major scale
SELECT DegreeNumber, ScaleDegree, Note, IntervalName
FROM dbo.fn_GenerateScale('C', 1)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 10: Test fn_GenerateScale Function - A Minor
PRINT 'Test 10: Testing fn_GenerateScale function (A Natural Minor)...';
DECLARE @aMinorDegrees INT;
SELECT @aMinorDegrees = COUNT(*)
FROM dbo.fn_GenerateScale('A', 2);

IF @aMinorDegrees = 7
    PRINT '  ✓ A Natural Minor scale generates correct number of degrees (7)';
ELSE
    RAISERROR('  ✗ FAILED: A Natural Minor scale has %d degrees, expected 7', 16, 1, @aMinorDegrees);

-- Show A Minor scale
SELECT DegreeNumber, ScaleDegree, Note, IntervalName
FROM dbo.fn_GenerateScale('A', 2)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 11: Test fn_GenerateScale Function - G Major
PRINT 'Test 11: Testing fn_GenerateScale function (G Major)...';
DECLARE @gMajorDegrees INT;
SELECT @gMajorDegrees = COUNT(*)
FROM dbo.fn_GenerateScale('G', 1);

IF @gMajorDegrees = 7
    PRINT '  ✓ G Major scale generates correct number of degrees (7)';
ELSE
    RAISERROR('  ✗ FAILED: G Major scale has %d degrees, expected 7', 16, 1, @gMajorDegrees);

-- Show G Major scale
SELECT DegreeNumber, ScaleDegree, Note, IntervalName
FROM dbo.fn_GenerateScale('G', 1)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 12: Test fn_GenerateArpeggio Function - C Major 7
PRINT 'Test 12: Testing fn_GenerateArpeggio function (C Major 7)...';
DECLARE @cMaj7Notes INT;
SELECT @cMaj7Notes = COUNT(*)
FROM dbo.fn_GenerateArpeggio('C', 5);

IF @cMaj7Notes = 4
    PRINT '  ✓ C Major 7 arpeggio generates correct number of notes (4)';
ELSE
    RAISERROR('  ✗ FAILED: C Major 7 arpeggio has %d notes, expected 4', 16, 1, @cMaj7Notes);

-- Show C Major 7 arpeggio
SELECT DegreeNumber, ChordTone, Note, IntervalName
FROM dbo.fn_GenerateArpeggio('C', 5)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 13: Test fn_GenerateArpeggio Function - D Minor 7
PRINT 'Test 13: Testing fn_GenerateArpeggio function (D Minor 7)...';
DECLARE @dMin7Notes INT;
SELECT @dMin7Notes = COUNT(*)
FROM dbo.fn_GenerateArpeggio('D', 6);

IF @dMin7Notes = 4
    PRINT '  ✓ D Minor 7 arpeggio generates correct number of notes (4)';
ELSE
    RAISERROR('  ✗ FAILED: D Minor 7 arpeggio has %d notes, expected 4', 16, 1, @dMin7Notes);

-- Show D Minor 7 arpeggio
SELECT DegreeNumber, ChordTone, Note, IntervalName
FROM dbo.fn_GenerateArpeggio('D', 6)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 14: Test fn_GenerateArpeggio Function - G Dominant 7
PRINT 'Test 14: Testing fn_GenerateArpeggio function (G Dominant 7)...';
DECLARE @gDom7Notes INT;
SELECT @gDom7Notes = COUNT(*)
FROM dbo.fn_GenerateArpeggio('G', 7);

IF @gDom7Notes = 4
    PRINT '  ✓ G Dominant 7 arpeggio generates correct number of notes (4)';
ELSE
    RAISERROR('  ✗ FAILED: G Dominant 7 arpeggio has %d notes, expected 4', 16, 1, @gDom7Notes);

-- Show G Dominant 7 arpeggio
SELECT DegreeNumber, ChordTone, Note, IntervalName
FROM dbo.fn_GenerateArpeggio('G', 7)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 15: Test vw_NoteIntervals View
PRINT 'Test 15: Testing vw_NoteIntervals view...';
DECLARE @noteIntervalsCount INT;
SELECT @noteIntervalsCount = COUNT(*)
FROM dbo.vw_NoteIntervals;

IF @noteIntervalsCount > 0
    PRINT '  ✓ vw_NoteIntervals view returns data (' + CAST(@noteIntervalsCount AS VARCHAR) + ' intervals)';
ELSE
    RAISERROR('  ✗ FAILED: vw_NoteIntervals view returns no data', 16, 1);

-- Show sample intervals from C
SELECT TOP 5
    FromNote, ToNote, IntervalName, Semitones
FROM dbo.vw_NoteIntervals
WHERE FromNote = 'C'
ORDER BY Semitones;
PRINT '';
GO

-- Test 12: Test Extended Chord - F Dominant 7b9
PRINT 'Test 12: Testing fn_GenerateArpeggio function (F Dominant 7b9)...';
DECLARE @fDom7b9Notes INT;
SELECT @fDom7b9Notes = COUNT(*)
FROM dbo.fn_GenerateArpeggio('F', 16);

IF @fDom7b9Notes >= 4
    PRINT '  ✓ F Dominant 7b9 arpeggio generates correct number of notes';
ELSE
    RAISERROR('  ✗ FAILED: F Dominant 7b9 arpeggio has %d notes, expected >= 4', 16, 1, @fDom7b9Notes);

-- Show F Dominant 7b9 arpeggio
SELECT DegreeNumber, ChordTone, Note, IntervalName
FROM dbo.fn_GenerateArpeggio('F', 16)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 13: Test Complex Chord - A Dominant 13
PRINT 'Test 13: Testing fn_GenerateArpeggio function (A Dominant 13)...';
DECLARE @aDom13Notes INT;
SELECT @aDom13Notes = COUNT(*)
FROM dbo.fn_GenerateArpeggio('A', 22);

IF @aDom13Notes >= 4
    PRINT '  ✓ A Dominant 13 arpeggio generates correct number of notes';
ELSE
    RAISERROR('  ✗ FAILED: A Dominant 13 arpeggio has %d notes, expected >= 4', 16, 1, @aDom13Notes);

-- Show A Dominant 13 arpeggio
SELECT DegreeNumber, ChordTone, Note, IntervalName
FROM dbo.fn_GenerateArpeggio('A', 22)
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 14: Verify All Scales Can Be Generated
PRINT 'Test 14: Verifying all scale types can be generated...';
DECLARE @scaleTestErrors INT = 0;
DECLARE @scaleTypeId INT;
DECLARE @scaleName NVARCHAR(100);
DECLARE @scaleCount INT;

DECLARE scale_cursor CURSOR FOR 
SELECT ScaleTypeId, ScaleName
FROM dbo.ScaleTypes;

OPEN scale_cursor;
FETCH NEXT FROM scale_cursor INTO @scaleTypeId, @scaleName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @scaleCount = COUNT(*)
    FROM dbo.fn_GenerateScale('C', @scaleTypeId);

    IF @scaleCount = 0
    BEGIN
        PRINT '  ✗ FAILED: Scale type ' + @scaleName + ' (ID: ' + CAST(@scaleTypeId AS VARCHAR) + ') generates no notes';
        SET @scaleTestErrors = @scaleTestErrors + 1;
    END

    FETCH NEXT FROM scale_cursor INTO @scaleTypeId, @scaleName;
END

CLOSE scale_cursor;
DEALLOCATE scale_cursor;

IF @scaleTestErrors = 0
    PRINT '  ✓ All scale types can be generated successfully';
ELSE
    RAISERROR('  ✗ FAILED: %d scale types failed to generate', 16, 1, @scaleTestErrors);

PRINT '';
GO

-- Test 15: Verify All Chord Types Can Be Generated
PRINT 'Test 15: Verifying all chord types can be generated...';
DECLARE @chordTestErrors INT = 0;
DECLARE @chordTypeId INT;
DECLARE @chordName NVARCHAR(100);
DECLARE @chordCount INT;

DECLARE chord_cursor CURSOR FOR 
SELECT ChordTypeId, ChordName
FROM dbo.ChordTypes;

OPEN chord_cursor;
FETCH NEXT FROM chord_cursor INTO @chordTypeId, @chordName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @chordCount = COUNT(*)
    FROM dbo.fn_GenerateArpeggio('C', @chordTypeId);

    IF @chordCount = 0
    BEGIN
        PRINT '  ✗ FAILED: Chord type ' + @chordName + ' (ID: ' + CAST(@chordTypeId AS VARCHAR) + ') generates no notes';
        SET @chordTestErrors = @chordTestErrors + 1;
    END

    FETCH NEXT FROM chord_cursor INTO @chordTypeId, @chordName;
END

CLOSE chord_cursor;
DEALLOCATE chord_cursor;

IF @chordTestErrors = 0
    PRINT '  ✓ All chord types can be generated successfully';
ELSE
    RAISERROR('  ✗ FAILED: %d chord types failed to generate', 16, 1, @chordTestErrors);

PRINT '';
GO

-- Test 14: Verify DiatonicChordProgressions Table
PRINT 'Test 14: Verifying DiatonicChordProgressions table...';
DECLARE @chordProgressionCount INT;
SELECT @chordProgressionCount = COUNT(*)
FROM dbo.DiatonicChordProgressions;

IF @chordProgressionCount >= 84 -- 12 major keys * 7 chords = 84
    PRINT '  ✓ DiatonicChordProgressions table contains chord progressions (' + CAST(@chordProgressionCount AS VARCHAR) + ' entries)';
ELSE
    RAISERROR('  ✗ FAILED: DiatonicChordProgressions table has %d entries, expected at least 84', 16, 1, @chordProgressionCount);

-- Show C Major chord progression
PRINT '  Sample: C Major chord progression (I-ii-iii-IV-V-vi-vii°):';
SELECT DegreeNumber, DegreeRomanNumeral, ChordSymbol, ChordQuality, IntervalFromTonic
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'C' AND ScaleTypeId = 1
ORDER BY DegreeNumber;
PRINT '';
GO

-- Test 16: Test vw_CircleOfFifthsKeys View
PRINT 'Test 16: Testing vw_CircleOfFifthsKeys view...';
DECLARE @circleKeyCount INT;
SELECT @circleKeyCount = COUNT(*)
FROM dbo.vw_CircleOfFifthsKeys;

IF @circleKeyCount >= 24 -- At least 12 major + 12 minor
    PRINT '  ✓ vw_CircleOfFifthsKeys view contains keys (' + CAST(@circleKeyCount AS VARCHAR) + ' entries)';
ELSE
    RAISERROR('  ✗ FAILED: vw_CircleOfFifthsKeys view has %d entries, expected at least 24', 16, 1, @circleKeyCount);

-- Show Circle of Fifths major keys
PRINT '  Sample: Major keys in Circle of Fifths order:';
SELECT TOP 12
    RootNote, ScaleName, AccidentalCount, AccidentalType, RelativeKey, CirclePosition
FROM dbo.vw_CircleOfFifthsKeys
WHERE ScaleTypeId = 1
ORDER BY CirclePosition;
PRINT '';
GO

-- Test 16: Verify Circle of Fifths data integrity
PRINT 'Test 16: Verifying Circle of Fifths data integrity...';

-- Check that all major keys have corresponding chord progressions
DECLARE @majorKeysWithoutChords INT;
SELECT @majorKeysWithoutChords = COUNT(*)
FROM (
    SELECT DISTINCT RootNote
    FROM dbo.vw_CircleOfFifthsKeys
    WHERE ScaleTypeId = 1
) k
WHERE NOT EXISTS (
    SELECT 1
FROM dbo.DiatonicChordProgressions dcp
WHERE dcp.KeyNote = k.RootNote AND dcp.ScaleTypeId = 1
);

IF @majorKeysWithoutChords = 0
    PRINT '  ✓ All major keys have chord progressions';
ELSE
    RAISERROR('  ✗ FAILED: %d major keys missing chord progressions', 16, 1, @majorKeysWithoutChords);

-- Check that relative keys are correctly matched
DECLARE @invalidRelativeKeys INT;
SELECT @invalidRelativeKeys = COUNT(*)
FROM dbo.vw_CircleOfFifthsKeys
WHERE RelativeKey IS NULL AND ScaleTypeId IN (1, 2);

IF @invalidRelativeKeys = 0
    PRINT '  ✓ All keys have valid relative major/minor keys';
ELSE
    PRINT '  ⚠ Warning: ' + CAST(@invalidRelativeKeys AS VARCHAR) + ' keys missing relative key mapping';

PRINT '';
GO

-- Test 17: Detailed Minor Key Diagnostic (troubleshooting)
PRINT 'Test 17: Detailed minor key chord progression diagnostic...';

-- Count distinct minor keys
DECLARE @minorKeyCount INT;
SELECT @minorKeyCount = COUNT(DISTINCT KeyNote)
FROM dbo.DiatonicChordProgressions
WHERE ScaleTypeId = 2;

PRINT '  Minor keys with chord progressions: ' + CAST(@minorKeyCount AS VARCHAR);

IF @minorKeyCount = 15
    PRINT '  ✓ All 15 minor keys found';
ELSE IF @minorKeyCount = 3
    RAISERROR('  ✗ CRITICAL: Only 3 minor keys found - deployment did not include new keys!', 16, 1);
ELSE
    RAISERROR('  ⚠ WARNING: Found %d minor keys, expected 15', 16, 1, @minorKeyCount);

-- List all minor keys currently in database
PRINT '';
PRINT '  Minor keys in database:';
SELECT DISTINCT KeyNote
FROM dbo.DiatonicChordProgressions
WHERE ScaleTypeId = 2
ORDER BY KeyNote;

PRINT '';
GO

-- Test 18: Verify specific minor keys (previously failing keys)
PRINT 'Test 18: Checking specific minor keys that were failing in API...';

DECLARE @testKeys TABLE (KeyNote NVARCHAR(10));
INSERT INTO @testKeys
VALUES
    ('B'),
    ('F#'),
    ('C#'),
    ('G#'),
    ('D#'),
    ('Bb'),
    ('Eb'),
    ('A'),
    ('E'),
    ('D'),
    ('G'),
    ('C'),
    ('F');

DECLARE @keyName NVARCHAR(10);
DECLARE @chordCount INT;
DECLARE @allKeysPresent BIT = 1;

DECLARE key_cursor CURSOR FOR SELECT KeyNote
FROM @testKeys
ORDER BY KeyNote;
OPEN key_cursor;
FETCH NEXT FROM key_cursor INTO @keyName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @chordCount = COUNT(*)
    FROM dbo.DiatonicChordProgressions
    WHERE KeyNote = @keyName AND ScaleTypeId = 2;

    IF @chordCount = 7
        PRINT '  ✓ ' + @keyName + ' minor: ' + CAST(@chordCount AS VARCHAR) + ' chords';
    ELSE IF @chordCount = 0
    BEGIN
        PRINT '  ✗ ' + @keyName + ' minor: MISSING (0 chords)';
        SET @allKeysPresent = 0;
    END
    ELSE
    BEGIN
        PRINT '  ⚠ ' + @keyName + ' minor: ' + CAST(@chordCount AS VARCHAR) + ' chords (expected 7)';
        SET @allKeysPresent = 0;
    END

    FETCH NEXT FROM key_cursor INTO @keyName;
END

CLOSE key_cursor;
DEALLOCATE key_cursor;

IF @allKeysPresent = 1
    PRINT '  ✓ All 13 test keys have complete chord progressions';
ELSE
    RAISERROR('  ✗ FAILED: Some keys are missing or incomplete', 16, 1);

PRINT '';
GO

-- Test 19: Sample chord progression verification
PRINT 'Test 19: Verifying sample chord progressions...';

PRINT '  F# minor chord progression:';
DECLARE @fSharpMinorCount INT;
SELECT DegreeNumber, DegreeRomanNumeral, ChordSymbol
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'F#' AND ScaleTypeId = 2
ORDER BY DegreeNumber;
SET @fSharpMinorCount = @@ROWCOUNT;

IF @fSharpMinorCount = 7
    PRINT '  ✓ F# minor progression complete (7 chords)';
ELSE IF @fSharpMinorCount = 0
    RAISERROR('  ✗ FAILED: F# minor progression not found', 16, 1);
ELSE
    RAISERROR('  ✗ FAILED: F# minor has %d chords, expected 7', 16, 1, @fSharpMinorCount);

PRINT '';
PRINT '  A minor chord progression:';
DECLARE @aMinorCount INT;
SELECT DegreeNumber, DegreeRomanNumeral, ChordSymbol
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'A' AND ScaleTypeId = 2
ORDER BY DegreeNumber;
SET @aMinorCount = @@ROWCOUNT;

IF @aMinorCount = 7
    PRINT '  ✓ A minor progression complete (7 chords)';
ELSE
    RAISERROR('  ✗ FAILED: A minor progression has %d chords, expected 7', 16, 1, @aMinorCount);

PRINT '';
GO

-- Test 20: Table metadata verification
PRINT 'Test 20: Checking table metadata for deployment verification...';

SELECT
    t.name AS TableName,
    t.create_date AS CreateDate,
    t.modify_date AS ModifyDate,
    DATEDIFF(MINUTE, t.create_date, GETDATE()) AS MinutesSinceCreation,
    DATEDIFF(MINUTE, t.modify_date, GETDATE()) AS MinutesSinceModification
FROM sys.tables t
WHERE t.name = 'DiatonicChordProgressions';

PRINT '  Note: If create_date is recent, table was dropped and recreated';
PRINT '  Note: If modify_date is recent, data was recently inserted/updated';

PRINT '';
GO

-- Test 21: Expected vs Actual minor keys
PRINT 'Test 21: Missing keys report...';

-- Expected keys
DECLARE @expectedKeys TABLE (KeyNote NVARCHAR(10));
INSERT INTO @expectedKeys
VALUES
    ('A'),
    ('B'),
    ('C'),
    ('C#'),
    ('D'),
    ('D#'),
    ('E'),
    ('Eb'),
    ('F'),
    ('F#'),
    ('G'),
    ('G#'),
    ('Bb');

-- Find missing keys
PRINT '  Expected 13 minor keys (enharmonic spellings excluded):';
SELECT ek.KeyNote AS ExpectedKey,
    CASE WHEN dcp.KeyNote IS NULL THEN '✗ MISSING' ELSE '✓ Found' END AS Status,
    COUNT(dcp.DegreeNumber) AS ChordCount
FROM @expectedKeys ek
    LEFT JOIN (
    SELECT DISTINCT KeyNote, DegreeNumber
    FROM dbo.DiatonicChordProgressions
    WHERE ScaleTypeId = 2
) dcp ON ek.KeyNote = dcp.KeyNote
GROUP BY ek.KeyNote, dcp.KeyNote
ORDER BY ek.KeyNote;

DECLARE @missingCount INT;
SELECT @missingCount = COUNT(*)
FROM @expectedKeys ek
WHERE NOT EXISTS (
    SELECT 1
FROM dbo.DiatonicChordProgressions dcp
WHERE dcp.KeyNote = ek.KeyNote AND dcp.ScaleTypeId = 2
);

IF @missingCount = 0
    PRINT '  ✓ All expected keys found';
ELSE
    RAISERROR('  ✗ FAILED: %d keys are missing from database', 16, 1, @missingCount);

PRINT '';
GO

-- Test 22: Check for duplicate diatonic chords
PRINT 'Test 22: Checking for duplicate diatonic chords...';
SELECT
    KeyNote,
    ScaleTypeId,
    DegreeNumber,
    ChordSymbol,
    COUNT(*) as DuplicateCount
FROM dbo.DiatonicChordProgressions
GROUP BY KeyNote, ScaleTypeId, DegreeNumber, ChordSymbol
HAVING COUNT(*) > 1
ORDER BY KeyNote, DegreeNumber;

IF @@ROWCOUNT = 0
    PRINT '  ✓ No duplicate chords found';
ELSE
    RAISERROR('  ✗ FAILED: Duplicate chords found - see results above', 16, 1);
PRINT '';
GO

-- Test 23: Verify C# Minor sharp symbols
PRINT 'Test 23: Verifying C# Minor sharp symbols...';
SELECT
    DegreeNumber,
    DegreeRomanNumeral,
    ChordRoot,
    ChordSymbol,
    LEN(ChordSymbol) as SymbolLength,
    ASCII(SUBSTRING(ChordSymbol, 2, 1)) as SecondCharASCII,
    CASE 
        WHEN ChordSymbol LIKE '%#%' THEN '✓ Contains #'
        ELSE '✗ Missing #'
    END as HasSharp
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'C#' AND ScaleTypeId = 2
ORDER BY DegreeNumber;

DECLARE @missingSharpCount INT;
SELECT @missingSharpCount = COUNT(*)
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'C#'
    AND ScaleTypeId = 2
    AND ChordRoot LIKE '%#%'
    AND ChordSymbol NOT LIKE '%#%';

IF @missingSharpCount = 0
    PRINT '  ✓ All sharp symbols present in C# Minor';
ELSE
    RAISERROR('  ✗ FAILED: %d chord symbols missing sharp (#) in C# Minor', 16, 1, @missingSharpCount);
PRINT '';
GO

-- Test 24: Verify all sharp minor keys have proper symbols
PRINT 'Test 24: Verifying sharp symbols in all sharp minor keys...';
SELECT
    KeyNote,
    DegreeNumber,
    ChordSymbol,
    CASE 
        WHEN ChordSymbol LIKE '%#%' THEN '✓'
        WHEN ChordRoot LIKE '%#%' THEN '⚠ Root has #, Symbol missing #'
        ELSE 'OK (no sharp expected)'
    END as SharpCheck
FROM dbo.DiatonicChordProgressions
WHERE ScaleTypeId = 2
    AND KeyNote IN ('B', 'F#', 'C#', 'G#', 'D#', 'A#')
    AND (ChordRoot LIKE '%#%' OR ChordSymbol LIKE '%#%')
ORDER BY KeyNote, DegreeNumber;

DECLARE @sharpIssueCount INT;
SELECT @sharpIssueCount = COUNT(*)
FROM dbo.DiatonicChordProgressions
WHERE ScaleTypeId = 2
    AND KeyNote IN ('B', 'F#', 'C#', 'G#', 'D#', 'A#')
    AND ChordRoot LIKE '%#%'
    AND ChordSymbol NOT LIKE '%#%';

IF @sharpIssueCount = 0
    PRINT '  ✓ All sharp symbols correct in sharp minor keys';
ELSE
    RAISERROR('  ✗ FAILED: %d chord symbols have sharp symbol issues', 16, 1, @sharpIssueCount);
PRINT '';
GO

-- Test 25: Verify chord count per key (should be 7 each)
PRINT 'Test 25: Verifying chord count per key...';
SELECT
    KeyNote,
    ScaleTypeId,
    CASE ScaleTypeId WHEN 1 THEN 'Major' WHEN 2 THEN 'Minor' END as ScaleType,
    COUNT(*) as ChordCount,
    CASE 
        WHEN COUNT(*) = 7 THEN '✓'
        ELSE '✗ Expected 7'
    END as Status
FROM dbo.DiatonicChordProgressions
GROUP BY KeyNote, ScaleTypeId
ORDER BY ScaleTypeId, KeyNote;

DECLARE @incorrectChordCount INT;
SELECT @incorrectChordCount = COUNT(*)
FROM (
    SELECT KeyNote, ScaleTypeId, COUNT(*) as ChordCount
    FROM dbo.DiatonicChordProgressions
    GROUP BY KeyNote, ScaleTypeId
    HAVING COUNT(*) != 7
) AS Incorrect;

IF @incorrectChordCount = 0
    PRINT '  ✓ All keys have exactly 7 diatonic chords';
ELSE
    RAISERROR('  ✗ FAILED: %d keys have incorrect chord count', 16, 1, @incorrectChordCount);
PRINT '';
GO

-- Test Summary
PRINT '========================================';
PRINT 'Database Validation Complete!';
PRINT '========================================';
PRINT 'Test Summary:';
PRINT '  Tests 1-6:   Core tables (Notes, Intervals, ScaleTypes, ChordTypes)';
PRINT '  Tests 7-11:  Functions (fn_GenerateScale, fn_GenerateArpeggio)';
PRINT '  Tests 12-16: Circle of Fifths (views, chord progressions, data integrity)';
PRINT '  Tests 17-21: Detailed diagnostics (minor keys, missing data, metadata)';
PRINT '  Tests 22-25: Circle of Fifths validation (duplicates, sharp symbols, counts)';
PRINT '';
PRINT 'If all tests pass:';
PRINT '  ✓ Database is ready for use';
PRINT '';
PRINT 'If Tests 17-21 show missing minor keys:';
PRINT '  ✗ Re-run deployment: sqlcmd -S <server> -d <database> -G -i setup-music-tables.sql';
PRINT '  ✗ Verify correct database: Check server and database names match environment';
PRINT '';
PRINT 'If Tests 22-25 show issues:';
PRINT '  ✗ Test 22 fails: Duplicate data - redeploy with GO statements fixed';
PRINT '  ✗ Test 23-24 fails: Sharp symbols missing - check Unicode encoding in database';
PRINT '  ✗ Test 25 fails: Incorrect chord counts - verify INSERT statements complete';
PRINT '';
GO
