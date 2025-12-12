# Key Signature System - Fixing Note Spelling in Scales and Arpeggios

## Problem

The original database logic used a simple rule: "if the root note is flat, prefer flats; otherwise prefer sharps." This caused incorrect note spelling that violates music theory conventions:

**Example Issues:**
- F Major scale returned: F, G, A, **A#**, C, D, E, F (incorrect - should be **Bb**)
- Violated the rule that each letter (A-G) appears exactly once in a scale
- Didn't follow the interval pattern (W-W-H-W-W-W-H for major scales)

## Solution

Implemented a **Key Signature System** that defines the correct note spelling for each scale type and root note combination.

### Key Music Theory Principles

1. **Letter Name Rule**: Every scale uses each letter name (A, B, C, D, E, F, G) exactly once
2. **Circle of Fifths**: Sharp keys (G, D, A, E, B, F#, C#) use sharps; Flat keys (F, Bb, Eb, Ab, Db, Gb) use flats
3. **Key Signatures**: Each key has a defined set of sharps or flats that apply to all scales in that key

### Database Changes

#### 1. KeySignatures Table

Created `dbo.KeySignatures` table with:
- **RootNote**: The tonic/root of the scale (e.g., 'C', 'F', 'G')
- **ScaleTypeId**: Reference to the scale type (Major, Natural Minor, etc.)
- **PreferredAccidental**: 'sharp', 'flat', or 'natural'
- **ScaleLetterSequence**: Ordered list of letter names (e.g., 'F,G,A,B,C,D,E' for F Major)
- **Description**: Human-readable description

**Example entries:**
```sql
-- C Major uses natural notes with letter sequence C,D,E,F,G,A,B
('C', 1, 'natural', 'C,D,E,F,G,A,B', 'C Major - No sharps or flats')

-- F Major uses flats with letter sequence F,G,A,B,C,D,E
-- Note: B in the sequence becomes Bb due to the interval pattern
('F', 1, 'flat', 'F,G,A,B,C,D,E', 'F Major - 1 flat (Bb)')

-- G Major uses sharps with letter sequence G,A,B,C,D,E,F
-- Note: F in the sequence becomes F# due to the interval pattern
('G', 1, 'sharp', 'G,A,B,C,D,E,F', 'G Major - 1 sharp (F#)')
```

#### 2. ChordKeySignatures Table

Created `dbo.ChordKeySignatures` table for arpeggios:
- **RootNote**: The root of the chord
- **PreferredAccidental**: 'sharp', 'flat', or 'natural'

Simplified approach: chords follow the same sharp/flat preference as their root note's major scale.

### Function Updates

#### Enhanced fn_GenerateScale

The updated function:

1. **Looks up key signature** for the root note and scale type
2. **Extracts letter sequence** (e.g., F,G,A,B,C,D,E for F Major)
3. **Matches each scale degree** to its required letter
4. **Applies interval pattern** to find the correct semitone
5. **Selects the note** with both the correct semitone AND correct letter

**Algorithm:**
```sql
-- For each degree in the scale:
-- 1. Get the required letter from the letter sequence
-- 2. Calculate the semitone using the interval pattern
-- 3. Find the note that matches BOTH:
--    - The calculated semitone (pitch)
--    - The required letter (spelling)
```

**Example: F Major Scale**
- Degree 1: Letter=F, Semitones=0 → F
- Degree 2: Letter=G, Semitones=2 → G
- Degree 3: Letter=A, Semitones=4 → A
- Degree 4: Letter=B, Semitones=5 → **Bb** (not A#!)
- Degree 5: Letter=C, Semitones=7 → C
- Degree 6: Letter=D, Semitones=9 → D
- Degree 7: Letter=E, Semitones=11 → E
- Degree 8: Letter=F, Semitones=12 → F

#### Enhanced fn_GenerateArpeggio

Similar approach for chords:

1. **Looks up chord key signature** for the root note
2. **Uses preferred accidental** (sharp/flat/natural)
3. **Selects notes** matching both semitone and accidental preference

### Key Signature Coverage

#### Major Scales (ScaleTypeId = 1)
- **Sharp keys**: G, D, A, E, B, F#, C#
- **Flat keys**: F, Bb, Eb, Ab, Db, Gb
- **Natural key**: C

#### Natural Minor Scales (ScaleTypeId = 2)
- Uses same key signatures as their **relative major**
- Example: A minor = C Major (no sharps/flats)
- Example: E minor = G Major (1 sharp: F#)

#### Other Scales
- Harmonic Minor (ScaleTypeId = 3)
- Melodic Minor (ScaleTypeId = 4)
- Dorian, Phrygian, Lydian, Mixolydian, Locrian (ScaleTypeId = 5-9)
- Pentatonic Major/Minor (ScaleTypeId = 10-11)
- Blues (ScaleTypeId = 12)

### Benefits

1. **Correct Note Spelling**: Every scale follows proper music notation
2. **One Letter Per Degree**: Each scale uses A-G exactly once (except pentatonic)
3. **Follows Circle of Fifths**: Sharp keys use sharps, flat keys use flats
4. **Scalable**: Easy to add new scales by defining their key signature
5. **Music Theory Compliance**: Matches standard notation in sheet music

### Examples

#### Before (Incorrect)
```
F Major: F, G, A, A#, C, D, E, F  ❌ (A appears twice as A and A#)
Eb Major: D#, F, G, G#, A#, C, D, D#  ❌ (D and G appear twice)
```

#### After (Correct)
```
F Major: F, G, A, Bb, C, D, E, F  ✅ (Each letter once)
Eb Major: Eb, F, G, Ab, Bb, C, D, Eb  ✅ (Each letter once)
D Major: D, E, F#, G, A, B, C#, D  ✅ (Each letter once)
```

### Implementation Files

1. **add-key-signatures.sql**: Creates KeySignatures table with all key signatures
2. **update-scale-function.sql**: Enhanced fn_GenerateScale with letter-matching logic
3. **update-arpeggio-function.sql**: Enhanced fn_GenerateArpeggio with accidental preferences
4. **apply-key-signatures.ps1**: PowerShell script to apply all changes

### Testing

Run the test queries included in each script:

```sql
-- Test F Major (should show Bb, not A#)
SELECT * FROM dbo.fn_GenerateScale('F', 1);

-- Test D Major (should show F# and C#)
SELECT * FROM dbo.fn_GenerateScale('D', 1);

-- Test Eb Major (should show Bb, Eb, Ab)
SELECT * FROM dbo.fn_GenerateScale('Eb', 1);

-- Test F Major 7 chord (should show Bb)
SELECT * FROM dbo.fn_GenerateArpeggio('F', 5);
```

### Deployment

Run from the infra directory:

```powershell
.\apply-key-signatures.ps1
```

This will:
1. Verify Azure authentication
2. Create KeySignatures tables
3. Update fn_GenerateScale function
4. Update fn_GenerateArpeggio function
5. Run test queries

### Future Enhancements

1. **Double Sharps/Flats**: For extreme keys (e.g., G# Major with F𝄪)
2. **Descending Melodic Minor**: Different notes when descending
3. **Modal Key Signatures**: Explicit signatures for each mode
4. **Chord Inversions**: Specify which note is in the bass
5. **Jazz Alterations**: b9, #9, #11, b13 in extended chords

## Music Theory Reference

### Circle of Fifths (Sharps)
- **C**: No sharps
- **G**: F#
- **D**: F#, C#
- **A**: F#, C#, G#
- **E**: F#, C#, G#, D#
- **B**: F#, C#, G#, D#, A#
- **F#**: F#, C#, G#, D#, A#, E#
- **C#**: All sharps

### Circle of Fifths (Flats)
- **C**: No flats
- **F**: Bb
- **Bb**: Bb, Eb
- **Eb**: Bb, Eb, Ab
- **Ab**: Bb, Eb, Ab, Db
- **Db**: Bb, Eb, Ab, Db, Gb
- **Gb**: Bb, Eb, Ab, Db, Gb, Cb

### Major Scale Pattern
**W-W-H-W-W-W-H** (Whole-Whole-Half-Whole-Whole-Whole-Half)
- In semitones: 2-2-1-2-2-2-1

### Natural Minor Scale Pattern
**W-H-W-W-H-W-W** (Whole-Half-Whole-Whole-Half-Whole-Whole)
- In semitones: 2-1-2-2-1-2-2
