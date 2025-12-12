import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';

interface NotePosition {
  note: string;
  x: number;
  y: number;
  ledgerLines: number[]; // Y positions of ledger lines if needed
  accidental?: 'sharp' | 'flat' | 'natural';
}

@Component({
  selector: 'app-musical-staff',
  standalone: true,
  imports: [CommonModule],
  template: `
    <svg [attr.width]="width" [attr.height]="height" class="musical-staff">
      <!-- Staff lines -->
      <g class="staff-lines">
        <line *ngFor="let y of staffLines"
              [attr.x1]="margins.left"
              [attr.y1]="y"
              [attr.x2]="width - margins.right"
              [attr.y2]="y"
              stroke="#000"
              stroke-width="1.5"/>
      </g>

      <!-- Treble clef -->
      <g class="treble-clef">
        <text [attr.x]="margins.left + 5"
              [attr.y]="staffLines[3] + 5"
              font-family="'Bravura', 'Gonville', 'Emmentaler', serif"
              font-size="85"
              fill="#000">𝄞</text>
      </g>

      <!-- Ledger lines -->
      <g class="ledger-lines">
        <ng-container *ngFor="let notePos of notePositions">
          <line *ngFor="let ledgerY of notePos.ledgerLines"
                [attr.x1]="notePos.x - 15"
                [attr.y1]="ledgerY"
                [attr.x2]="notePos.x + 15"
                [attr.y2]="ledgerY"
                stroke="#000"
                stroke-width="1.5"/>
        </ng-container>
      </g>

      <!-- Accidentals (sharps/flats) -->
      <g class="accidentals">
        <ng-container *ngFor="let notePos of notePositions">
          <!-- Sharp symbol -->
          <text *ngIf="notePos.accidental === 'sharp'"
                [attr.x]="notePos.x - 20"
                [attr.y]="notePos.y + 8"
                font-family="Arial, sans-serif"
                font-size="32"
                fill="#000">♯</text>

          <!-- Flat symbol -->
          <text *ngIf="notePos.accidental === 'flat'"
                [attr.x]="notePos.x - 20"
                [attr.y]="notePos.y + 8"
                font-family="Arial, sans-serif"
                font-size="32"
                fill="#000">♭</text>

          <!-- Natural symbol -->
          <text *ngIf="notePos.accidental === 'natural'"
                [attr.x]="notePos.x - 20"
                [attr.y]="notePos.y + 8"
                font-family="Arial, sans-serif"
                font-size="32"
                fill="#000">♮</text>
        </ng-container>
      </g>

      <!-- Note heads -->
      <g class="note-heads">
        <ellipse *ngFor="let notePos of notePositions"
                 [attr.cx]="notePos.x"
                 [attr.cy]="notePos.y"
                 rx="7"
                 ry="6"
                 fill="#000"
                 [attr.transform]="'rotate(-20 ' + notePos.x + ' ' + notePos.y + ')'"/>
      </g>

      <!-- Stems -->
      <g class="stems">
        <line *ngFor="let notePos of notePositions"
              [attr.x1]="notePos.x + 6.5"
              [attr.y1]="notePos.y"
              [attr.x2]="notePos.x + 6.5"
              [attr.y2]="notePos.y - 35"
              stroke="#000"
              stroke-width="1.5"/>
      </g>

      <!-- Note labels below staff -->
      <g class="note-labels">
        <text *ngFor="let notePos of notePositions"
              [attr.x]="notePos.x"
              [attr.y]="staffLines[staffLines.length - 1] + 35"
              font-family="Arial, sans-serif"
              font-size="16"
              font-weight="500"
              fill="#000"
              text-anchor="middle">{{ notePos.note }}</text>
      </g>
    </svg>
  `,
  styles: [`
    .musical-staff {
      display: block;
      margin: 0;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
  `]
})
export class MusicalStaffComponent {
  @Input() notes: string[] = [];

  width = 800;
  height = 200;
  margins = { left: 60, right: 40, top: 40, bottom: 40 };

  staffLines: number[] = [];
  notePositions: NotePosition[] = [];

  ngOnInit() {
    this.calculateStaffLines();
    this.calculateNotePositions();
  }

