# Circle of Fifths Feature

## Overview

The Circle of Fifths is an interactive visualization tool that helps musicians understand key relationships, chord progressions, and key signatures in music theory. This feature displays major and minor keys in concentric circles, showing their relationships, sharp/flat counts, and diatonic chord progressions.

## Features

### Interactive Diagram
- **Outer Ring**: Major keys arranged in Circle of Fifths order (C → G → D → A → E → B → F#/Gb → Db → Ab → Eb → Bb → F)
- **Middle Ring**: Major key labels with sharp/flat counts
- **Inner Ring**: Relative minor keys (e.g., A minor is relative to C major)
- **Color Coding**:
  - Blue tint: Flat keys (left side)
  - Orange tint: Sharp keys (right side)
  - Purple tint: Minor keys (inner ring)
  - White: C Major / A Minor (no sharps or flats)

### Key Information Display
When a key is clicked:
- **Key name and scale type** (e.g., "G Major")
- **Description** with sharp/flat count (e.g., "G Major - 1 sharp (F#)")
- **Relative major/minor key** (e.g., "Relative Minor: Em")
- **Diatonic chord progression** with roman numerals:
  - Major: I, ii, iii, IV, V, vi, vii°
  - Minor: i, ii°, III, iv, v, VI, VII

### Chord Progression Cards
Each chord in the selected key's progression shows:
- **Roman numeral** (I, ii, iii, etc.)
- **Chord symbol** (C, Dm, Em, etc.)
- **Chord quality** (Major, Minor, Diminished)
- **Function description** (Tonic, Subdominant, Dominant, etc.)

## Database Schema

### New Tables

#### DiatonicChordProgressions
Stores the seven diatonic chords for each major and minor key.

```sql
CREATE TABLE dbo.DiatonicChordProgressions (
    ProgressionId INT PRIMARY KEY IDENTITY(1,1),
    KeyNote NVARCHAR(10) NOT NULL,
    ScaleTypeId INT NOT NULL,  -- 1 = Major, 2 = Natural Minor
    DegreeNumber INT NOT NULL,  -- 1-7 for scale degrees
    DegreeRomanNumeral NVARCHAR(10) NOT NULL,  -- I, ii, iii, IV, V, vi, vii°
    ChordRoot NVARCHAR(10) NOT NULL,
    ChordQuality NVARCHAR(20) NOT NULL,  -- 'Major', 'Minor', 'Diminished'
    ChordSymbol NVARCHAR(20) NOT NULL,  -- Display symbol (e.g., 'C', 'Dm')
    IntervalFromTonic INT NOT NULL,  -- Semitones from tonic
    Description NVARCHAR(200) NULL
);
```

**Example Data**:
```sql
-- C Major chord progression
('C', 1, 1, 'I', 'C', 'Major', 'C', 0, 'Tonic - Home chord')
('C', 1, 2, 'ii', 'D', 'Minor', 'Dm', 2, 'Supertonic - Pre-dominant')
('C', 1, 3, 'iii', 'E', 'Minor', 'Em', 4, 'Mediant - Tonic substitute')
('C', 1, 4, 'IV', 'F', 'Major', 'F', 5, 'Subdominant - Pre-dominant')
('C', 1, 5, 'V', 'G', 'Major', 'G', 7, 'Dominant - Tension and resolution')
('C', 1, 6, 'vi', 'A', 'Minor', 'Am', 9, 'Submediant - Tonic substitute')
('C', 1, 7, 'vii°', 'B', 'Diminished', 'B°', 11, 'Leading tone - Dominant function')
```

### New Views

#### vw_CircleOfFifthsKeys
Provides a comprehensive view of all keys with their Circle of Fifths metadata.

```sql
CREATE VIEW dbo.vw_CircleOfFifthsKeys AS
SELECT 
    ks.KeySignatureId,
    ks.RootNote,
    ks.ScaleTypeId,
    st.ScaleName,
    ks.PreferredAccidental,
    ks.Description,
    -- Calculate sharp/flat count from description
    CASE WHEN ks.Description LIKE '%1 sharp%' THEN 1 ... END AS AccidentalCount,
    CASE WHEN ks.PreferredAccidental = 'sharp' THEN 'Sharps' ... END AS AccidentalType,
    -- Position in Circle (0-11, where C=0)
    CASE ks.RootNote WHEN 'C' THEN 0 WHEN 'G' THEN 1 ... END AS CirclePosition,
    -- Relative major/minor
    CASE WHEN ks.ScaleTypeId = 1 THEN (find relative minor) ... END AS RelativeKey
FROM KeySignatures ks
INNER JOIN ScaleTypes st ON ks.ScaleTypeId = st.ScaleTypeId
WHERE ks.ScaleTypeId IN (1, 2);
```

**View Output Example**:
| RootNote | ScaleName | AccidentalCount | AccidentalType | CirclePosition | RelativeKey |
|----------|-----------|-----------------|----------------|----------------|-------------|
| C        | Major     | 0               | Natural        | 0              | A           |
| G        | Major     | 1               | Sharps         | 1              | E           |
| D        | Major     | 2               | Sharps         | 2              | B           |
| A        | Minor     | 0               | Natural        | 0              | C           |

## API Endpoints

### GET /circle-of-fifths/keys
Get all keys in the Circle of Fifths with metadata.

**Query Parameters**:
- `scale_type` (optional): Filter by scale type (1=Major, 2=Minor)

**Examples**:
```bash
# Get all major and minor keys
GET /circle-of-fifths/keys

# Get major keys only
GET /circle-of-fifths/keys?scale_type=1

# Get minor keys only
GET /circle-of-fifths/keys?scale_type=2
```

**Response Model** (`CircleOfFifthsKey`):
```typescript
{
  KeySignatureId: number;
  RootNote: string;
  ScaleTypeId: number;
  ScaleName: string;
  PreferredAccidental: string;
  Description: string;
  AccidentalCount: number;
  AccidentalType: string;  // "Sharps", "Flats", or "Natural"
  CirclePosition: number;  // 0-11
  RelativeKey: string;
}
```

**Example Response**:
```json
[
  {
    "KeySignatureId": 1,
    "RootNote": "C",
    "ScaleTypeId": 1,
    "ScaleName": "Major",
    "PreferredAccidental": "natural",
    "Description": "C Major - No sharps or flats",
    "AccidentalCount": 0,
    "AccidentalType": "Natural",
    "CirclePosition": 0,
    "RelativeKey": "A"
  },
  {
    "KeySignatureId": 2,
    "RootNote": "G",
    "ScaleTypeId": 1,
    "ScaleName": "Major",
    "PreferredAccidental": "sharp",
    "Description": "G Major - 1 sharp (F#)",
    "AccidentalCount": 1,
    "AccidentalType": "Sharps",
    "CirclePosition": 1,
    "RelativeKey": "E"
  }
]
```

---

### GET /circle-of-fifths/progression/{key_note}
Get the diatonic chord progression for a specific key.

**Path Parameters**:
- `key_note`: Root note of the key (e.g., "C", "G", "A")

**Query Parameters**:
- `scale_type`: Scale type (1=Major, 2=Minor). Default: 1

**Examples**:
```bash
# C Major chord progression (C, Dm, Em, F, G, Am, B°)
GET /circle-of-fifths/progression/C?scale_type=1

# A Minor chord progression (Am, B°, C, Dm, Em, F, G)
GET /circle-of-fifths/progression/A?scale_type=2

# G Major chord progression (G, Am, Bm, C, D, Em, F#°)
GET /circle-of-fifths/progression/G?scale_type=1
```

**Response Model** (`DiatonicChord`):
```typescript
{
  ProgressionId: number;
  KeyNote: string;
  ScaleTypeId: number;
  DegreeNumber: number;
  DegreeRomanNumeral: string;
  ChordRoot: string;
  ChordQuality: string;
  ChordSymbol: string;
  IntervalFromTonic: number;
  Description: string;
}
```

**Example Response** (C Major):
```json
[
  {
    "ProgressionId": 1,
    "KeyNote": "C",
    "ScaleTypeId": 1,
    "DegreeNumber": 1,
    "DegreeRomanNumeral": "I",
    "ChordRoot": "C",
    "ChordQuality": "Major",
    "ChordSymbol": "C",
    "IntervalFromTonic": 0,
    "Description": "Tonic - Home chord"
  },
  {
    "ProgressionId": 2,
    "KeyNote": "C",
    "ScaleTypeId": 1,
    "DegreeNumber": 2,
    "DegreeRomanNumeral": "ii",
    "ChordRoot": "D",
    "ChordQuality": "Minor",
    "ChordSymbol": "Dm",
    "IntervalFromTonic": 2,
    "Description": "Supertonic - Pre-dominant"
  }
  // ... remaining chords (iii, IV, V, vi, vii°)
]
```

## Frontend Component

### Component Structure

**File**: `app/src/app/components/circle-of-fifths.component.ts`

**Key Features**:
1. **SVG-based circular diagram** with concentric rings
2. **Three layers**:
   - Outer ring: Sharp/flat count labels
   - Middle ring: Major key names
   - Inner ring: Minor key names
3. **Interactive segments**: Click to select a key
4. **Dynamic chord progression display**: Shows diatonic chords when key is selected
5. **Color-coded segments**: Sharps (orange), flats (blue), minor (purple)

### Component Properties

```typescript
majorKeys: CircleOfFifthsKey[] = [];    // Major keys sorted by CirclePosition
minorKeys: CircleOfFifthsKey[] = [];    // Minor keys sorted by CirclePosition
selectedKey: CircleOfFifthsKey | null = null;
chordProgression: DiatonicChord[] = [];

// SVG dimensions
svgSize = 500;
center = 250;
outerRadius = 240;  // Outer edge
middleRadius = 170;  // Between major and minor
innerRadius = 100;   // Inner edge
```

### Key Methods

#### getSegmentPath(index, outerR, innerR): string
Generates SVG path for a wedge-shaped segment in the circle.

**Parameters**:
- `index`: Position in circle (0-11)
- `outerR`: Outer radius of segment
- `innerR`: Inner radius of segment

**Returns**: SVG path string for arc segment

#### selectKey(key: CircleOfFifthsKey)
Handles key selection and loads chord progression.

**Actions**:
1. Sets `selectedKey`
2. Calls `loadChordProgression()`
3. Updates UI to highlight selected segment

#### loadChordProgression(keyNote, scaleType)
Fetches diatonic chord progression from API.

**API Call**:
```typescript
GET ${apiUrl}/circle-of-fifths/progression/${keyNote}?scale_type=${scaleType}
```

## Usage Instructions

### For Users

1. **Select a key**: Click on any segment in the circle
   - Outer/middle ring: Major keys
   - Inner ring: Minor keys

2. **View key information**: Right panel shows:
   - Key name and description
   - Sharp/flat count
   - Relative major/minor
   - All seven diatonic chords

3. **Understand the circle**:
   - **Clockwise movement**: Adds sharps (C → G → D → A → E → B → F#)
   - **Counter-clockwise movement**: Adds flats (C → F → Bb → Eb → Ab → Db → Gb)
   - **Each position**: 5 semitones (perfect fifth) from previous
   - **Opposite sides**: Enharmonic equivalents (F# ≈ Gb, C# ≈ Db)

4. **Use chord progressions**:
   - Roman numerals indicate chord function
   - **I, IV, V**: Primary chords (strongest harmonic function)
   - **ii, iii, vi**: Secondary chords (color and movement)
   - **vii°**: Leading tone (dominant function)

### For Developers

#### Adding the Component

1. **Import component**:
```typescript
import { CircleOfFifthsComponent } from './components/circle-of-fifths.component';

@Component({
  imports: [CircleOfFifthsComponent, ...]
})
```

2. **Add to template**:
```html
<app-circle-of-fifths></app-circle-of-fifths>
```

#### Customizing Appearance

Modify component styles in `circle-of-fifths.component.ts`:

```typescript
// SVG dimensions
svgSize = 600;  // Increase circle size
center = 300;
outerRadius = 280;
middleRadius = 200;
innerRadius = 120;

// Segment colors (in template)
[attr.fill]="i >= 6 ? '#YOUR_COLOR' : '#YOUR_COLOR'"
```

## Music Theory Background

### Circle of Fifths Order
Moving clockwise by fifths (7 semitones each):

**Major Keys**: C → G → D → A → E → B → F# → (Db) → Ab → Eb → Bb → F → C

**Corresponding Sharps/Flats**:
- **C**: 0 (no sharps or flats)
- **G**: 1♯ (F#)
- **D**: 2♯ (F#, C#)
- **A**: 3♯ (F#, C#, G#)
- **E**: 4♯ (F#, C#, G#, D#)
- **B**: 5♯ (F#, C#, G#, D#, A#)
- **F#**: 6♯ (F#, C#, G#, D#, A#, E#)
- **F**: 1♭ (Bb)
- **Bb**: 2♭ (Bb, Eb)
- **Eb**: 3♭ (Bb, Eb, Ab)
- **Ab**: 4♭ (Bb, Eb, Ab, Db)
- **Db**: 5♭ (Bb, Eb, Ab, Db, Gb)
- **Gb**: 6♭ (Bb, Eb, Ab, Db, Gb, Cb)

### Relative Major/Minor
Each major key has a relative minor 3 semitones below:
- **C Major** ↔ **A Minor** (both have no sharps or flats)
- **G Major** ↔ **E Minor** (both have 1 sharp)
- **D Major** ↔ **B Minor** (both have 2 sharps)

### Diatonic Chord Formulas

**Major Keys (Ionian)**:
- I: Major (1, 3, 5)
- ii: Minor (2, 4, 6)
- iii: Minor (3, 5, 7)
- IV: Major (4, 6, 1)
- V: Major (5, 7, 2)
- vi: Minor (6, 1, 3)
- vii°: Diminished (7, 2, 4)

**Minor Keys (Aeolian/Natural Minor)**:
- i: Minor (1, ♭3, 5)
- ii°: Diminished (2, 4, ♭6)
- III: Major (♭3, 5, ♭7)
- iv: Minor (4, ♭6, 1)
- v: Minor (5, ♭7, 2)
- VI: Major (♭6, 1, ♭3)
- VII: Major (♭7, 2, 4)

## Testing

### Database Tests

Run tests in `infra/test-database.sql`:

```sql
-- Test DiatonicChordProgressions table
SELECT COUNT(*) FROM dbo.DiatonicChordProgressions;
-- Expected: 84+ (12 major keys × 7 chords = 84)

-- Test vw_CircleOfFifthsKeys view
SELECT COUNT(*) FROM dbo.vw_CircleOfFifthsKeys;
-- Expected: 24+ (12 major + 12 minor minimum)

-- Test C Major chord progression
SELECT * FROM dbo.DiatonicChordProgressions
WHERE KeyNote = 'C' AND ScaleTypeId = 1
ORDER BY DegreeNumber;
-- Expected: 7 chords (I, ii, iii, IV, V, vi, vii°)
```

### API Tests

```bash
# Test keys endpoint
curl http://localhost:8000/circle-of-fifths/keys

# Test major keys filter
curl "http://localhost:8000/circle-of-fifths/keys?scale_type=1"

# Test chord progression
curl "http://localhost:8000/circle-of-fifths/progression/C?scale_type=1"

# Test API documentation
curl http://localhost:8000/docs
```

### Frontend Tests

1. **Visual inspection**: Open frontend, click "Circle of Fifths" tab
2. **Key selection**: Click each major and minor key segment
3. **Chord display**: Verify 7 chords appear for each key
4. **Color coding**: Verify sharps (orange), flats (blue), minor (purple)
5. **Relative keys**: Verify correct relative major/minor displayed

## Deployment

### Database Updates

1. **Run schema update**:
```powershell
sqlcmd -S your-server.database.windows.net -d your-database -G -i setup-music-tables.sql
```

2. **Verify deployment**:
```powershell
sqlcmd -S your-server.database.windows.net -d your-database -G -i test-database.sql
```

### API Updates

No additional configuration needed. New endpoints are automatically available after deployment.

### Frontend Updates

1. **Build production**:
```powershell
npm run build:prod
```

2. **Deploy to Azure**:
```powershell
.\deploy-updates.ps1 -FrontendOnly
```

## Troubleshooting

### Issue: No keys appear in circle
**Cause**: API endpoint failing or CORS issue  
**Solution**: Check browser console for errors, verify API URL in config

### Issue: Chord progression not loading
**Cause**: Missing data in DiatonicChordProgressions table  
**Solution**: Run `setup-music-tables.sql` to populate data

### Issue: Wrong sharp/flat counts displayed
**Cause**: KeySignatures description parsing error  
**Solution**: Verify `vw_CircleOfFifthsKeys` CASE statement matches description format

### Issue: Circle segments not clickable
**Cause**: SVG path generation error  
**Solution**: Check browser console for SVG errors, verify `getSegmentPath()` logic

## Future Enhancements

1. **Chord substitutions**: Show common chord substitutions (e.g., vi for I)
2. **Modulation paths**: Highlight common modulation destinations
3. **Audio playback**: Play chord progressions
4. **Scale visualization**: Show scale notes when key selected
5. **Jazz progressions**: Add ii-V-I and other jazz progressions
6. **Harmonic analysis**: Analyze uploaded MIDI files
7. **Mode support**: Add Dorian, Phrygian, Lydian, Mixolydian modes
8. **Seventh chords**: Show diatonic seventh chords (Imaj7, iim7, etc.)

## References

- [Circle of Fifths User Guide](https://randscullard.com/CircleOfFifths/UserGuide.htm) - Inspiration for interactive features
- [Wikipedia: Circle of Fifths](https://en.wikipedia.org/wiki/Circle_of_fifths) - Music theory background
- [GrooveApp README](../README.md) - Project overview and deployment

---

**Last Updated**: January 2025  
**Version**: 1.0.0  
**Author**: GrooveApp Development Team
