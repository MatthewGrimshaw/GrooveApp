SELECT *
FROM dbo.fn_GenerateScale('Db', 1);

-- View all notes:
SELECT *
FROM dbo.Notes
ORDER BY SemitonesFromC;

-- Generate C Major scale:
SELECT *
FROM dbo.fn_GenerateScale('D', 1);

-- Generate G Major scale:
SELECT *
FROM dbo.fn_GenerateScale('G', 1);

-- Generate A Minor scale:
SELECT *
FROM dbo.fn_GenerateScale('A', 2);

-- View intervals from C:
SELECT *
FROM dbo.vw_NoteIntervals
WHERE FromNote = 'C'
ORDER BY Semitones;

-- View all major scales:
SELECT st.ScaleName, n.NoteName AS RootNote, s.DegreeNumber, s.ScaleDegree, s.Note, s.IntervalName
FROM dbo.ScaleTypes st
CROSS APPLY (SELECT NoteName
    FROM dbo.Notes
    WHERE IsSharp = 1 OR IsNatural = 1) n
CROSS APPLY dbo.fn_GenerateScale(n.NoteName, st.ScaleTypeId) s
WHERE st.ScaleTypeId = 1
ORDER BY n.NoteName, s.DegreeNumber;


Select *
FROM dbo.ScaleTypes;

-- Generate A Minor scale:
SELECT *
FROM dbo.fn_GenerateScale('A', 14);


-- View all chord types
SELECT *
FROM dbo.ChordTypes;

-- C Major 7 arpeggio
SELECT *
FROM dbo.fn_GenerateArpeggio('C', 5);

-- D Minor 7 arpeggio
SELECT *
FROM dbo.fn_GenerateArpeggio('D', 6);

-- G Dominant 7 arpeggio
SELECT *
FROM dbo.fn_GenerateArpeggio('G', 7);

-- B Half Diminished arpeggio
SELECT *
FROM dbo.fn_GenerateArpeggio('B', 8);

-- F Dominant 7b9 arpeggio
SELECT *
FROM dbo.fn_GenerateArpeggio('F', 16);

-- A Dominant 13 arpeggio
SELECT *
FROM dbo.fn_GenerateArpeggio('A', 22);

-- ====================================
-- Circle of Fifths Queries
-- ====================================

-- View all major keys in Circle of Fifths order
SELECT *
FROM dbo.vw_CircleOfFifthsKeys
WHERE ScaleTypeId = 1
ORDER BY CirclePosition;

-- View all minor keys in Circle of Fifths order
SELECT *
FROM dbo.vw_CircleOfFifthsKeys
WHERE ScaleTypeId = 2
ORDER BY CirclePosition;

-- Get chord progression for C Major
SELECT *
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'C' AND ScaleTypeId = 1
ORDER BY DegreeNumber;

-- Get chord progression for A Minor
SELECT *
FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'A' AND ScaleTypeId = 2
ORDER BY DegreeNumber;

-- Get all keys with their relative major/minor and sharp/flat counts
SELECT
    RootNote,
    ScaleName,
    AccidentalCount,
    AccidentalType,
    RelativeKey,
    CirclePosition
FROM dbo.vw_CircleOfFifthsKeys
ORDER BY ScaleTypeId, CirclePosition;

-- Get adjacent keys in Circle of Fifths (modulat ion destinations)
SELECT
    k1.RootNote AS CurrentKey,
    k1.ScaleName AS CurrentScale,
    k1.CirclePosition,
    k2.RootNote AS NextKey,
    k2.ScaleName AS NextScale,
    k2.CirclePosition AS NextPosition
FROM dbo.vw_CircleOfFifthsKeys k1
    LEFT JOIN dbo.vw_CircleOfFifthsKeys k2
    ON k2.CirclePosition = (k1.CirclePosition + 1) % 12
        AND k2.ScaleTypeId = k1.ScaleTypeId
WHERE k1.ScaleTypeId = 1
ORDER BY k1.CirclePosition;
