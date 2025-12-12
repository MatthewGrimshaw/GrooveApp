import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  Note,
  Interval,
  IntervalFromNote,
  ScaleType,
  Scale,
  ScaleDegree,
  ChordType,
  Arpeggio,
  ArpeggioDegree,
  ChordExtension,
  HealthCheck
} from '../models/music.models';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class MusicApiService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  // Health Check
  getHealth(): Observable<HealthCheck> {
    return this.http.get<HealthCheck>(`${this.apiUrl}/health`);
  }

  // Notes
  getNotes(): Observable<Note[]> {
    return this.http.get<Note[]>(`${this.apiUrl}/notes`);
  }

  // Intervals
  getIntervals(): Observable<Interval[]> {
    return this.http.get<Interval[]>(`${this.apiUrl}/intervals`);
  }

  getIntervalsFromNote(note: string): Observable<IntervalFromNote[]> {
    const encodedNote = note.replace('#', '%23');
    return this.http.get<IntervalFromNote[]>(`${this.apiUrl}/intervals/${encodedNote}`);
  }

  // Scales
  getScaleTypes(): Observable<ScaleType[]> {
    return this.http.get<ScaleType[]>(`${this.apiUrl}/scales`);
  }

  getScale(rootNote: string, scaleTypeId: number): Observable<ScaleDegree[]> {
    const encodedNote = rootNote.replace('#', '%23');
    return this.http.get<ScaleDegree[]>(`${this.apiUrl}/scales/${encodedNote}/${scaleTypeId}`);
  }

  // Chords/Arpeggios
  getChordTypes(): Observable<ChordType[]> {
    return this.http.get<ChordType[]>(`${this.apiUrl}/chords`);
  }

  getArpeggio(rootNote: string, chordTypeId: number): Observable<ArpeggioDegree[]> {
    const encodedNote = rootNote.replace('#', '%23');
    return this.http.get<ArpeggioDegree[]>(`${this.apiUrl}/arpeggios/${encodedNote}/${chordTypeId}`);
  }

  // Chord Extensions
  getChordExtensions(chordTypeId: number, rootNote?: string): Observable<ChordExtension[]> {
    const url = rootNote
      ? `${this.apiUrl}/chords/${chordTypeId}/extensions?root_note=${encodeURIComponent(rootNote)}`
      : `${this.apiUrl}/chords/${chordTypeId}/extensions`;
    return this.http.get<ChordExtension[]>(url);
  }
}
