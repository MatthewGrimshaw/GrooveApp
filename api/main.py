"""
GrooveApp Music Theory API
FastAPI application for querying music theory data from Azure SQL Database
"""
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import pyodbc
import os
import subprocess
import json
import shutil
from pydantic import BaseModel
from azure.identity import DefaultAzureCredential
import struct

# Helper function to fix Unicode decoding issues with pyodbc
def fix_unicode(s):
    """Fix Unicode characters that pyodbc may have decoded incorrectly"""
    if s is None:
        return None
    if isinstance(s, str):
        # pyodbc with ODBC Driver 18 sometimes fails to decode certain Unicode characters
        # from SQL Server NVARCHAR columns, replacing them with '?'
        # We know the only special character should be the flat symbol ♭ (U+266D)
        # Workaround: replace the malformed character with the correct Unicode
        if '?' in s and len(s) > 1:
            # Likely a roman numeral with flat: ?II, ?III, ?V, ?VI, ?VII
            return s.replace('?', '♭')
        return s
    return s

# Models
class Note(BaseModel):
    NoteId: int
    NoteName: str
    EnharmonicEquivalent: Optional[str]
    SemitonesFromC: int
    IsNatural: bool
    IsSharp: bool
    IsFlat: bool

class ScaleNote(BaseModel):
    DegreeNumber: int
    ScaleDegree: Optional[str]
    Note: str
    SemitonesFromRoot: int
    IntervalName: Optional[str]
    RomanNumeral: Optional[str]
    ScaleName: str

class ScaleType(BaseModel):
    ScaleTypeId: int
    ScaleName: str
    IntervalPattern: str
    Description: Optional[str]

class ChordType(BaseModel):
    ChordTypeId: int
    ChordName: str
    ChordSymbol: str
    IntervalPattern: str
    Description: Optional[str]

class ArpeggioNote(BaseModel):
    NotePosition: int
    ChordTone: Optional[str]
    Note: Optional[str]
    SemitonesFromRoot: int
    IntervalName: Optional[str]
    RomanNumeral: Optional[str]
    ChordName: str
    ChordSymbol: str
    FullChordSymbol: str

class Interval(BaseModel):
    IntervalId: int
    IntervalName: str
    Semitones: int
    ShortName: str
    RomanNumeral: str
    Description: Optional[str]

class ChordExtension(BaseModel):
    ExtensionId: int
    ChordTypeId: int
    ExtensionName: str
    ExtensionSymbol: str
    Semitones: int
    Description: Optional[str]
    IsCommonInJazz: bool
    DisplayOrder: int
    Note: Optional[str] = None

class NoteInterval(BaseModel):
    FromNote: str
    ToNote: str
    Semitones: int
    IntervalName: Optional[str]
    IntervalShortName: Optional[str]

# FastAPI app
app = FastAPI(
    title="GrooveApp Music Theory API",
    description="REST API for music theory queries including scales, chords, and intervals",
    version="1.0.0"
)

# CORS middleware
# Allow both localhost (development) and Azure frontend (production)
allowed_origins = [
    "http://localhost:8080",
    "http://localhost:4200",
    os.environ.get("FRONTEND_URL", "https://webapp-grooveapp-frontend.azurewebsites.net")
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection
def get_access_token():
    """Get access token using DefaultAzureCredential (Azure) or environment variable (local)"""
    # Check for environment variable first (best for local Docker testing)
    token = os.environ.get('AZURE_ACCESS_TOKEN')
    if token:
        return token
    
    try:
        # Use DefaultAzureCredential (works in Azure with managed identity)
        credential = DefaultAzureCredential()
        token_obj = credential.get_token("https://database.windows.net/.default")
        return token_obj.token
    except Exception as e:
        raise Exception(f"Failed to get access token. Either set AZURE_ACCESS_TOKEN environment variable or configure managed identity: {str(e)}")

def get_db_connection():
    """Create database connection using Entra ID authentication"""
    server = os.environ.get('SQL_SERVER', 'sql-grooveapp.database.windows.net')
    database = os.environ.get('SQL_DATABASE', 'db-grooveapp')
    
    try:
        # Get access token
        access_token = get_access_token()
        
        # Encode token for SQL Server
        token_bytes = access_token.encode('UTF-16-LE')
        token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)
        
        # Connect using ODBC Driver 18 (or 17) with access token attribute
        # Try Driver 18 first, fall back to 17
        drivers = ['ODBC Driver 18 for SQL Server', 'ODBC Driver 17 for SQL Server']
        conn = None
        
        for driver in drivers:
            try:
                conn_str = f'DRIVER={{{driver}}};SERVER={server};DATABASE={database};Encrypt=yes'
                # SQL_COPT_SS_ACCESS_TOKEN = 1256
                conn = pyodbc.connect(conn_str, attrs_before={1256: token_struct})
                break
            except pyodbc.Error:
                continue
        
        if not conn:
            raise Exception("Could not connect with ODBC Driver 17 or 18")
            
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

