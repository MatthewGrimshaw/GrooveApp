import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Component, OnInit } from '@angular/core';
import { ConfigService } from '../services/config.service';
import { LoggingService } from '../services/logging.service';

interface CircleOfFifthsKey {
  KeySignatureId: number;
  RootNote: string;
  ScaleTypeId: number;
  ScaleName: string;
  PreferredAccidental: string;
  Description: string;
  AccidentalCount: number;
  AccidentalType: string;
  CirclePosition: number;
  RelativeKey: string;
}

interface DiatonicChord {
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

@Component({
  selector: 'app-circle-of-fifths',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="circle-container">
      <h2>Interactive Circle of Fifths</h2>

      <div class="circle-wrapper">
        <!-- SVG Circle of Fifths -->
        <svg [attr.width]="svgSize" [attr.height]="svgSize" class="circle-svg">
          <!-- Outer ring background (sharps - right side) -->
          <path *ngFor="let key of majorKeys; let i = index"
                [attr.d]="getSegmentPath(i, outerRadius, middleRadius)"
                [attr.fill]="selectedKey?.RootNote === key.RootNote ? '#4CAF50' : (i >= 6 ? '#FFE0B2' : '#B3E5FC')"
                [attr.stroke]="'#333'"
                [attr.stroke-width]="2"
                (click)="selectKey(key)"
                class="segment clickable"
                [class.selected]="selectedKey?.RootNote === key.RootNote">
            <title>{{ key.RootNote }} {{ key.ScaleName }}</title>
          </path>

          <!-- Major key labels (middle ring) -->
          <text *ngFor="let key of majorKeys; let i = index"
                [attr.x]="getLabelX(i, middleRadius + 30)"
                [attr.y]="getLabelY(i, middleRadius + 30)"
                [attr.text-anchor]="'middle'"
                [attr.dominant-baseline]="'middle'"
                [attr.font-size]="18"
                [attr.font-weight]="selectedKey?.RootNote === key.RootNote ? 'bold' : 'normal'"
                [attr.fill]="'#000'"
                (click)="selectKey(key)"
                class="clickable">
            {{ key.RootNote }}
          </text>

          <!-- Sharp/Flat count labels (outer ring) -->
          <text *ngFor="let key of majorKeys; let i = index"
                [attr.x]="getLabelX(i, outerRadius - 20)"
                [attr.y]="getLabelY(i, outerRadius - 20)"
                [attr.text-anchor]="'middle'"
                [attr.dominant-baseline]="'middle'"
                [attr.font-size]="12"
                [attr.fill]="'#555'"
                class="accidental-label">
            {{ key.AccidentalCount > 0 ? key.AccidentalCount + (key.AccidentalType === 'Sharps' ? '♯' : '♭') : '' }}
          </text>

          <!-- Inner ring background (minor keys) -->
          <path *ngFor="let key of minorKeys; let i = index"
                [attr.d]="getSegmentPath(i, middleRadius, innerRadius)"
                [attr.fill]="selectedKey?.RootNote === key.RootNote && selectedKey?.ScaleTypeId === 2 ? '#8BC34A' : '#E1BEE7'"
                [attr.stroke]="'#333'"
                [attr.stroke-width]="2"
                (click)="selectKey(key)"
                class="segment clickable"
                [class.selected]="selectedKey?.RootNote === key.RootNote && selectedKey?.ScaleTypeId === 2">
            <title>{{ key.RootNote }} {{ key.ScaleName }}</title>
          </path>

          <!-- Minor key labels (inner ring) -->
          <text *ngFor="let key of minorKeys; let i = index"
                [attr.x]="getLabelX(i, (middleRadius + innerRadius) / 2)"
                [attr.y]="getLabelY(i, (middleRadius + innerRadius) / 2)"
                [attr.text-anchor]="'middle'"
                [attr.dominant-baseline]="'middle'"
                [attr.font-size]="14"
                [attr.font-weight]="selectedKey?.RootNote === key.RootNote && selectedKey?.ScaleTypeId === 2 ? 'bold' : 'normal'"
                [attr.fill]="'#000'"
                (click)="selectKey(key)"
                class="clickable">
            {{ key.RootNote }}m
          </text>

          <!-- Center circle -->
          <circle [attr.cx]="center" [attr.cy]="center" [attr.r]="innerRadius"
                  fill="#FFF" stroke="#333" stroke-width="2"/>

          <!-- Center text -->
          <text [attr.x]="center" [attr.y]="center - 10"
                text-anchor="middle" dominant-baseline="middle"
                font-size="16" font-weight="bold" fill="#333">
            Circle of
          </text>
          <text [attr.x]="center" [attr.y]="center + 15"
                text-anchor="middle" dominant-baseline="middle"
                font-size="16" font-weight="bold" fill="#333">
            Fifths
          </text>
        </svg>

        <!-- Key info panel -->
        <div class="key-info" *ngIf="selectedKey">
          <h3>{{ selectedKey.RootNote }} {{ selectedKey.ScaleName }}</h3>
          <p class="key-description">{{ selectedKey.Description }}</p>
          <p class="relative-key" *ngIf="selectedKey.RelativeKey">
            <strong>Relative {{ selectedKey.ScaleTypeId === 1 ? 'Minor' : 'Major' }}:</strong>
            {{ selectedKey.RelativeKey }}
          </p>

          <div class="chord-progression" *ngIf="chordProgression.length > 0">
            <h4>Diatonic Chords</h4>
            <div class="chords-grid">
              <div *ngFor="let chord of chordProgression" class="chord-card">
                <div class="roman-numeral">{{ chord.DegreeRomanNumeral }}</div>
                <div class="chord-symbol">{{ chord.ChordSymbol }}</div>
                <div class="chord-quality">{{ chord.ChordQuality }}</div>
                <div class="chord-desc">{{ chord.Description }}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="legend">
        <h4>Legend</h4>
        <div class="legend-item">
          <div class="color-box sharp"></div>
          <span>Sharp Keys (right side)</span>
        </div>
        <div class="legend-item">
          <div class="color-box flat"></div>
          <span>Flat Keys (left side)</span>
        </div>
        <div class="legend-item">
          <div class="color-box minor"></div>
          <span>Minor Keys (inner ring)</span>
        </div>
        <div class="legend-item">
          <div class="color-box c-natural"></div>
          <span>C Major / A Minor (no sharps/flats)</span>
        </div>
      </div>

      <div class="instructions">
        <h4>How to Use</h4>
        <ul>
          <li><strong>Click on any key</strong> to see its diatonic chord progression (I-ii-iii-IV-V-vi-vii°)</li>
          <li><strong>Outer ring:</strong> Major keys with sharp/flat counts</li>
          <li><strong>Inner ring:</strong> Relative minor keys</li>
          <li><strong>Moving clockwise:</strong> Each step adds one sharp (or removes one flat)</li>
          <li><strong>Moving counter-clockwise:</strong> Each step adds one flat (or removes one sharp)</li>
        </ul>
      </div>
    </div>
  `,
  styles: [`
    .circle-container {
      padding: 20px;
      max-width: 1200px;
      margin: 0 auto;
    }

    h2 {
      text-align: center;
      color: #333;
      margin-bottom: 20px;
    }

    .circle-wrapper {
      display: flex;
      gap: 30px;
      align-items: flex-start;
      margin-bottom: 30px;
    }

    .circle-svg {
      flex-shrink: 0;
      filter: drop-shadow(0 4px 6px rgba(0,0,0,0.1));
    }

    .segment {
      transition: all 0.3s ease;
    }

    .segment.clickable:hover {
      opacity: 0.8;
      cursor: pointer;
    }

    .segment.selected {
      filter: drop-shadow(0 0 8px rgba(0,0,0,0.4));
    }

    .clickable {
      cursor: pointer;
      user-select: none;
    }

    text.clickable:hover {
      font-weight: bold;
    }

    .accidental-label {
      pointer-events: none;
    }

    .key-info {
      flex: 1;
      background: #f5f5f5;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .key-info h3 {
      margin-top: 0;
      color: #2196F3;
      font-size: 24px;
    }

    .key-description {
      color: #666;
      font-style: italic;
      margin: 10px 0;
    }

    .relative-key {
      color: #555;
      margin: 10px 0;
      padding: 10px;
      background: #fff;
      border-radius: 4px;
      border-left: 3px solid #4CAF50;
    }

    .chord-progression {
      margin-top: 20px;
    }

    .chord-progression h4 {
      color: #333;
      margin-bottom: 15px;
      border-bottom: 2px solid #4CAF50;
      padding-bottom: 5px;
    }

    .chords-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
      gap: 15px;
    }

    .chord-card {
      background: white;
      padding: 15px;
      border-radius: 6px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      text-align: center;
      transition: transform 0.2s ease;
    }

    .chord-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 8px rgba(0,0,0,0.15);
    }