  ngOnChanges() {
    // Ensure staff lines are calculated before positioning notes
    if (this.staffLines.length === 0) {
      this.calculateStaffLines();
    }
    this.calculateNotePositions();
  }

  private calculateStaffLines() {
    const centerY = this.height / 2;
    const spacing = 10;

    // 5 staff lines centered vertically
    this.staffLines = [
      centerY - spacing * 2,
      centerY - spacing,
      centerY,
      centerY + spacing,
      centerY + spacing * 2
    ];
  }

  private calculateNotePositions() {
    if (!this.notes || this.notes.length === 0) {
      this.notePositions = [];
      return;
    }

    const spacing = (this.width - this.margins.left - this.margins.right - 80) / Math.max(this.notes.length - 1, 1);
    const startX = this.margins.left + 80;

    // Track octave changes for sequential notes in a scale
    let currentOctave = 4;
    let previousNoteValue = -1;

    this.notePositions = this.notes.map((note, index) => {
      const { y, ledgerLines, accidental, noteValue } = this.getNoteY(note, currentOctave);

      // If the note value went down (e.g., from B to C), we've crossed into the next octave
      if (index > 0 && noteValue < previousNoteValue) {
        currentOctave++;
        const adjusted = this.getNoteY(note, currentOctave);
        previousNoteValue = adjusted.noteValue;
        return {
          note,
          x: startX + (index * spacing),
          y: adjusted.y,
          ledgerLines: adjusted.ledgerLines,
          accidental: adjusted.accidental
        };
      }

      previousNoteValue = noteValue;
      return {
        note,
        x: startX + (index * spacing),
        y,
        ledgerLines,
        accidental
      };
    });
  }

  private getNoteY(note: string, octave: number = 4): { y: number; ledgerLines: number[]; accidental?: 'sharp' | 'flat' | 'natural'; noteValue: number } {
    // Parse note: e.g., "C4", "F#5", "Bb3", or just "C", "F#", "Bb"
    const match = note.match(/^([A-G])(#|♯|b|♭)?(\d)?$/);
    if (!match) {
      return { y: this.staffLines[2], ledgerLines: [], noteValue: 0 };
    }

    const noteName = match[1];
    const accidental = match[2];
    const noteOctave = match[3] ? parseInt(match[3]) : octave; // Use provided octave if not in note string

    // Map note names to numeric values (C=0, D=1, E=2, F=3, G=4, A=5, B=6)
    const noteValueMap: { [key: string]: number } = {
      'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6
    };
    const noteValue = noteValueMap[noteName];

    // Map note names to staff positions (C4 is middle C)
    // Position 0 is middle line (B4), positive is higher, negative is lower
    const noteMap: { [key: string]: number } = {
      'C': -6, // Below staff
      'D': -5,
      'E': -4,
      'F': -3,
      'G': -2,
      'A': -1,
      'B': 0   // Middle line
    };

    // Calculate position based on octave and note
    let position = noteMap[noteName];
    position += (noteOctave - 4) * 7; // Adjust for octave (7 notes per octave)

    // Each position is 5 pixels (half a staff space)
    const centerLine = this.staffLines[2];
    const y = centerLine - (position * 5);

    // Determine if ledger lines are needed
    const ledgerLines: number[] = [];
    const topLine = this.staffLines[0];
    const bottomLine = this.staffLines[4];

    // Add ledger lines above staff
    if (y < topLine) {
      for (let ly = topLine - 10; ly >= y; ly -= 10) {
        ledgerLines.push(ly);
      }
    }

    // Add ledger lines below staff
    if (y > bottomLine) {
      for (let ly = bottomLine + 10; ly <= y; ly += 10) {
        ledgerLines.push(ly);
      }
    }

    // Determine accidental type
    let accidentalType: 'sharp' | 'flat' | 'natural' | undefined;
    if (accidental === '#' || accidental === '♯') {
      accidentalType = 'sharp';
    } else if (accidental === 'b' || accidental === '♭') {
      accidentalType = 'flat';
    }

    return { y, ledgerLines, accidental: accidentalType, noteValue };
  }
}
