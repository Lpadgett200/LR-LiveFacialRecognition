import { useState, useCallback, useEffect } from 'react';
import { isDebug, useNuiEvent, fetchNui } from './hooks/useNui';

interface AlertType {
  code: string;
  label: string;
  severity: 'low' | 'medium' | 'high';
  color: string;
}

interface ScanResult {
  id: string;
  netId?: number;
  name: string;
  age: number;
  region: string;
  postcode: string;
  alertType: AlertType | null;
  gender: string;
  description: string;
  confidence: number;
  distance: number;
  snapTime?: string;
  lastName?: string;
  headshotTxd?: string; // Texture dictionary for ped headshot
  sceneImage?: string; // Base64 screenshot from screenshot-basic
  note?: string; // Officer notes
}

export default function App() {
  const [visible, setVisible] = useState(isDebug);
  const [mode, setMode] = useState<'menu' | 'manual' | 'snap'>('menu');
  const [currentSnap, setCurrentSnap] = useState<ScanResult | null>(null);
  const [snapHistory, setSnapHistory] = useState<ScanResult[]>([]);
  const [snapIndex, setSnapIndex] = useState(0);
  const [showNoteModal, setShowNoteModal] = useState(false);
  const [noteText, setNoteText] = useState('');

  useNuiEvent('open', (data: { mode?: string }) => {
    setVisible(true);
    if (data?.mode === 'manual') {
      setMode('manual');
    } else {
      setMode('menu');
    }
  });

  useNuiEvent('close', () => {
    setVisible(false);
    setMode('menu');
    setCurrentSnap(null);
  });

  useNuiEvent('returnToMenu', () => {
    setMode('menu');
    setCurrentSnap(null);
  });

  useNuiEvent('snapResult', (data: { result: ScanResult }) => {
    console.log('[LFR UI] snapResult received:', data);
    if (data.result) {
      console.log('[LFR UI] Processing result for:', data.result.name);
      const timestamped = {
        ...data.result,
        snapTime: new Date().toLocaleTimeString('en-GB'),
        lastName: data.result.name.split(' ').slice(1).join(' ') || data.result.name,
        // Mock headshot for browser preview
        headshotTxd: data.result.headshotTxd || (isDebug ? 'char_pa_female_01' : undefined)
      };
      
      setSnapHistory(prev => {
        const newHistory = [timestamped, ...prev].slice(0, 20);
        return newHistory;
      });
      
      setCurrentSnap(timestamped);
      setSnapIndex(0);
      setMode('snap');
      console.log('[LFR UI] Switched to snap mode');
    } else {
      console.log('[LFR UI] No result in data');
    }
  });

  const handleClose = useCallback(async () => {
    setVisible(false);
    setMode('menu');
    setCurrentSnap(null);
    await fetchNui('close', {}, { success: true });
  }, []);

  const handleReturnToMenu = useCallback(async () => {
    setMode('menu');
    setCurrentSnap(null);
    await fetchNui('returnToMenu', {}, { success: true });
  }, []);

  const handleStartManual = useCallback(async () => {
    setMode('manual');
    await fetchNui('startManual', {}, { success: true });
  }, []);

  const handleSnap = useCallback(async () => {
    await fetchNui('snap', {}, { success: true });
  }, []);

  const handleNextSnap = useCallback(() => {
    if (snapIndex < snapHistory.length - 1) {
      const newIndex = snapIndex + 1;
      setSnapIndex(newIndex);
      setCurrentSnap(snapHistory[newIndex]);
    }
  }, [snapIndex, snapHistory]);

  const handlePrevSnap = useCallback(() => {
    if (snapIndex > 0) {
      const newIndex = snapIndex - 1;
      setSnapIndex(newIndex);
      setCurrentSnap(snapHistory[newIndex]);
    }
  }, [snapIndex, snapHistory]);

  const handleMarkWanted = useCallback(async () => {
    if (!currentSnap) return;
    await fetchNui('markWanted', { id: currentSnap.id, netId: currentSnap.netId }, { success: true });
  }, [currentSnap]);

  const handleEditNotes = useCallback(() => {
    if (!currentSnap) return;
    setNoteText(currentSnap.note || '');
    setShowNoteModal(true);
  }, [currentSnap]);

  const handleSaveNote = useCallback(async () => {
    if (!currentSnap) return;
    await fetchNui('saveNote', { id: currentSnap.id, note: noteText }, { success: true });
    
    // Update local state
    const updatedSnap = { ...currentSnap, note: noteText };
    setCurrentSnap(updatedSnap);
    setSnapHistory(prev => prev.map((s, i) => i === snapIndex ? updatedSnap : s));
    setShowNoteModal(false);
  }, [currentSnap, noteText, snapIndex]);

  // Keyboard controls - only active when UI has focus (menu or snap modes)
  // Manual mode uses game controls via Lua, not React keyboard handler
  useEffect(() => {
    if (!visible) return;

    const onKeyDown = (e: KeyboardEvent) => {
      // In manual mode, don't intercept keys - let game controls work
      if (mode === 'manual') return;

      if (e.key === 'Escape') {
        if (mode === 'snap') {
          handleReturnToMenu();
        } else {
          handleClose();
        }
      }
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [visible, mode, handleReturnToMenu, handleClose]);

  if (!visible) return null;

  // Main Menu
  if (mode === 'menu') {
    return (
      <div className="fixed inset-0 flex items-center justify-center pointer-events-none">
        <div className="pointer-events-auto w-[400px] bg-[#111111] rounded-lg border border-[#333] overflow-hidden shadow-2xl">
          {/* Header */}
          <div className="px-4 py-3 border-b border-[#333] flex items-center justify-between">
            <div className="w-16" />
            <h1 className="text-white text-sm font-medium">Facial Recognition</h1>
            <button onClick={handleClose} className="text-gray-500 hover:text-white text-lg leading-none">&times;</button>
          </div>

          {/* Content */}
          <div className="p-6 flex flex-col items-center">
            <div className="w-24 h-24 rounded-full bg-[#1a1a1a] border border-[#333] flex items-center justify-center mb-4">
              <svg className="w-12 h-12 text-[#444]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>

            <button
              onClick={handleStartManual}
              className="w-full py-3 rounded bg-[#222] hover:bg-[#2a2a2a] text-white text-sm font-medium transition-all"
            >
              Enter Manual Mode
            </button>
          </div>

          {/* Recent Snaps */}
          {snapHistory.length > 0 && (
            <div className="border-t border-[#333] p-4">
              <p className="text-[#666] text-xs font-medium mb-3">RECENT CAPTURES</p>
              <div className="space-y-1 max-h-32 overflow-y-auto">
                {snapHistory.slice(0, 4).map((snap, i) => (
                  <button
                    key={`${snap.id}-${i}`}
                    onClick={() => {
                      setCurrentSnap(snap);
                      setSnapIndex(i);
                      setMode('snap');
                    }}
                    className="w-full flex items-center gap-3 p-2 rounded bg-[#1a1a1a] hover:bg-[#222] transition-all"
                  >
                    <div className={`w-8 h-8 rounded flex items-center justify-center ${
                      snap.alertType ? 'bg-red-500/20' : 'bg-[#2a2a2a]'
                    }`}>
                      <svg className={`w-4 h-4 ${snap.alertType ? 'text-red-400' : 'text-[#555]'}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                    </div>
                    <div className="flex-1 text-left">
                      <p className="text-white text-xs">{snap.name}</p>
                      <p className="text-[#555] text-[10px]">{snap.snapTime}</p>
                    </div>
                    {snap.alertType && (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-500/20 text-red-400">
                        {snap.alertType.code}
                      </span>
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

  // Manual Mode - Camera Overlay
  if (mode === 'manual') {
    return (
      <div className="fixed inset-0 pointer-events-none">
        {/* Control Legend - Top Left */}
        <div className="absolute top-4 left-4 pointer-events-auto">
          <div className="bg-black/90 px-3 py-2 rounded text-[11px] font-mono text-white leading-relaxed">
            <div className="text-[#888] mb-1">Manual Mode</div>
            <div>↑ ↓ tilt | ← → pan</div>
            <div>ENTER to snap ped</div>
            <div>BACKSPACE to exit</div>
          </div>
        </div>

        {/* Targeting Reticle - Center */}
        <div className="absolute inset-0 flex items-center justify-center">
          <div className="w-0.5 h-16 bg-red-500" />
        </div>

        {/* Notification Box - Bottom Left */}
        <div className="absolute bottom-6 left-4 pointer-events-auto">
          <div className="bg-[#111] rounded-lg border-2 border-[#ff4060] p-4 max-w-xs" style={{ boxShadow: '0 0 20px rgba(255, 64, 96, 0.3)' }}>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-10 h-10 bg-[#1a1a1a] rounded flex items-center justify-center">
                <svg className="w-6 h-6 text-[#ff4060]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
              </div>
              <div>
                <div className="text-white text-sm font-bold tracking-wide">MANUAL MODE</div>
                <div className="text-[#888] text-[10px] flex items-center gap-1">
                  <span>L</span>
                  <span className="text-[#ff4060]">LR DEVELOPMENT</span>
                </div>
              </div>
            </div>
            <p className="text-[#888] text-[11px] leading-relaxed">
              Manually select and capture individuals within the camera view, giving you full control over when and what the system records
            </p>
          </div>
        </div>
      </div>
    );
  }

  // Facial Snap Detail View
  if (mode === 'snap' && currentSnap) {
    const firstName = currentSnap.name.split(' ')[0];

    return (
      <div className="fixed inset-0 flex items-center justify-center bg-black/70 pointer-events-none">
        <div className="pointer-events-auto w-[700px] bg-[#111111] rounded-lg border border-[#333] overflow-hidden shadow-2xl">
          {/* Header */}
          <div className="px-4 py-3 border-b border-[#333] flex items-center justify-between">
            <button
              onClick={handleReturnToMenu}
              className="text-[#888] hover:text-white text-xs transition-colors"
            >
              &lt; Return to Main Menu
            </button>
            <h1 className="text-white text-sm font-medium">
              Facial Snap | #{String(snapIndex + 1).padStart(2, '0')}
            </h1>
            <button onClick={handleClose} className="text-gray-500 hover:text-white text-lg leading-none">&times;</button>
          </div>

          {/* Images Section */}
          <div className="flex border-b border-[#333]">
            {/* Detailed Image */}
            <div className="flex-1 p-3 border-r border-[#333]">
              <SectionHeader title="Detailed Image" />
              <div className="relative bg-[#1a1a1a] rounded h-44 flex items-center justify-center overflow-hidden">
                {/* Ped headshot or placeholder */}
                {currentSnap.headshotTxd ? (
                  <img 
                    src={`https://nui-img/${currentSnap.headshotTxd}/${currentSnap.headshotTxd}`}
                    alt="Subject"
                    className="w-32 h-32 object-cover rounded-lg"
                    style={{ imageRendering: 'auto' }}
                  />
                ) : (
                  <div className="w-20 h-20 rounded-full bg-[#252525] flex items-center justify-center">
                    <svg className="w-14 h-14 text-[#333]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                )}

                {/* Overlay info */}
                <div className="absolute top-2 left-2 bg-black/70 px-2 py-1.5 rounded text-[10px] font-mono">
                  <p className="text-white"><span className="text-[#666]">Name:</span> {firstName}</p>
                  <p className="text-white"><span className="text-[#666]">Age:</span> {currentSnap.age}</p>
                  <p className="text-white"><span className="text-[#666]">Confidence:</span> {currentSnap.confidence}%</p>
                </div>

                {/* Zoom controls */}
                <div className="absolute bottom-2 right-2 flex gap-1">
                  <button className="w-5 h-5 bg-[#2a2a2a] rounded text-gray-400 hover:text-white text-xs leading-none flex items-center justify-center">+</button>
                  <button className="w-5 h-5 bg-[#2a2a2a] rounded text-gray-400 hover:text-white text-xs leading-none flex items-center justify-center">−</button>
                </div>
              </div>
            </div>

            {/* Original Image */}
            <div className="flex-1 p-3">
              <SectionHeader title="Original Image" />
              <div className="relative bg-[#1a1a1a] rounded h-44 flex items-center justify-center overflow-hidden">
                {currentSnap.sceneImage ? (
                  <img 
                    src={currentSnap.sceneImage}
                    alt="Scene"
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full bg-gradient-to-b from-[#1e3a5f]/10 to-[#1a1a1a] flex items-center justify-center">
                    <svg className="w-12 h-12 text-[#333]" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1} d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Bottom Section */}
          <div className="flex">
            {/* Information */}
            <div className="flex-1 p-3 border-r border-[#333]">
              <SectionHeader title="Information" />
              <div className="space-y-1.5">
                <InfoField label="Last Name" value={currentSnap.lastName || 'N/A'} />
                <InfoField label="Snap Time" value={currentSnap.snapTime || 'N/A'} />
                <InfoField label="Camera" value="Front" />
                <InfoField label="Confidence" value={`${currentSnap.confidence}%`} />
                <InfoField label="Gender" value={currentSnap.gender === 'male' ? 'Male' : 'Female'} />
                <InfoField label="Note" value={currentSnap.note || currentSnap.alertType?.code || 'N/A'} />
              </div>
            </div>

            {/* Enforcement Actions */}
            <div className="flex-1 p-3">
              <SectionHeader title="Enforcement Actions" />
              <div className="space-y-1.5">
                <button
                  onClick={handleMarkWanted}
                  className="w-full py-2.5 rounded bg-[#222] hover:bg-[#2a2a2a] text-white text-xs font-medium transition-all"
                >
                  Mark Wanted
                </button>
                <button
                  onClick={handleEditNotes}
                  className="w-full py-2.5 rounded bg-[#222] hover:bg-[#2a2a2a] text-white text-xs font-medium transition-all"
                >
                  Edit Notes
                </button>
              </div>
            </div>
          </div>

          {/* Navigation */}
          <div className="px-4 py-2 border-t border-[#333] flex items-center justify-between">
            <button
              onClick={handlePrevSnap}
              disabled={snapIndex === 0}
              className={`text-xs ${snapIndex === 0 ? 'text-[#444]' : 'text-[#888] hover:text-white'}`}
            >
              &lt; Previous
            </button>
            <span className="text-[#555] text-xs">
              {snapIndex + 1} of {snapHistory.length}
            </span>
            <button
              onClick={handleNextSnap}
              disabled={snapIndex >= snapHistory.length - 1}
              className={`text-xs ${snapIndex >= snapHistory.length - 1 ? 'text-[#444]' : 'text-[#888] hover:text-white'}`}
            >
              Next &gt;
            </button>
          </div>
        </div>

        {/* Edit Notes Modal */}
        {showNoteModal && (
          <div className="fixed inset-0 flex items-center justify-center pointer-events-auto" style={{ zIndex: 100 }}>
            <div className="w-[350px] bg-[#111111] rounded-lg border border-[#444] overflow-hidden shadow-2xl">
              {/* Modal Header */}
              <div className="px-4 py-3 border-b border-[#333] flex items-center justify-between">
                <span className="text-white text-sm font-medium">Edit Notes</span>
                <button 
                  onClick={() => setShowNoteModal(false)}
                  className="text-gray-500 hover:text-white text-lg leading-none"
                >
                  &times;
                </button>
              </div>
              
              {/* Modal Content */}
              <div className="p-4">
                <p className="text-[#666] text-xs mb-2">Subject: {currentSnap?.name}</p>
                <textarea
                  value={noteText}
                  onChange={(e) => setNoteText(e.target.value)}
                  placeholder="Enter officer notes..."
                  className="w-full h-32 bg-[#1a1a1a] border border-[#333] rounded px-3 py-2 text-white text-xs resize-none focus:outline-none focus:border-[#555]"
                  autoFocus
                />
              </div>
              
              {/* Modal Footer */}
              <div className="px-4 py-3 border-t border-[#333] flex gap-2">
                <button
                  onClick={() => setShowNoteModal(false)}
                  className="flex-1 py-2 rounded bg-[#222] hover:bg-[#2a2a2a] text-[#888] text-xs font-medium transition-all"
                >
                  Cancel
                </button>
                <button
                  onClick={handleSaveNote}
                  className="flex-1 py-2 rounded bg-[#1a4a2a] hover:bg-[#1e5a32] text-white text-xs font-medium transition-all"
                >
                  Save Note
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    );
  }

  return null;
}

function SectionHeader({ title }: { title: string }) {
  return (
    <div className="flex items-center gap-2 mb-2">
      <div className="w-0.5 h-3 bg-[#555] rounded-full" />
      <p className="text-[#888] text-[11px] font-medium">{title}</p>
    </div>
  );
}

function InfoField({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between">
      <p className="text-[#555] text-[11px]">{label}</p>
      <div className="px-3 py-1.5 bg-[#1a1a1a] rounded text-[11px] min-w-[110px] text-right">
        <span className="text-white">{value}</span>
      </div>
    </div>
  );
}
