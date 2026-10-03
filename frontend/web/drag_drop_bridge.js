// HTML5 Native Drag & Drop Bridge for Achuppori
(function() {
  let activeDropCallback = null;
  let activeStateCallback = null;
  let dragCounter = 0;
  let dragTimer = null;

  function notifyState(isDragging) {
    if (activeStateCallback) {
      try {
        activeStateCallback(isDragging);
      } catch (e) {
        console.error('Error in drag state callback:', e);
      }
    }
  }

  window.initWebDragDrop = function(onStateChange, onFileDrop) {
    activeStateCallback = onStateChange;
    activeDropCallback = onFileDrop;
  };

  window.clearWebDragDrop = function() {
    activeStateCallback = null;
    activeDropCallback = null;
    dragCounter = 0;
    if (dragTimer) {
      clearTimeout(dragTimer);
      dragTimer = null;
    }
  };

  function hasFiles(e) {
    if (!e.dataTransfer) return false;
    const types = e.dataTransfer.types;
    if (!types) return true;
    for (let i = 0; i < types.length; i++) {
      if (types[i] === 'Files' || types[i] === 'application/x-moz-file') {
        return true;
      }
    }
    return false;
  }

  window.addEventListener('dragenter', function(e) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    dragCounter++;
    if (dragCounter === 1) {
      notifyState(true);
    }
  }, true);

  window.addEventListener('dragover', function(e) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    if (e.dataTransfer) {
      e.dataTransfer.dropEffect = 'copy';
    }

    if (dragCounter <= 0) {
      dragCounter = 1;
      notifyState(true);
    }

    if (dragTimer) clearTimeout(dragTimer);
    dragTimer = setTimeout(function() {
      dragCounter = 0;
      notifyState(false);
    }, 400);
  }, true);

  window.addEventListener('dragleave', function(e) {
    e.preventDefault();
    dragCounter--;

    if (!e.relatedTarget || e.clientX <= 0 || e.clientY <= 0 ||
        e.clientX >= window.innerWidth || e.clientY >= window.innerHeight) {
      dragCounter = 0;
    }

    if (dragCounter <= 0) {
      dragCounter = 0;
      if (dragTimer) clearTimeout(dragTimer);
      notifyState(false);
    }
  }, true);

  window.addEventListener('dragend', function(e) {
    dragCounter = 0;
    if (dragTimer) clearTimeout(dragTimer);
    notifyState(false);
  }, true);

  window.addEventListener('drop', function(e) {
    e.preventDefault();
    e.stopPropagation();
    dragCounter = 0;
    if (dragTimer) {
      clearTimeout(dragTimer);
      dragTimer = null;
    }
    notifyState(false);

    if (!e.dataTransfer) return;

    let files = [];
    if (e.dataTransfer.files && e.dataTransfer.files.length > 0) {
      files = Array.from(e.dataTransfer.files);
    } else if (e.dataTransfer.items && e.dataTransfer.items.length > 0) {
      for (let i = 0; i < e.dataTransfer.items.length; i++) {
        const item = e.dataTransfer.items[i];
        if (item.kind === 'file') {
          const f = item.getAsFile();
          if (f) files.push(f);
        }
      }
    }

    if (files.length === 0) return;

    files.forEach(function(file) {
      const reader = new FileReader();
      reader.onload = function(evt) {
        if (evt.target && evt.target.result && activeDropCallback) {
          try {
            const uint8 = new Uint8Array(evt.target.result);
            activeDropCallback(file.name, uint8);
          } catch (err) {
            console.error('Error delivering dropped file to Dart:', err);
          }
        }
      };
      reader.onerror = function(err) {
        console.error('FileReader error:', err);
      };
      reader.readAsArrayBuffer(file);
    });
  }, true);
})();