    .roman-numeral {
      font-size: 20px;
      font-weight: bold;
      color: #2196F3;
      margin-bottom: 5px;
    }

    .chord-symbol {
      font-size: 18px;
      font-weight: 600;
      color: #333;
      margin-bottom: 3px;
    }

    .chord-quality {
      font-size: 12px;
      color: #666;
      margin-bottom: 5px;
    }

    .chord-desc {
      font-size: 11px;
      color: #999;
      font-style: italic;
    }

    .legend {
      background: #f9f9f9;
      padding: 15px;
      border-radius: 8px;
      margin-bottom: 20px;
    }

    .legend h4 {
      margin-top: 0;
      color: #333;
    }

    .legend-item {
      display: flex;
      align-items: center;
      gap: 10px;
      margin: 8px 0;
    }

    .color-box {
      width: 30px;
      height: 20px;
      border: 1px solid #333;
      border-radius: 3px;
    }

    .color-box.sharp {
      background: #FFE0B2;
    }

    .color-box.flat {
      background: #B3E5FC;
    }

    .color-box.minor {
      background: #E1BEE7;
    }

    .color-box.c-natural {
      background: #fff;
    }

    .instructions {
      background: #E3F2FD;
      padding: 15px;
      border-radius: 8px;
      border-left: 4px solid #2196F3;
    }

