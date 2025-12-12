SELECT * FROM dbo.fn_GenerateScale('Db', 1);

-- View all notes:
SELECT * FROM dbo.Notes ORDER BY SemitonesFromC;

-- Generate C Major scale:
SELECT * FROM dbo.fn_GenerateScale('D', 1);

-- Generate G Major scale:
SELECT * FROM dbo.fn_GenerateScale('G', 1);

-- Generate A Minor scale:
SELECT * FROM dbo.fn_GenerateScale('A', 2);

-- View intervals from C:
SELECT *
FROM dbo.vw_NoteIntervals
WHERE FromNote = 'C'
ORDER BY Semitones;

-- View all major scales:
SELECT st.ScaleName, n.NoteName AS RootNote, s.DegreeNumber, s.ScaleDegree, s.Note, s.IntervalName
FROM dbo.ScaleTypes st
CROSS APPLY (SELECT NoteName FROM dbo.Notes WHERE IsSharp = 1 OR IsNatural = 1) n
CROSS APPLY dbo.fn_GenerateScale(n.NoteName, st.ScaleTypeId) s
WHERE st.ScaleTypeId = 1
ORDER BY n.NoteName, s.DegreeNumber;


Select * FROM dbo.ScaleTypes;

-- Generate A Minor scale:
SELECT * FROM dbo.fn_GenerateScale('A', 14);


-- View all chord types
SELECT * FROM dbo.ChordTypes;

-- C Major 7 arpeggio
SELECT * FROM dbo.fn_GenerateArpeggio('C', 5);

-- D Minor 7 arpeggio
SELECT * FROM dbo.fn_GenerateArpeggio('D', 6);

-- G Dominant 7 arpeggio
SELECT * FROM dbo.fn_GenerateArpeggio('G', 7);

-- B Half Diminished arpeggio
SELECT * FROM dbo.fn_GenerateArpeggio('B', 8);

-- F Dominant 7b9 arpeggio
SELECT * FROM dbo.fn_GenerateArpeggio('F', 16);

-- A Dominant 13 arpeggio
SELECT * FROM dbo.fn_GenerateArpeggio('A', 22);