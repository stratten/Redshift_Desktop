# Progressive Loading Strategy for Basil

## Current Issues
- Backend takes 56 seconds to start (model scanning, heavy imports)
- Frontend waits for backend health check
- User sees no feedback during long startup

## Progressive Loading Approach

### Phase 1: Immediate Response (0-2 seconds)
- Backend starts with minimal imports
- Health endpoint responds immediately
- Frontend launches and shows "Starting..." status
- User sees app is launching

### Phase 2: Core Functionality (2-10 seconds)
- Load essential API routes
- Initialize basic settings
- Enable basic transcription without models
- User can access settings, see status

### Phase 3: Model Loading (10-60 seconds)
- Load models in background
- Show progress in UI
- Enable advanced features as they become available
- User can use basic features while waiting

### Phase 4: Full Functionality (60+ seconds)
- All models loaded
- All features available
- Background optimization continues

## Implementation Steps

1. **Backend Lazy Loading** ✅
   - Defer model scanning until needed
   - Load routes progressively
   - Immediate health check response

2. **Frontend Progressive UI**
   - Show startup progress
   - Enable features as backend reports ready
   - Graceful degradation for missing features

3. **Model Streaming**
   - Download models on-demand
   - Cache frequently used models
   - Stream large models in chunks

4. **Background Optimization**
   - Pre-warm frequently used models
   - Optimize model loading order
   - Cache scan results
