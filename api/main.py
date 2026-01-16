"""
GrooveApp Music Theory API
FastAPI application for querying music theory data from Azure SQL Database
"""
from fastapi import FastAPI, HTTPException, Query, Request
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

# Import logging configuration
from logging_config import configure_logging, create_audit_log
from logging_middleware import RequestLoggingMiddleware, DatabaseLoggingMiddleware

# Initialize logger
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')  # OFF, ERROR, WARNING, INFO/ON, VERBOSE/DEBUG
APPLICATIONINSIGHTS_CONNECTION_STRING = os.getenv('APPLICATIONINSIGHTS_CONNECTION_STRING')

logger = configure_logging(
    app_insights_connection_string=APPLICATIONINSIGHTS_CONNECTION_STRING,
    log_level=LOG_LEVEL,
    service_name='grooveapp-api'
)

# Helper function to fix Unicode decoding issues with pyodbc
def fix_unicode(s):
    """Fix Unicode characters that pyodbc may have decoded incorrectly"""
    if s is None:
        return None
    if isinstance(s, str):
        # pyodbc with ODBC Driver 18 sometimes fails to decode certain Unicode characters
        # from SQL Server NVARCHAR columns, replacing them with '?'
        # We know the special characters should be:
        # - flat symbol ♭ (U+266D)
        # - sharp symbol # (ASCII 0x23) or ♯ (U+266F)
        # - degree symbol ° (U+00B0)
        
        # Replace malformed character with flat symbol
        if '?' in s and len(s) > 1:
            # Likely a roman numeral with flat: ?II, ?III, ?V, ?VI, ?VII
            return s.replace('?', '♭')
        
        # Fix corrupted degree symbol: The database stores UTF-8 bytes (C2 B0) as Latin-1 characters
        # When read back, C2 appears as 'Â' and B0 as '°', resulting in 'Â°'
        # Replace 'Â°' with proper degree symbol '°'
        if 'Â°' in s:
            s = s.replace('Â°', '°')
        
        # Note: Sharp (#) is standard ASCII and should not need fixing
        # But we'll ensure it's preserved
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

class CircleOfFifthsKey(BaseModel):
    KeySignatureId: int
    RootNote: str
    ScaleTypeId: int
    ScaleName: str
    PreferredAccidental: str
    Description: Optional[str]
    AccidentalCount: int
    AccidentalType: str
    CirclePosition: int
    RelativeKey: Optional[str]

class DiatonicChord(BaseModel):
    ProgressionId: int
    KeyNote: str
    ScaleTypeId: int
    DegreeNumber: int
    DegreeRomanNumeral: str
    ChordRoot: str
    ChordQuality: str
    ChordSymbol: str
    IntervalFromTonic: int
    Description: Optional[str]

# FastAPI app
app = FastAPI(
    title="GrooveApp Music Theory API",
    description="REST API for music theory queries including scales, chords, and intervals",
    version="1.0.0"
)

# Add request logging middleware
app.add_middleware(RequestLoggingMiddleware, logger=logger)

