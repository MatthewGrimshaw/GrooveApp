import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClientModule } from '@angular/common/http';
import { interval, Subscription } from 'rxjs';
import { switchMap, catchError } from 'rxjs/operators';
import { of } from 'rxjs';
import { MusicApiService } from './services/music-api.service';
import {
  Note,
  ScaleType,
  Scale,
  ChordType,
  Arpeggio,
  IntervalFromNote,
  ChordExtension
} from './models/music.models';
import { MusicalStaffComponent } from './components/musical-staff.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule, HttpClientModule, MusicalStaffComponent],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.css']
})
export class AppComponent implements OnInit, OnDestroy {
  title = 'GrooveApp Music Theory';

  // Data
  notes: Note[] = [];
  scaleTypes: ScaleType[] = [];
  chordTypes: ChordType[] = [];

  // User selections
  selectedNote = 'C';
  selectedNoteObj: Note | null = null;
  selectedScaleTypeId = 1;
  selectedChordTypeId = 5;
  intervalFromNote = 'C';
  intervalFromNoteObj: Note | null = null;

  // Results
  currentScale: Scale | null = null;
  currentArpeggio: Arpeggio | null = null;
  currentChordExtensions: ChordExtension[] = [];
  intervalsFromNote: IntervalFromNote[] = [];

  // UI State
  loading = false;
  error: string | null = null;
  healthStatus: string | null = null;
  healthDetails: string | null = null;
  healthResponseTime: number | null = null;
  lastHealthCheck: Date | null = null;
  consecutiveHealthFailures = 0;
  maxHealthFailures = 3;
  activeTab: 'scales' | 'arpeggios' | 'intervals' = 'scales';

  // Subscriptions
  private healthCheckSubscription?: Subscription;

  constructor(private musicApi: MusicApiService) {}

  ngOnInit() {
    // Load data without blocking the UI
    this.checkHealth();
    setTimeout(() => this.loadInitialData(), 100);

    // Start periodic health checks every 30 seconds
    this.startHealthMonitoring();
  }

  ngOnDestroy() {
    // Clean up subscription when component is destroyed
    if (this.healthCheckSubscription) {
      this.healthCheckSubscription.unsubscribe();
    }
  }

  startHealthMonitoring() {
    // Poll health endpoint every 30 seconds with circuit breaker pattern
    this.healthCheckSubscription = interval(30000)
      .pipe(
        switchMap(() => this.musicApi.getHealth().pipe(
          catchError(error => {
            // Return error as observable to continue polling
            return of({ error: true, message: error.message });
          })
        ))
      )
      .subscribe({
        next: (response: any) => {
          if (response.error) {
            this.handleHealthCheckFailure(response.message);
          } else {
            this.handleHealthCheckSuccess(response);
          }
        }
      });
  }

  checkHealth() {
    this.healthStatus = 'Checking...';
    this.musicApi.getHealth().subscribe({
      next: (health) => {
        this.handleHealthCheckSuccess(health);
      },
      error: (err) => {
        this.handleHealthCheckFailure(err.message || 'Unknown error');
      }
    });
  }

  handleHealthCheckSuccess(health: any) {
    this.consecutiveHealthFailures = 0;
    this.lastHealthCheck = new Date();
    this.healthResponseTime = health.responseTimeMs;

    // Build detailed status string
    let statusParts = [`${health.status} - Database: ${health.database}`];

    if (health.responseTimeMs) {
      statusParts.push(`(${health.responseTimeMs.toFixed(0)}ms)`);
    }

    this.healthStatus = statusParts.join(' ');

    // Build details string with checks
    const details: string[] = [];
    if (health.checks?.database) {
      const db = health.checks.database;
      if (db.status === 'healthy' && db.responseTimeMs) {
        details.push(`DB: ${db.responseTimeMs.toFixed(0)}ms`);
      } else if (db.error) {
        details.push(`DB Error: ${db.errorType || 'Unknown'}`);
      }
    }

    if (health.checks?.authentication) {
      const auth = health.checks.authentication;
      if (auth.status === 'healthy') {
        details.push(`Auth: ${auth.method || 'OK'}`);
      } else if (auth.error) {
        details.push(`Auth Warning`);
      }
    }

    this.healthDetails = details.length > 0 ? details.join(' | ') : null;
  }

  handleHealthCheckFailure(errorMessage: string) {
    this.consecutiveHealthFailures++;
    this.lastHealthCheck = new Date();

    // Circuit breaker: Stop polling after max failures
    if (this.consecutiveHealthFailures >= this.maxHealthFailures) {
      this.healthStatus = 'API Unavailable - Stopped polling after multiple failures';
      if (this.healthCheckSubscription) {
        this.healthCheckSubscription.unsubscribe();
      }
    } else {
      this.healthStatus = `API Unavailable (${this.consecutiveHealthFailures}/${this.maxHealthFailures} failures)`;
    }

    this.healthDetails = `Last check: ${this.lastHealthCheck.toLocaleTimeString()}`;
    console.error('Health check failed:', errorMessage);
  }