    .instructions h4 {
      margin-top: 0;
      color: #1976D2;
    }

    .instructions ul {
      margin: 10px 0;
      padding-left: 20px;
    }

    .instructions li {
      margin: 8px 0;
      line-height: 1.6;
    }

    @media (max-width: 900px) {
      .circle-wrapper {
        flex-direction: column;
        align-items: center;
      }

      .chords-grid {
        grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
      }
    }
  `]
})
export class CircleOfFifthsComponent implements OnInit {
  majorKeys: CircleOfFifthsKey[] = [];
  minorKeys: CircleOfFifthsKey[] = [];
  selectedKey: CircleOfFifthsKey | null = null;
  chordProgression: DiatonicChord[] = [];

  // SVG dimensions
  svgSize = 500;
  center = 250;
  outerRadius = 240;
  middleRadius = 170;
  innerRadius = 100;

  private apiUrl: string;

  constructor(
    private http: HttpClient,
    private configService: ConfigService,
    private logger: LoggingService
  ) {
    this.apiUrl = this.configService.apiUrl;
  }

  ngOnInit() {
    this.loadKeys();
  }

  loadKeys() {
    this.logger.info('Circle of Fifths: Loading keys...');

    // Load major keys
    this.http.get<CircleOfFifthsKey[]>(`${this.apiUrl}/circle-of-fifths/keys?scale_type=1`)
      .subscribe({
        next: (keys) => {
          const keyList = keys.map(k => k.RootNote).join(', ');
          this.logger.info(`✓ Loaded ${keys.length} major keys: ${keyList}`);

          // Sort by CirclePosition
          const sorted = keys.sort((a, b) => a.CirclePosition - b.CirclePosition);

          // Filter to show only one enharmonic equivalent per position
          // Prefer sharps on right side (positions 1-6), flats on left side (7-11)
          this.majorKeys = [];
          const seenPositions = new Set<number>();

          for (const key of sorted) {
            if (!seenPositions.has(key.CirclePosition)) {
              seenPositions.add(key.CirclePosition);

              // For position 6 (F#/Gb), prefer the one with PreferredAccidental = 'sharp'
              if (key.CirclePosition === 6) {
                const alternatives = sorted.filter(k => k.CirclePosition === 6);
                const preferred = alternatives.find(k => k.PreferredAccidental === 'sharp') || alternatives[0];
                this.majorKeys.push(preferred);
              } else {
                this.majorKeys.push(key);
              }
            }
          }
        },
        error: (error) => {
          const status = error.status || 0;
          const message = error.error?.detail || error.message || 'Unknown error';
          this.logger.error(`✗ Failed to load major keys: [${status}] ${message}`);
          console.error('Full error details:', error);
        }
      });

    // Load minor keys - they should align with their relative majors
    this.http.get<CircleOfFifthsKey[]>(`${this.apiUrl}/circle-of-fifths/keys?scale_type=2`)
      .subscribe({
        next: (keys) => {
          const keyList = keys.map(k => k.RootNote).join(', ');
          this.logger.info(`✓ Loaded ${keys.length} minor keys: ${keyList}`);

          // Map minor keys to their relative major positions
          // A minor (relative of C major at position 0) should be at position 0
          // E minor (relative of G major at position 1) should be at position 1
          const relativeMap: { [key: string]: number } = {
            'A': 0,   // relative to C
            'E': 1,   // relative to G
            'B': 2,   // relative to D
            'F#': 3,  // relative to A
            'C#': 4,  // relative to E
            'G#': 5,  // relative to B
            'D#': 6,  // relative to F# (or Eb relative to Gb)
            'Eb': 6,  // relative to Gb
            'Bb': 7,  // relative to Db
            'F': 8,   // relative to Ab
            'C': 9,   // relative to Eb
            'G': 10,  // relative to Bb
            'D': 11   // relative to F
          };

          // Create array with 12 positions
          this.minorKeys = new Array(12);

          for (const key of keys) {
            const position = relativeMap[key.RootNote];
            if (position !== undefined) {
              // For position 6, prefer D# over Eb
              if (position === 6) {
                if (!this.minorKeys[6] || key.RootNote === 'D#') {
                  this.minorKeys[6] = key;
                }
              } else {
                this.minorKeys[position] = key;
              }
            }
          }

          // Filter out any undefined positions
          this.minorKeys = this.minorKeys.filter(k => k !== undefined);
          this.logger.info(`Circle of Fifths: ${this.minorKeys.length} minor keys positioned on circle`);
        },
        error: (error) => {
          const status = error.status || 0;
          const message = error.error?.detail || error.message || 'Unknown error';
          this.logger.error(`✗ Failed to load minor keys: [${status}] ${message}`);
          console.error('Full error details:', error);
        }
      });
  }

  selectKey(key: CircleOfFifthsKey) {
    this.selectedKey = key;
    this.logger.info(`Circle of Fifths: Selected ${key.RootNote} ${key.ScaleName}`);
    this.loadChordProgression(key.RootNote, key.ScaleTypeId);
  }

  loadChordProgression(keyNote: string, scaleType: number) {
    const url = `${this.apiUrl}/circle-of-fifths/progression/${encodeURIComponent(keyNote)}?scale_type=${scaleType}`;
    this.logger.info(`API Call: GET ${url}`);

    this.http.get<DiatonicChord[]>(url)
      .subscribe({
        next: (chords) => {
          this.chordProgression = chords;
          const chordList = chords.map(c => c.ChordSymbol).join(', ');
          this.logger.info(`✓ Received ${chords.length} chords for ${keyNote} (scale_type=${scaleType}): ${chordList}`);
        },
        error: (error) => {
          const status = error.status || 0;
          const message = error.error?.detail || error.message || 'Unknown error';
          this.logger.error(`✗ Failed to load chord progression for ${keyNote}: [${status}] ${message}`);
          console.error('Full error details:', error);
          this.chordProgression = [];
        }
      });
  }

  /**
   * Generate SVG path for a segment of the circle
   * @param index Position in the circle (0-11)
   * @param outerR Outer radius
   * @param innerR Inner radius
   */
  getSegmentPath(index: number, outerR: number, innerR: number): string {
    const angleStep = 360 / 12;
    const startAngle = index * angleStep - 90; // Start at top (12 o'clock)
    const endAngle = (index + 1) * angleStep - 90;

    const x1Outer = this.center + outerR * Math.cos(this.degreesToRadians(startAngle));
    const y1Outer = this.center + outerR * Math.sin(this.degreesToRadians(startAngle));
    const x2Outer = this.center + outerR * Math.cos(this.degreesToRadians(endAngle));
    const y2Outer = this.center + outerR * Math.sin(this.degreesToRadians(endAngle));

    const x1Inner = this.center + innerR * Math.cos(this.degreesToRadians(startAngle));
    const y1Inner = this.center + innerR * Math.sin(this.degreesToRadians(startAngle));
    const x2Inner = this.center + innerR * Math.cos(this.degreesToRadians(endAngle));
    const y2Inner = this.center + innerR * Math.sin(this.degreesToRadians(endAngle));

    // Create path: outer arc -> line -> inner arc (reverse) -> close
    return `
      M ${x1Outer} ${y1Outer}
      A ${outerR} ${outerR} 0 0 1 ${x2Outer} ${y2Outer}
      L ${x2Inner} ${y2Inner}
      A ${innerR} ${innerR} 0 0 0 ${x1Inner} ${y1Inner}
      Z
    `;
  }

  /**
   * Get X coordinate for label at given position
   */
  getLabelX(index: number, radius: number): number {
    const angleStep = 360 / 12;
    const angle = index * angleStep - 90 + (angleStep / 2); // Center in middle of segment
    return this.center + radius * Math.cos(this.degreesToRadians(angle));
  }

  /**
   * Get Y coordinate for label at given position
   */
  getLabelY(index: number, radius: number): number {
    const angleStep = 360 / 12;
    const angle = index * angleStep - 90 + (angleStep / 2); // Center in middle of segment
    return this.center + radius * Math.sin(this.degreesToRadians(angle));
  }

  /**
   * Convert degrees to radians
   */
  private degreesToRadians(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}