# CORS middleware
# Allow both localhost (development) and Azure frontend (production)
allowed_origins = [
    "http://localhost:8080",
    "http://localhost:4200",
    "http://host.docker.internal:8080",  # Docker container accessing host
    os.environ.get("FRONTEND_URL", "https://webapp-grooveapp-frontend.azurewebsites.net")
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

logger.info(
    "API startup complete",
    extra={
        'operation_id': 'startup',
        'request_path': '/startup',
        'log_level': LOG_LEVEL,
        'app_insights_enabled': bool(APPLICATIONINSIGHTS_CONNECTION_STRING)
    }
)

# Database connection
def get_access_token():
    """Get access token using ManagedIdentityCredential (Azure) or DefaultAzureCredential (local)"""
    import base64
    import json
    
    # Check for environment variable first (explicit token for local Docker testing)
    token = os.environ.get('AZURE_ACCESS_TOKEN')
    if token:
        logger.info("Using AZURE_ACCESS_TOKEN environment variable")
        return token
    
    try:
        # Try ManagedIdentityCredential first (best for Azure App Service)
        from azure.identity import ManagedIdentityCredential
        credential = ManagedIdentityCredential()
        token_obj = credential.get_token("https://database.windows.net/.default")
        
        # Decode token to see which principal it's for (for debugging)
        try:
            # JWT tokens have 3 parts: header.payload.signature
            token_parts = token_obj.token.split('.')
            if len(token_parts) >= 2:
                # Decode payload (add padding if needed)
                payload = token_parts[1]
                padding = 4 - len(payload) % 4
                if padding != 4:
                    payload += '=' * padding
                decoded = base64.urlsafe_b64decode(payload)
                token_info = json.loads(decoded)
                principal_name = token_info.get('appid', token_info.get('oid', 'unknown'))
                logger.info(f"Acquired token for principal: {token_info.get('app_displayname', principal_name)} (oid: {token_info.get('oid', 'N/A')})")
        except Exception as decode_error:
            logger.warning(f"Could not decode token for debugging: {decode_error}")
        
        return token_obj.token
    except Exception as managed_identity_error:
        logger.warning(f"ManagedIdentityCredential failed: {managed_identity_error}")
        # Fall back to DefaultAzureCredential for local development
        # This tries Azure CLI, VS Code, Environment Variables, etc.
        try:
            credential = DefaultAzureCredential()
            token_obj = credential.get_token("https://database.windows.net/.default")
            logger.info("Using DefaultAzureCredential fallback")
            return token_obj.token
        except Exception as default_cred_error:
            raise Exception(
                f"Failed to get access token using both ManagedIdentityCredential and DefaultAzureCredential.\n\n"
                f"ManagedIdentityCredential error: {str(managed_identity_error)}\n"
                f"DefaultAzureCredential error: {str(default_cred_error)}\n\n"
                f"For Azure App Service: Make sure system-assigned managed identity is enabled.\n"
                f"For local development: Run 'az login' or set AZURE_ACCESS_TOKEN environment variable."
            )

def get_db_connection(timeout_seconds=30):
    """Create database connection using Entra ID authentication
    
    Args:
        timeout_seconds: Connection timeout in seconds (default: 30)
    """
    server = os.environ.get('SQL_SERVER')
    database = os.environ.get('SQL_DATABASE')
    
    if not server or not database:
        raise ValueError("SQL_SERVER and SQL_DATABASE environment variables must be set")
    
    try:
        # Get access token
        access_token = get_access_token()
        
        # Encode token for SQL Server
        token_bytes = access_token.encode('UTF-16-LE')
        token_struct = struct.pack(f'<I{len(token_bytes)}s', len(token_bytes), token_bytes)
        
        # Connect using ODBC Driver 18 with access token attribute
        try:
            driver = 'ODBC Driver 18 for SQL Server'
            conn_str = f'DRIVER={{{driver}}};SERVER={server};DATABASE={database};Encrypt=yes;Connection Timeout={timeout_seconds}'
            # SQL_COPT_SS_ACCESS_TOKEN = 1256
            conn = pyodbc.connect(conn_str, attrs_before={1256: token_struct})
            return conn
        except pyodbc.Error as e:
            error_code = e.args[0] if e.args else 'Unknown'
            error_msg = e.args[1] if len(e.args) > 1 else str(e)
            
            # Provide helpful error messages for common issues
            if error_code == '28000' and 'Login failed' in error_msg:
                # Determine if it's a token expiration or permission issue
                if 'Token is expired' in error_msg:
                    raise Exception(
                        f"Database authentication failed: {error_msg}\n\n"
                        "The Azure AD access token has expired.\n\n"
                        "To fix this:\n"
                        "1. Restart the API web app to get a fresh managed identity token\n"
                        "2. Or for local development: az login"
                    )
                else:
                    # Parse the token to determine which principal failed to authenticate
                    principal_info = "the web app's managed identity"
                    try:
                        import base64, json
                        token_parts = access_token.split('.')
                        if len(token_parts) >= 2:
                            payload = token_parts[1]
                            padding = 4 - len(payload) % 4
                            if padding != 4:
                                payload += '=' * padding
                            decoded = base64.urlsafe_b64decode(payload)
                            token_info = json.loads(decoded)
                            # Check if it's a user token or service principal token
                            if token_info.get('upn'):  # User Principal Name = user token
                                principal_info = f"user {token_info.get('upn')}"
                            elif token_info.get('app_displayname'):  # App display name = managed identity
                                principal_info = f"managed identity '{token_info.get('app_displayname')}'"
                            elif token_info.get('oid'):
                                principal_info = f"principal (OID: {token_info.get('oid')})"
                    except Exception:
                        pass  # Use default principal_info
                    
                    raise Exception(
                        f"Database authentication failed for {principal_info}: {error_msg}\n\n"
                        "The database principal doesn't have permission to access this database.\n\n"
                        "Possible fixes:\n"
                        "1. For managed identity issues: Re-run Terraform to recreate database users:\n"
                        "   cd infra/terraform && terraform apply -var-file=environments/dev.tfvars\n\n"
                        "2. For local development (user authentication):\n"
                        "   - Get your email: az ad signed-in-user show --query userPrincipalName -o tsv\n"
                        "   - Edit infra/setup-music-tables.sql and set @DeveloperEmail to your email\n"
                        "   - Run: sqlcmd -S {server} -d {database} -G -i infra/setup-music-tables.sql"
                    )
            else:
                raise Exception(f"Database connection failed ({error_code}): {error_msg}")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

# Health check
@app.get("/", tags=["Health"])
async def root(request: Request):
    """Health check endpoint"""
    logger.info(
        "Root endpoint accessed",
        extra={
            'operation_id': getattr(request.state, 'operation_id', 'N/A'),
            'user_id': getattr(request.state, 'user_id', 'anonymous'),
            'request_path': '/'
        }
    )
    return {
        "status": "healthy",
        "service": "GrooveApp Music Theory API",
        "version": "1.0.0"
    }

@app.get("/health", tags=["Health"])
async def health_check(request: Request):
    """Comprehensive health check with detailed diagnostics"""
    import time
    from datetime import datetime, timedelta
    
    start_time = time.time()
    operation_id = getattr(request.state, 'operation_id', 'N/A')
    
    health_response = {
        "status": "healthy",
        "database": "connected",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "responseTimeMs": 0,
        "checks": {}
    }
    
    # Database connectivity check with retry logic
    db_healthy = False
    db_error_msg = None
    max_retries = 3
    retry_delay = 1  # Start with 1 second
    db_timeout = 10  # 10 second timeout per attempt
    
    for attempt in range(max_retries):
        try:
            db_start = time.time()
            
            with DatabaseLoggingMiddleware(logger, f"Health check DB connection (attempt {attempt + 1}/{max_retries})", request):
                conn = get_db_connection(timeout_seconds=db_timeout)
                cursor = conn.cursor()
                cursor.execute("SELECT 1")
                cursor.close()
                conn.close()
                
            db_time = (time.time() - db_start) * 1000
            
            health_response["checks"]["database"] = {
                "status": "healthy",
                "responseTimeMs": round(db_time, 2),
                "attempts": attempt + 1
            }
            
            db_healthy = True
            
            logger.debug(
                "Health check database check passed",
                extra={
                    'operation_id': operation_id,
                    'user_id': 'system',
                    'request_path': '/health',
                    'duration_ms': round(db_time, 2),
                    'attempts': attempt + 1
                }
            )
            break  # Success, exit retry loop
            
        except Exception as e:
            db_error_msg = str(e)
            
            # Check if this is a timeout error (likely VNet integration not ready)
            is_timeout = 'timeout' in str(e).lower() or 'HYT00' in str(e)
            
            if attempt < max_retries - 1 and is_timeout:
                logger.warning(
                    f"Health check database connection attempt {attempt + 1} failed (timeout), retrying in {retry_delay}s",
                    extra={
                        'operation_id': operation_id,
                        'user_id': 'system',
                        'request_path': '/health',
                        'error': str(e),
                        'attempt': attempt + 1
                    }
                )
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff
            else:
                logger.error(
                    f"Health check database connection failed after {attempt + 1} attempts: {str(e)}",
                    extra={
                        'operation_id': operation_id,
                        'user_id': 'system',
                        'request_path': '/health',
                        'error': str(e),
                        'attempts': attempt + 1
                    },
                    exc_info=(attempt == max_retries - 1)  # Only log full stack trace on final attempt
                )
                break
    
    # Handle database check failure - mark as degraded but still return 200 OK
    # This allows the app to be considered healthy during startup while VNet integration establishes
    if not db_healthy:
        health_response["status"] = "degraded"  # Changed from "unhealthy" to allow startup
        health_response["database"] = "disconnected"
        health_response["checks"]["database"] = {
            "status": "unhealthy",
            "error": db_error_msg,
            "attempts": max_retries,
            "note": "Database may be unreachable during VNet integration setup. Service will retry."
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

# Circle of Fifths endpoints
@app.get("/circle-of-fifths/keys", response_model=List[CircleOfFifthsKey], tags=["Circle of Fifths"])
async def get_circle_of_fifths_keys(scale_type: Optional[int] = Query(None, description="Filter by scale type (1=Major, 2=Minor)")):
    """Get all keys in the Circle of Fifths with sharp/flat counts and relative keys
    
    Examples:
    - /circle-of-fifths/keys - All major and minor keys
    - /circle-of-fifths/keys?scale_type=1 - Major keys only
    - /circle-of-fifths/keys?scale_type=2 - Minor keys only
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        if scale_type:
            query = """
                SELECT KeySignatureId, RootNote, ScaleTypeId, ScaleName, PreferredAccidental, 
                       Description, AccidentalCount, AccidentalType, CirclePosition, RelativeKey
                FROM dbo.vw_CircleOfFifthsKeys
                WHERE ScaleTypeId = ?
                ORDER BY CirclePosition
            """
            cursor.execute(query, scale_type)
        else:
            query = """
                SELECT KeySignatureId, RootNote, ScaleTypeId, ScaleName, PreferredAccidental, 
                       Description, AccidentalCount, AccidentalType, CirclePosition, RelativeKey
                FROM dbo.vw_CircleOfFifthsKeys
                ORDER BY ScaleTypeId, CirclePosition
            """
            cursor.execute(query)
        
        keys = []
        for row in cursor.fetchall():
            keys.append(CircleOfFifthsKey(
                KeySignatureId=row[0],
                RootNote=row[1],
                ScaleTypeId=row[2],
                ScaleName=row[3],
                PreferredAccidental=row[4],
                Description=row[5],
                AccidentalCount=row[6],
                AccidentalType=row[7],
                CirclePosition=row[8],
                RelativeKey=row[9]
            ))
        
        cursor.close()
        conn.close()
        return keys
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/circle-of-fifths/progression/{key_note}", response_model=List[DiatonicChord], tags=["Circle of Fifths"])
async def get_chord_progression(
    key_note: str, 
    scale_type: int = Query(1, description="Scale type (1=Major, 2=Minor)")
):
    """Get the diatonic chord progression for a key (I-ii-iii-IV-V-vi-vii° for major)
    
    Examples:
    - /circle-of-fifths/progression/C?scale_type=1 - C Major: C, Dm, Em, F, G, Am, B°
    - /circle-of-fifths/progression/A?scale_type=2 - A Minor: Am, B°, C, Dm, Em, F, G
    - /circle-of-fifths/progression/G?scale_type=1 - G Major: G, Am, Bm, C, D, Em, F#°
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT ProgressionId, KeyNote, ScaleTypeId, DegreeNumber, DegreeRomanNumeral,
                   ChordRoot, ChordQuality, ChordSymbol, IntervalFromTonic, Description
            FROM dbo.DiatonicChordProgressions
            WHERE KeyNote = ? AND ScaleTypeId = ?
            ORDER BY DegreeNumber
        """, key_note, scale_type)
        
        chords = []
        for row in cursor.fetchall():
            chords.append(DiatonicChord(
                ProgressionId=row[0],
                KeyNote=fix_unicode(row[1]),
                ScaleTypeId=row[2],
                DegreeNumber=row[3],
                DegreeRomanNumeral=fix_unicode(row[4]),
                ChordRoot=fix_unicode(row[5]),
                ChordQuality=row[6],
                ChordSymbol=fix_unicode(row[7]),
                IntervalFromTonic=row[8],
                Description=row[9]
            ))
        
        cursor.close()
        conn.close()
        
        if not chords:
            raise HTTPException(status_code=404, detail=f"Chord progression not found for {key_note} with scale type {scale_type}")
        
        return chords
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