# Health check
@app.get("/", tags=["Health"])
async def root():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "GrooveApp Music Theory API",
        "version": "1.0.0"
    }

@app.get("/health", tags=["Health"])
async def health_check():
    """Comprehensive health check with detailed diagnostics"""
    import time
    from datetime import datetime, timedelta
    
    start_time = time.time()
    health_response = {
        "status": "healthy",
        "database": "connected",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "responseTimeMs": 0,
        "checks": {}
    }
    
    # Database connectivity check
    try:
        db_start = time.time()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        db_time = (time.time() - db_start) * 1000
        
        health_response["checks"]["database"] = {
            "status": "healthy",
            "responseTimeMs": round(db_time, 2)
        }
    except Exception as e:
        health_response["status"] = "unhealthy"
        health_response["database"] = "disconnected"
        health_response["checks"]["database"] = {
            "status": "unhealthy",
            "error": str(e),
            "errorType": type(e).__name__
        }
    
    # Azure token check
    try:
        token = os.environ.get('AZURE_ACCESS_TOKEN')
        if token:
            health_response["checks"]["authentication"] = {
                "status": "healthy",
                "method": "environment_token",
                "note": "Token expiration monitoring not available with environment variable"
            }
        else:
            # Try to get token expiry from DefaultAzureCredential
            try:
                from azure.identity import DefaultAzureCredential
                credential = DefaultAzureCredential()
                token_obj = credential.get_token("https://database.windows.net/.default")
                # Token objects don't expose expiry directly, but tokens typically last 1 hour
                health_response["checks"]["authentication"] = {
                    "status": "healthy",
                    "method": "managed_identity",
                    "note": "Azure AD token obtained successfully"
                }
            except Exception as auth_error:
                health_response["checks"]["authentication"] = {
                    "status": "warning",
                    "method": "unknown",
                    "error": str(auth_error)
                }
    except Exception as e:
        health_response["checks"]["authentication"] = {
            "status": "warning",
            "error": str(e)
        }
    
    # Calculate total response time
    health_response["responseTimeMs"] = round((time.time() - start_time) * 1000, 2)
    
    # Return appropriate status code
    if health_response["status"] == "unhealthy":
        raise HTTPException(status_code=503, detail=health_response)
    
    return health_response