  loadInitialData() {
    this.loading = true;
    this.error = null;

    // Load notes
    this.musicApi.getNotes().subscribe({
      next: (notes) => {
        this.notes = notes;
      },
      error: (err) => {
        this.error = 'Failed to load notes. Is the API running on http://localhost:8000?';
        this.loading = false;
        console.error(err);
      }
    });

    // Load scale types
    this.musicApi.getScaleTypes().subscribe({
      next: (types) => {
        this.scaleTypes = types;
        this.loading = false;
        if (types.length > 0) {
          this.generateScale();
        }
      },
      error: (err) => {
        this.error = 'Failed to load scale types. Is the API running on http://localhost:8000?';
        this.loading = false;
        console.error(err);
      }
    });

    // Load chord types
    this.musicApi.getChordTypes().subscribe({
      next: (types) => {
        this.chordTypes = types;
        if (types.length > 0) {
          this.generateArpeggio();
        }
      },
      error: (err) => {
        this.error = 'Failed to load chord types. Is the API running on http://localhost:8000?';
        console.error(err);
      }
    });
  }

  generateScale() {
    if (!this.selectedNoteObj || !this.selectedScaleTypeId) {
      return;
    }

    const noteName = this.selectedNoteObj.NoteName;

    this.loading = true;
    this.error = null;

    this.musicApi.getScale(noteName, this.selectedScaleTypeId).subscribe({
      next: (scaleDegrees) => {
        // Transform API response into Scale object
        if (scaleDegrees && scaleDegrees.length > 0) {
          const scaleType = this.scaleTypes.find(st => st.ScaleTypeId === this.selectedScaleTypeId);
          this.currentScale = {
            ScaleTypeId: this.selectedScaleTypeId,
            ScaleName: scaleDegrees[0].ScaleName,
            RootNote: this.selectedNoteObj!.NoteName,
            Notes: scaleDegrees.map(sd => sd.Note),
            RomanNumerals: scaleDegrees.map(sd => sd.RomanNumeral || ''),
            IntervalPattern: scaleType?.IntervalPattern || 'N/A'
          };
        } else {
          this.currentScale = null;
        }
        this.loading = false;
      },
      error: (err) => {
        this.error = 'Failed to generate scale: ' + (err.message || err.statusText || 'Unknown error');
        this.loading = false;
        console.error('Scale generation error:', err);
      }
    });
  }

  generateArpeggio() {
    if (!this.selectedNoteObj || !this.selectedChordTypeId) return;

    const noteName = this.selectedNoteObj.NoteName;

    this.loading = true;
    this.error = null;

    this.musicApi.getArpeggio(noteName, this.selectedChordTypeId).subscribe({
      next: (arpeggioDegrees) => {
        // Transform API response into Arpeggio object
        if (arpeggioDegrees && arpeggioDegrees.length > 0) {
          const chordType = this.chordTypes.find(ct => ct.ChordTypeId === this.selectedChordTypeId);
          this.currentArpeggio = {
            ChordTypeId: this.selectedChordTypeId,
            ChordName: arpeggioDegrees[0].ChordName,
            RootNote: this.selectedNoteObj!.NoteName,
            Notes: arpeggioDegrees.map(ad => ad.Note),
            RomanNumerals: arpeggioDegrees.map(ad => ad.RomanNumeral || ''),
            IntervalPattern: chordType?.IntervalPattern || ''
          };
          // Load chord extensions
          this.loadChordExtensions();
        } else {
        }
        this.loading = false;
      },
      error: (err) => {
        this.error = 'Failed to generate arpeggio: ' + (err.message || err.statusText || 'Unknown error');
        this.loading = false;
        console.error('Arpeggio generation error:', err);
      }
    });
  }

  loadChordExtensions() {
    if (!this.selectedChordTypeId || !this.selectedNoteObj) {
      this.currentChordExtensions = [];
      return;
    }

    const rootNote = this.selectedNoteObj.NoteName;
    this.musicApi.getChordExtensions(this.selectedChordTypeId, rootNote).subscribe({
      next: (extensions) => {
        this.currentChordExtensions = extensions;
      },
      error: (err) => {
        // Extensions are optional, so just log errors without showing to user
        console.warn('Could not load chord extensions:', err);
        this.currentChordExtensions = [];
      }
    });
  }

  showIntervalsFromNote() {
    if (!this.intervalFromNoteObj) return;

    const noteName = this.intervalFromNoteObj.NoteName;

    this.loading = true;
    this.error = null;

    this.musicApi.getIntervalsFromNote(noteName).subscribe({
      next: (intervals) => {
        this.intervalsFromNote = intervals;
        this.loading = false;
      },
      error: (err) => {
        this.error = 'Failed to load intervals';
        this.loading = false;
        console.error(err);
      }
    });
  }

  setActiveTab(tab: 'scales' | 'arpeggios' | 'intervals') {
    this.activeTab = tab;
    if (tab === 'intervals' && this.intervalsFromNote.length === 0) {
      this.showIntervalsFromNote();
    }
  }
}
