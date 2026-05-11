A realistic UK-style Live Facial Recognition (LFR) system for FiveM, designed for law enforcement roleplay.

Features
Manual Mode Camera System

Enter a configurable vehicle (default: Speedo van) to access the LFR camera
Pan/tilt camera using arrow keys (WASD also supported)
Central red targeting reticle for aiming
Press ENTER to capture/scana subject in the camera view
Scene capture saved at the moment of scan (via screenshot-basic)
Facial Snap Interface

Metropolitan Police-styled terminal UI
Two-pane image layout:
Detailed Image: Ped headshot with name, age, confidence overlay
Original Image: Scene screenshot from the exact moment of capture
Information panel: Last Name, Snap Time, Camera, Confidence, Gender, Notes
Enforcement actions: Mark Wanted, Edit Notes
Identity Generation

Gender-accurate names using IsPedMale() detection
UK-themed names (James, Oliver, Olivia, Amelia, etc.)
UK regions (London, Manchester, Birmingham, etc.)
UK postcode format (SW1-SW9)
15% alert chance with types: WANTED, MISSING, PERSON-INT, KNOWN-LOC, INTEL
Notes System

Add officer notes to any scanned subject
Notes persist across scans by citizen ID
Accessible via "Edit Notes" button in enforcement panel
Requirements
ox_lib - notifications
ox_target - vehicle interaction
screenshot-basic - scene captures (optional, falls back gracefully)