# Notes endpoints
@app.get("/notes", response_model=List[Note], tags=["Notes"])
async def get_notes():
    """Get all musical notes"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.Notes ORDER BY SemitonesFromC")
        
        notes = []
        for row in cursor.fetchall():
            notes.append(Note(
                NoteId=row[0],
                NoteName=row[1],
                EnharmonicEquivalent=row[2],
                SemitonesFromC=row[3],
                IsNatural=bool(row[4]),
                IsSharp=bool(row[5]),
                IsFlat=bool(row[6])
            ))
        
        cursor.close()
        conn.close()
        return notes
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Intervals endpoints
@app.get("/intervals", response_model=List[Interval], tags=["Intervals"])
async def get_intervals():
    """Get all musical intervals"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.Intervals ORDER BY Semitones")
        
        intervals = []
        for row in cursor.fetchall():
            intervals.append(Interval(
                IntervalId=row[0],
                IntervalName=row[1],
                Semitones=row[2],
                ShortName=row[3],
                RomanNumeral=fix_unicode(row[4]),
                Description=row[5]
            ))
        
        cursor.close()
        conn.close()
        return intervals
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/intervals/{from_note}", response_model=List[NoteInterval], tags=["Intervals"])
async def get_intervals_from_note(from_note: str):
    """Get all intervals from a specific note"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT * FROM dbo.vw_NoteIntervals 
            WHERE FromNote = ? 
            ORDER BY Semitones
        """, from_note)
        
        intervals = []
        for row in cursor.fetchall():
            intervals.append(NoteInterval(
                FromNote=row[0],
                ToNote=row[1],
                Semitones=row[2],
                IntervalName=row[3],
                IntervalShortName=row[4]
            ))
        
        cursor.close()
        conn.close()
        return intervals
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Scale endpoints
@app.get("/scales", response_model=List[ScaleType], tags=["Scales"])
async def get_scale_types():
    """Get all scale types"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.ScaleTypes ORDER BY ScaleTypeId")
        
        scales = []
        for row in cursor.fetchall():
            scales.append(ScaleType(
                ScaleTypeId=row[0],
                ScaleName=row[1],
                IntervalPattern=row[2],
                Description=row[3]
            ))
        
        cursor.close()
        conn.close()
        return scales
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/scales/{root_note}/{scale_type_id}", response_model=List[ScaleNote], tags=["Scales"])
async def generate_scale(root_note: str, scale_type_id: int):
    """Generate a scale from a root note and scale type
    
    Examples:
    - /scales/C/1 - C Major
    - /scales/A/2 - A Natural Minor
    - /scales/Db/1 - Db Major
    - /scales/G/8 - G Mixolydian
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.fn_GenerateScale(?, ?)", root_note, scale_type_id)
        
        scale_notes = []
        for row in cursor.fetchall():
            scale_notes.append(ScaleNote(
                DegreeNumber=row[0],
                ScaleDegree=row[1],
                Note=row[2],
                SemitonesFromRoot=row[3],
                IntervalName=row[4],
                RomanNumeral=fix_unicode(row[5]),
                ScaleName=row[6]
            ))
        
        cursor.close()
        conn.close()
        
        if not scale_notes:
            raise HTTPException(status_code=404, detail=f"Scale not found for {root_note} with type {scale_type_id}")
        
        return scale_notes
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Chord/Arpeggio endpoints
@app.get("/chords", response_model=List[ChordType], tags=["Chords"])
async def get_chord_types():
    """Get all chord types"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.ChordTypes ORDER BY ChordTypeId")
        
        chords = []
        for row in cursor.fetchall():
            chords.append(ChordType(
                ChordTypeId=row[0],
                ChordName=row[1],
                ChordSymbol=row[2],
                IntervalPattern=row[3],
                Description=row[4]
            ))
        
        cursor.close()
        conn.close()
        return chords
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/chords/{chord_type_id}/extensions", response_model=List[ChordExtension], tags=["Chords"])
async def get_chord_extensions(chord_type_id: int, root_note: Optional[str] = None):
    """Get available Jazz extensions for a specific chord type, optionally with actual notes calculated from root"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT ExtensionId, ChordTypeId, ExtensionName, ExtensionSymbol, 
                   Semitones, Description, IsCommonInJazz, DisplayOrder
            FROM dbo.ChordExtensions
            WHERE ChordTypeId = ? AND IsCommonInJazz = 1
            ORDER BY DisplayOrder, Semitones
        """, (chord_type_id,))
        
        extensions = []
        for row in cursor.fetchall():
            note = None
            if root_note:
                # Calculate the actual note for this extension
                note_cursor = conn.cursor()
                note_cursor.execute("""
                    SELECT TOP 1 NoteName
                    FROM dbo.Notes
                    WHERE SemitonesFromC = (
                        (SELECT SemitonesFromC FROM dbo.Notes WHERE NoteName = ?) + ?
                    ) % 12
                    AND (IsSharp = 1 OR IsNatural = 1)
                    ORDER BY IsNatural DESC, IsSharp DESC
                """, (root_note, row[4]))  # row[4] is Semitones
                note_row = note_cursor.fetchone()
                if note_row:
                    note = note_row[0]
                note_cursor.close()
            
            extensions.append(ChordExtension(
                ExtensionId=row[0],
                ChordTypeId=row[1],
                ExtensionName=row[2],
                ExtensionSymbol=row[3],
                Semitones=row[4],
                Description=row[5],
                IsCommonInJazz=bool(row[6]),
                DisplayOrder=row[7],
                Note=note
            ))
        
        cursor.close()
        conn.close()
        return extensions
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/arpeggios/{root_note}/{chord_type_id}", response_model=List[ArpeggioNote], tags=["Chords"])
async def generate_arpeggio(root_note: str, chord_type_id: int):
    """Generate an arpeggio from a root note and chord type
    
    Examples:
    - /arpeggios/C/5 - C Major 7
    - /arpeggios/D/6 - D Minor 7
    - /arpeggios/G/7 - G Dominant 7
    - /arpeggios/B/8 - B Half Diminished
    - /arpeggios/F/16 - F Dominant 7b9
    - /arpeggios/A/22 - A Dominant 13
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM dbo.fn_GenerateArpeggio(?, ?)", root_note, chord_type_id)
        
        arpeggio_notes = []
        for row in cursor.fetchall():
            arpeggio_notes.append(ArpeggioNote(
                NotePosition=row[0],
                ChordTone=row[1],
                Note=row[2],
                SemitonesFromRoot=row[3],
                IntervalName=row[4],
                RomanNumeral=fix_unicode(row[5]),
                ChordName=row[6],
                ChordSymbol=row[7],
                FullChordSymbol=row[8]
            ))
        
        cursor.close()
        conn.close()
        
        if not arpeggio_notes:
            raise HTTPException(status_code=404, detail=f"Arpeggio not found for {root_note} with type {chord_type_id}")
        
        return arpeggio_notes
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
